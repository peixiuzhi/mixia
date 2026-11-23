import SwiftUI
import UIKit

struct ItemDetailView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID

    @State private var revealed = false
    @State private var revealTask: Task<Void, Never>?
    @State private var showDelete = false

    private enum RowAction {
        case copy(String)
        case open(String)
        case reveal
    }

    private var item: VaultItem? { store.item(itemID) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let item {
                VStack(spacing: 0) {
                    navBar
                    ScrollView {
                        VStack(spacing: 0) {
                            hero(item)
                            fields(item)
                            footer(item)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            revealTask?.cancel()
            revealed = false
        }
        .confirmationDialog("删除这条？删了就找不回来了", isPresented: $showDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.delete(itemID)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 导航栏

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            NavigationLink(value: Route.editor(itemID)) {
                Text("编辑")
                    .font(Theme.sans(13.5, .medium))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 8)
                    .frame(height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: - 顶部

    private func hero(_ item: VaultItem) -> some View {
        VStack(spacing: 0) {
            AvatarView(title: item.title, size: 60)
                .padding(.top, 8)

            Text(item.title)
                .font(Theme.sans(21, .semibold))
                .foregroundColor(Theme.text)
                .padding(.top, 12)

            if !item.url.isEmpty {
                Text(item.url)
                    .font(Theme.sans(12))
                    .foregroundColor(Theme.muted)
                    .padding(.top, 5)
            } else if !item.category.isEmpty {
                Text(item.category)
                    .font(Theme.sans(12))
                    .foregroundColor(Theme.muted)
                    .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 22)
    }

    // MARK: - 字段

    private func fields(_ item: VaultItem) -> some View {
        VStack(spacing: 0) {
            row("账号",
                value: item.account.isEmpty ? "—" : item.account,
                actions: item.account.isEmpty ? [] : [.copy(item.account)])
            divider
            row("密码",
                value: revealed ? item.password : String(repeating: "•", count: max(6, min(item.password.count, 14))),
                mono: true,
                color: revealed ? Theme.accent : Theme.text,
                actions: [.reveal, .copy(item.password)])
            if !item.url.isEmpty {
                divider
                row("网址", value: item.url, actions: [.open(item.url), .copy(item.url)])
            }
            if !item.note.isEmpty {
                divider
                noteRow(item.note)
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
            .padding(.leading, 14)
    }

    private func row(_ label: String,
                     value: String,
                     mono: Bool = false,
                     color: Color = Theme.text,
                     actions: [RowAction]) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Theme.sans(11))
                .foregroundColor(Theme.muted2)
                .frame(width: 46, alignment: .leading)

            Text(value)
                .font(mono ? Theme.mono(13.5) : Theme.sans(13.5))
                .foregroundColor(color)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                ForEach(actions.indices, id: \.self) { index in
                    actionButton(actions[index])
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }

    @ViewBuilder
    private func actionButton(_ action: RowAction) -> some View {
        switch action {
        case .copy(let text):
            IconSquareButton(systemName: "doc.on.doc") {
                Clipboard.copy(text)
                store.showToast("已复制 · 30 秒后清除")
                Haptics.success()
            }
        case .open(let url):
            IconSquareButton(systemName: "arrow.up.right.square") {
                openURL(url)
            }
        case .reveal:
            IconSquareButton(systemName: revealed ? "eye.slash" : "eye") {
                toggleReveal()
            }
        }
    }

    private func noteRow(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("备注")
                .font(Theme.sans(11))
                .foregroundColor(Theme.muted2)
            Text(note)
                .font(Theme.sans(12.5))
                .foregroundColor(Color(hex: 0xB9C5D4))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - 底部

    private func footer(_ item: VaultItem) -> some View {
        VStack(spacing: 0) {
            Button {
                Clipboard.copy(item.password)
                store.showToast("已复制 · 30 秒后清除")
                Haptics.success()
            } label: {
                Text("复制密码")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 14)

            Text("复制后 30 秒自动从剪贴板清除")
                .font(Theme.sans(10))
                .foregroundColor(Theme.muted2)
                .padding(.top, 9)

            VStack(spacing: 4) {
                Text("创建于 \(formattedDate(item.createdAt))　更新于 \(formattedDate(item.updatedAt))")
                    .font(Theme.sans(10))
                    .foregroundColor(Color(hex: 0x465262))
            }
            .padding(.top, 22)

            Button {
                showDelete = true
            } label: {
                Text("删除这条")
                    .font(Theme.sans(13, .medium))
                    .foregroundColor(Theme.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Theme.red.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
    }

    // MARK: - 动作

    private func toggleReveal() {
        revealed.toggle()
        revealTask?.cancel()
        guard revealed else { return }
        revealTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            revealed = false
        }
    }

    private func openURL(_ string: String) {
        let normalized = string.contains("://") ? string : "https://\(string)"
        guard let url = URL(string: normalized) else { return }
        UIApplication.shared.open(url)
    }
}
