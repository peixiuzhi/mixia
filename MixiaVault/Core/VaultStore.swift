import Foundation
import CryptoKit
import Combine

@MainActor
final class VaultStore: ObservableObject {

    // MARK: 对外状态

    @Published private(set) var vault = Vault()
    @Published private(set) var isLocked = true
    @Published private(set) var hasVault = false
    @Published private(set) var busy = false
    @Published var toast: String?

    let fileURL: URL

    // MARK: 私有

    private var file: VaultFile?
    private var key: SymmetricKey?
    private var backgroundedAt: Date?
    private var toastTask: Task<Void, Never>?

    var faceIDEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.faceID)
    }

    var autoLockSeconds: Double {
        UserDefaults.standard.double(forKey: SettingsKeys.autoLockSeconds)
    }

    var canUseFaceID: Bool {
        faceIDEnabled && Biometrics.available() && BioKeychain.exists()
    }

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("vault.mxv")
        hasVault = FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - 创建 / 解锁 / 锁定

    func create(pin: String) async throws {
        busy = true
        defer { busy = false }

        let fresh = Vault()
        let result = try await Task.detached(priority: .userInitiated) {
            try VaultCrypto.create(pin: pin, vault: fresh)
        }.value

        try write(result.data)
        vault = fresh
        file = try VaultFile.parse(result.data)
        key = result.key
        hasVault = true
        isLocked = false
        storeBioKey(result.key)
    }

    func unlock(pin: String) async throws {
        busy = true
        defer { busy = false }

        let url = fileURL
        let result = try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try VaultCrypto.unlock(fileData: data, pin: pin)
        }.value

        apply(result)
        storeBioKey(result.key)
    }

    /// 返回 true 表示用面容解锁成功
    @discardableResult
    func unlockWithFaceID() async -> Bool {
        guard faceIDEnabled else { return false }

        let loaded = await Task.detached(priority: .userInitiated) { BioKeychain.load() }.value
        guard let keyData = loaded else { return false }

        let url = fileURL
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: url)
                return try VaultCrypto.unlock(fileData: data, key: SymmetricKey(data: keyData))
            }.value
            apply(result)
            return true
        } catch {
            return false
        }
    }

    func lock() {
        vault = Vault()
        key = nil
        file = nil
        isLocked = true
    }

    private func apply(_ unlocked: Unlocked) {
        vault = unlocked.vault
        key = unlocked.key
        file = unlocked.file
        hasVault = true
        isLocked = false
    }

    private func storeBioKey(_ key: SymmetricKey) {
        guard faceIDEnabled, Biometrics.available() else { return }
        let raw = key.withUnsafeBytes { Data($0) }
        try? BioKeychain.save(raw)
    }

    /// 设置里切换 Face ID 开关时调用
    func syncFaceIDKey() {
        let enabled = UserDefaults.standard.bool(forKey: SettingsKeys.faceID)
        if !enabled {
            BioKeychain.delete()
            return
        }
        guard let key, Biometrics.available() else { return }
        try? BioKeychain.save(key.withUnsafeBytes { Data($0) })
    }

    // MARK: - 前后台

    func appWillResignActive() {
        backgroundedAt = Date()
    }

    func appDidBecomeActive() {
        guard !isLocked else { backgroundedAt = nil; return }
        guard let left = backgroundedAt else { return }
        backgroundedAt = nil

        let interval = autoLockSeconds
        if interval < 0 { return }                                   // 永不
        if interval == 0 { lock(); return }                          // 立即
        if Date().timeIntervalSince(left) >= interval { lock() }
    }

    // MARK: - 保存

    private func write(_ data: Data) throws {
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            showToast("写入失败")
            throw VaultError.writeFailed
        }
    }

    private func persist() {
        guard let file, let key else { return }
        do {
            let (data, updated) = try VaultCrypto.save(vault, file: file, key: key)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            self.file = updated
        } catch {
            showToast("保存失败")
        }
    }

    // MARK: - 条目

    func item(_ id: UUID) -> VaultItem? {
        vault.items.first { $0.id == id }
    }

    func upsert(_ item: VaultItem) {
        var value = item
        value.updatedAt = Date()
        if let index = vault.items.firstIndex(where: { $0.id == value.id }) {
            vault.items[index] = value
        } else {
            value.createdAt = Date()
            vault.items.insert(value, at: 0)
        }
        vault.updatedAt = Date()
        persist()
    }

    func delete(_ id: UUID) {
        vault.items.removeAll { $0.id == id }
        vault.updatedAt = Date()
        persist()
        showToast("已删除")
    }

    func addCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !vault.usedCategories.contains(trimmed) else { return }
        if !vault.categories.contains(trimmed) {
            vault.categories.append(trimmed)
            persist()
        }
    }

    // MARK: - 改 PIN

    func changePIN(to newPIN: String) throws {
        guard let file, let key else { throw VaultError.notUnlocked }
        let data = try VaultCrypto.changePIN(file: file, key: key, newPIN: newPIN)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        self.file = try VaultFile.parse(data)
        syncFaceIDKey()
        showToast("数字密码已更新")
    }

    // MARK: - 备份

    func exportData() -> Data? {
        try? Data(contentsOf: fileURL)
    }

    func importBackup(_ data: Data, pin: String) async throws {
        let result = try await Task.detached(priority: .userInitiated) {
            try VaultCrypto.unlock(fileData: data, pin: pin)
        }.value
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        apply(result)
        storeBioKey(result.key)
        showToast("备份已恢复")
    }

    func wipeAll() {
        try? FileManager.default.removeItem(at: fileURL)
        BioKeychain.delete()
        vault = Vault()
        file = nil
        key = nil
        hasVault = false
        isLocked = true
        showToast("已清空")
    }

    // MARK: - 提示

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
