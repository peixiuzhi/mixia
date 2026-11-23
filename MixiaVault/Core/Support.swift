import Foundation
import UIKit
import UniformTypeIdentifiers
import LocalAuthentication

// MARK: - 设置项

enum SettingsKeys {
    static let autoLockSeconds = "autoLockSeconds"   // 0 = 立即，-1 = 永不
    static let faceID = "faceIDEnabled"
    static let conceal = "concealInCapture"
    static let firstInstall = "firstInstallDate"
}

// MARK: - 剪贴板

enum Clipboard {
    /// 复制到剪贴板，30 秒后系统自动清空
    static func copy(_ text: String) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: text]],
            options: [.expirationDate: Date().addingTimeInterval(30)]
        )
    }
}

// MARK: - 生物识别

enum Biometrics {
    static func available() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}

// MARK: - 签名剩余天数

enum Provisioning {
    /// 从 App 包里的 embedded.mobileprovision 读 ExpirationDate。
    /// 未签名（还没用爱思助手签）时读不到，退化到「首次启动 + 7 天」。
    static func expiryDate() -> Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>")
        else { return nil }

        let plistText = String(text[start.lowerBound..<end.upperBound])
        guard let plistData = plistText.data(using: .isoLatin1),
              let object = try? PropertyListSerialization.propertyList(from: plistData, format: nil),
              let dict = object as? [String: Any],
              let expiry = dict["ExpirationDate"] as? Date
        else { return nil }
        return expiry
    }

    static func daysLeft() -> Int? {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: SettingsKeys.firstInstall) == nil {
            defaults.set(Date(), forKey: SettingsKeys.firstInstall)
        }

        if let expiry = expiryDate() {
            return max(0, Int(ceil(expiry.timeIntervalSinceNow / 86_400)))
        }
        guard let installed = defaults.object(forKey: SettingsKeys.firstInstall) as? Date else { return nil }
        let expiry = installed.addingTimeInterval(7 * 86_400)
        return max(0, Int(ceil(expiry.timeIntervalSinceNow / 86_400)))
    }

    static func expiryText() -> String {
        guard let date = expiryDate() ?? fallbackExpiry() else { return "未知" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日到期"
        return f.string(from: date)
    }

    private static func fallbackExpiry() -> Date? {
        guard let installed = UserDefaults.standard.object(forKey: SettingsKeys.firstInstall) as? Date else { return nil }
        return installed.addingTimeInterval(7 * 86_400)
    }
}

// MARK: - 小工具

func formattedDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

func mediumDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "M 月 d 日"
    return f.string(from: date)
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

enum PasswordGen {
    private static let sets = (
        upper: Array("ABCDEFGHJKLMNPQRSTUVWXYZ"),
        lower: Array("abcdefghijkmnopqrstuvwxyz"),
        digits: Array("23456789"),
        symbols: Array("!@#$%^&*-_=+?")
    )

    static func password(length: Int = 16) -> String {
        let pool = sets.upper + sets.lower + sets.digits + sets.symbols
        return String((0..<length).map { _ in pool[Int.random(in: 0..<pool.count)] })
    }
}
