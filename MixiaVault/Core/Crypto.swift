import Foundation
import CryptoKit
import CommonCrypto
import Security

// MARK: - 错误

enum VaultError: LocalizedError {
    case badPIN
    case badFile
    case notUnlocked
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .badPIN:      return "密码不对"
        case .badFile:     return "文件损坏，或者不是密匣的备份"
        case .notUnlocked: return "保险库是锁着的"
        case .writeFailed: return "写入失败，请检查存储空间"
        }
    }
}

// MARK: - 文件结构

/// 磁盘上的一个保险库文件：
///
///     "MXVT" | iterations(4, 大端) | salt(16) | nonceW(12) | nonceB(12)
///            | wrappedLen(2) | wrappedKey(48) | body(变长)
///
/// 上面这段头（magic + iterations + salt）同时作为 AES-GCM 的 AAD，
/// 防止有人把 iterations 改小来降低暴力破解成本。
struct VaultFile: Sendable {
    var iterations: UInt32
    var salt: Data
    var nonceWrap: Data
    var nonceBody: Data
    var wrapped: Data
    var body: Data

    static let magic = Data([0x4D, 0x58, 0x56, 0x54]) // "MXVT"
    static let defaultIterations: UInt32 = 600_000

    /// 参与认证的头部
    var header: Data {
        var data = VaultFile.magic
        var it = iterations.bigEndian
        withUnsafeBytes(of: &it) { data.append(contentsOf: $0) }
        data.append(salt)
        return data
    }

    func serialized() -> Data {
        var data = header
        data.append(nonceWrap)
        data.append(nonceBody)
        var len = UInt16(wrapped.count).bigEndian
        withUnsafeBytes(of: &len) { data.append(contentsOf: $0) }
        data.append(wrapped)
        data.append(body)
        return data
    }

    static func parse(_ data: Data) throws -> VaultFile {
        let bytes = [UInt8](data)
        let headerSize = 4 + 4 + 16
        let fixedSize = headerSize + 12 + 12 + 2 + 16
        guard bytes.count > fixedSize else { throw VaultError.badFile }
        guard Data(bytes[0..<4]) == magic else { throw VaultError.badFile }

        var offset = 4
        let iterations = UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
        offset += 4

        let salt = Data(bytes[offset..<offset + 16]); offset += 16
        let nonceWrap = Data(bytes[offset..<offset + 12]); offset += 12
        let nonceBody = Data(bytes[offset..<offset + 12]); offset += 12
        let wrappedLen = Int(bytes[offset]) << 8 | Int(bytes[offset + 1]); offset += 2

        guard wrappedLen > 16, bytes.count > offset + wrappedLen + 16 else { throw VaultError.badFile }
        let wrapped = Data(bytes[offset..<offset + wrappedLen]); offset += wrappedLen
        let body = Data(bytes[offset...])

        return VaultFile(iterations: iterations,
                         salt: salt,
                         nonceWrap: nonceWrap,
                         nonceBody: nonceBody,
                         wrapped: wrapped,
                         body: body)
    }
}

// MARK: - 解锁结果

struct Unlocked {
    let vault: Vault
    let key: SymmetricKey
    let file: VaultFile
}

// MARK: - 加解密

