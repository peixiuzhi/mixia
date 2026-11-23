import SwiftUI

struct VaultListView: View {
    @EnvironmentObject private var store: VaultStore

    @State private var query = ""
    @State private var activeCategory: String?
    @State private var showNewCategory = false
    @State private var newCategoryName = ""
    @State private var signatureDays: Int?

    private var categories: [String] { store.vault.usedCategories }

    private var filtered: [VaultItem] {
        var items = store.vault.items
        if let activeCategory {
            items = items.filter { $0.category == activeCategory }
        }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !term.isEmpty {
            items = items.filter {
                $0.title.lowercased().contains(term)
                || $0.account.lowercased().contains(term)
                || $0.url.lowercased().contains(term)
                || $0.note.lowercased().contains(term)
            }
        }
        return items.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var subtitle: String {
        if !query.isEmpty { return "\(filtered.count) 个结果" }
        if let activeCategory { return "\(activeCategory) · \(filtered.count) 个条目" }
        return "\(store.vault.items.count) 个条目 · 只在这台手机"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            categoryBar
            itemList
            signatureStrip
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { signatureDays = Provisioning.daysLeft() }
        .alert("新分类", isPresented: $showNewCategory) {
            TextField("分类名", text: $newCategoryName)
            Button("取消", role: .cancel) { newCategoryName = "" }
            Button("添加") {
                store.addCategory(newCategoryName)
                newCategoryName = ""
            }
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(subtitle)
                    .font(Theme.sans(10.5))
                    .tracking(1.2)
                    .foregroundColor(Theme.muted2)
                Text("全部密码")
                    .font(Theme.sans(28, .bold))
                    .foregroundColor(Theme.text)
            }
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.muted)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Theme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                NavigationLink(value: Route.editor(nil)) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(Theme.accent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: - 搜索

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.muted2)
            TextField("搜索名字、账号或网址", text: $query)
                .font(Theme.sans(13))
                .foregroundColor(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - 分类

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                CategoryChip(title: "全部",
                             selected: activeCategory == nil,
                             count: store.vault.items.count) {
                    activeCategory = nil
                }

                ForEach(categories, id: \.self) { category in
                    CategoryChip(title: category,
                                 selected: activeCategory == category,
                                 count: store.vault.count(in: category)) {
                        activeCategory = (activeCategory == category) ? nil : category
                    }
                }

                Button {
                    showNewCategory = true
                } label: {
                    Text("+ 新分类")
                        .font(Theme.sans(12))
                        .foregroundColor(Theme.muted2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.line2, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 11)
    }

    // MARK: - 列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(filtered) { item in
                        row(item)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
    }

    private func row(_ item: VaultItem) -> some View {
        ZStack(alignment: .trailing) {
            NavigationLink(value: Route.detail(item.id)) {
                HStack(spacing: 12) {
                    AvatarView(title: item.title)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(Theme.sans(14, .medium))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                        Text(item.subtitle.isEmpty ? "—" : item.subtitle)
                            .font(Theme.sans(11))
                            .foregroundColor(Theme.muted2)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 44)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                Clipboard.copy(item.password)
                store.showToast("已复制 · 30 秒后清除")
                Haptics.success()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted2)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "key.slash")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(Theme.muted2)
            Text(activeCategory == nil ? "还没有条目，点右上角 + 记一条" : "这个分类下还没有东西")
                .font(Theme.sans(12))
                .foregroundColor(Theme.muted2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    // MARK: - 底部签名状态

    private var signatureStrip: some View {
        let days = signatureDays
        let warning = (days ?? 99) <= 2
        return HStack(spacing: 7) {
            Circle()
                .fill(warning ? Theme.amber : Theme.accent)
                .frame(width: 5, height: 5)
            Text(days == nil ? "已加密" : "已加密 · 签名剩 \(days!) 天")
                .font(Theme.sans(10))
                .foregroundColor(warning ? Color(hex: 0xE9D6AC) : Color(hex: 0x4A5666))
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}
