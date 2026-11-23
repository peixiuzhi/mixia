import Foundation

// MARK: - 条目

struct VaultItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var category: String = ""
    var account: String = ""
    var password: String = ""
    var url: String = ""
    var note: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// 列表里显示的第二行：账号 · 网址
    var subtitle: String {
        var parts: [String] = []
        if !account.isEmpty { parts.append(account) }
        if !url.isEmpty { parts.append(url) }
        return parts.joined(separator: " · ")
    }

    var initial: String {
        String(title.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }
}

// MARK: - 保险库

struct Vault: Codable {
    var version: Int = 1
    var items: [VaultItem] = []
    var categories: [String] = ["工作", "生活", "金融"]
    var updatedAt: Date = Date()

    func count(in category: String) -> Int {
        items.filter { $0.category == category }.count
    }

    var usedCategories: [String] {
        // 分类栏顺序：先按定义顺序，再补上条目里出现过但列表里没有的
        var list = categories
        for item in items where !item.category.isEmpty && !list.contains(item.category) {
            list.append(item.category)
        }
        return list
    }
}

// MARK: - 路由

enum Route: Hashable {
    case detail(UUID)
    case settings
    case editor(UUID?)
}