enum VaultCrypto {

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // 随机字节
    static func randomBytes(_ count: Int) -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return -1 }
            return SecRandomCopyBytes(kSecRandomDefault, count, base)
        }
        precondition(status == errSecSuccess, "系统随机数不可用")
        return data
    }

    // PBKDF2-HMAC-SHA256
    static func deriveKey(pin: String, salt: Data, iterations: UInt32) -> SymmetricKey {
        let pinData = Data(pin.utf8)
        var derived = Data(count: 32)

        let status: Int32 = derived.withUnsafeMutableBytes { keyBuffer in
            salt.withUnsafeBytes { saltBuffer in
                pinData.withUnsafeBytes { pinBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pinBuffer.baseAddress?.assumingMemoryBound(to: Int8.self),
                        pinData.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        keyBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        precondition(status == 0, "PBKDF2 失败")
        return SymmetricKey(data: derived)
    }

    // AES-256-GCM
    static func seal(_ plaintext: Data, key: SymmetricKey, nonce: Data, aad: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext,
                                   using: key,
                                   nonce: try AES.GCM.Nonce(data: nonce),
                                   authenticating: aad)
        return box.ciphertext + box.tag
    }

    static func open(_ combined: Data, key: SymmetricKey, nonce: Data, aad: Data) throws -> Data {
        guard combined.count > 16 else { throw VaultError.badFile }
        let ciphertext = combined.prefix(combined.count - 16)
        let tag = combined.suffix(16)
        let box = try AES.GCM.SealedBox(nonce: try AES.GCM.Nonce(data: nonce),
                                        ciphertext: ciphertext,
                                        tag: tag)
        return try AES.GCM.open(box, using: key, authenticating: aad)
    }

    // MARK: 新建

    /// 新建一个保险库：生成随机数据密钥，用 PIN 派生的 KEK 包一层
    static func create(pin: String, vault: Vault) throws -> (data: Data, key: SymmetricKey) {
        let salt = randomBytes(16)
        let iterations = VaultFile.defaultIterations
        let kek = deriveKey(pin: pin, salt: salt, iterations: iterations)
        let vaultKey = SymmetricKey(size: .bits256)

        var file = VaultFile(iterations: iterations,
                             salt: salt,
                             nonceWrap: randomBytes(12),
                             nonceBody: randomBytes(12),
                             wrapped: Data(),
                             body: Data())

        let aad = file.header
        let rawKey = vaultKey.withUnsafeBytes { Data($0) }
        file.wrapped = try seal(rawKey, key: kek, nonce: file.nonceWrap, aad: aad)
        let payload = try encoder.encode(vault)
        file.body = try seal(payload, key: vaultKey, nonce: file.nonceBody, aad: aad)

        return (file.serialized(), vaultKey)
    }

    // MARK: 用 PIN 解锁

    static func unlock(fileData: Data, pin: String) throws -> Unlocked {
        let file = try VaultFile.parse(fileData)
        let kek = deriveKey(pin: pin, salt: file.salt, iterations: file.iterations)
        let aad = file.header

        let rawKey: Data
        do {
            rawKey = try open(file.wrapped, key: kek, nonce: file.nonceWrap, aad: aad)
        } catch {
            throw VaultError.badPIN
        }
        let vaultKey = SymmetricKey(data: rawKey)

        let payload = try open(file.body, key: vaultKey, nonce: file.nonceBody, aad: aad)
        let vault = try decoder.decode(Vault.self, from: payload)
        return Unlocked(vault: vault, key: vaultKey, file: file)
    }

    // MARK: 用已有的钥匙解锁（Face ID 那条路）

    static func unlock(fileData: Data, key: SymmetricKey) throws -> Unlocked {
        let file = try VaultFile.parse(fileData)
        let payload = try open(file.body, key: key, nonce: file.nonceBody, aad: file.header)
        let vault = try decoder.decode(Vault.self, from: payload)
        return Unlocked(vault: vault, key: key, file: file)
    }

    // MARK: 保存

    /// 只重新加密正文，换一个 nonce；包钥匙那一段不动
    static func save(_ vault: Vault, file: VaultFile, key: SymmetricKey) throws -> (data: Data, file: VaultFile) {
        var newFile = file
        newFile.nonceBody = randomBytes(12)
        let payload = try encoder.encode(vault)
        newFile.body = try seal(payload, key: key, nonce: newFile.nonceBody, aad: newFile.header)
        return (newFile.serialized(), newFile)
    }

    // MARK: 改 PIN

    /// 换一个 salt，重新包同一个数据密钥
    static func changePIN(file: VaultFile, key: SymmetricKey, newPIN: String) throws -> Data {
        let salt = randomBytes(16)
        let iterations = VaultFile.defaultIterations
        let kek = deriveKey(pin: newPIN, salt: salt, iterations: iterations)

        var newFile = file
        newFile.iterations = iterations
        newFile.salt = salt
        newFile.nonceWrap = randomBytes(12)

        let aad = newFile.header                       // 换来新头，正文也要用新头重新认证

        // 正文的 AAD 是文件头，头变了就得用同一个数据密钥重新加密正文
        let rawKey = key.withUnsafeBytes { Data($0) }
        newFile.wrapped = try seal(rawKey, key: kek, nonce: newFile.nonceWrap, aad: aad)

        let payload = try open(file.body, key: key, nonce: file.nonceBody, aad: file.header)
        newFile.nonceBody = randomBytes(12)
        newFile.body = try seal(payload, key: key, nonce: newFile.nonceBody, aad: aad)

        return newFile.serialized()
    }
}

// MARK: - 钥匙串里的 Face ID 钥匙

enum BioKeychain {
    private static let service = "com.mixia.vault"
    private static let account = "vault-key"

    static func save(_ keyData: Data) throws {
        delete()
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil,
                                                           kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                           .biometryCurrentSet,
                                                           &error) else {
            throw VaultError.writeFailed
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessControl as String: access,
            kSecValueData as String: keyData
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultError.writeFailed }
    }

    /// 读的时候系统会自动弹面容 ID
    static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func exists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess
    }
}
