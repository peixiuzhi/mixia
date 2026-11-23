import SwiftUI
import UIKit

struct ItemEditorView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID?

    @State private var draft = VaultItem()
    @State private var didLoad = false
    @State private var addingCategory = false
    @State private var newCategory = ""

    private var isEditing: Bool { itemID != nil }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    textField("名字", text: $draft.title, placeholder: "比如 GitHub、家里 Wi-Fi")
                    categorySection
                    textField("账号", text: $draft.account, placeholder: "用户名 / 手机号 / 邮箱")
                    passwordSection
                    textField("网址（可不填）", text: $draft.url, placeholder: "github.com", keyboard: .URL)
                    noteSection

                    Button {
                        save()
                    } label: {
                        Text("保存")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: - 顶部

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(Theme.sans(13.5))
                    .foregroundColor(Theme.muted)
                    .frame(height: 36)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(isEditing ? "编辑" : "记一条")
                .font(Theme.sans(13.5, .semibold))
                .foregroundColor(Theme.text)

            Spacer()

            Button {
                save()
            } label: {
                Text("保存")
                    .font(Theme.sans(13.5, .medium))
                    .foregroundColor(Theme.accent)
                    .frame(height: 36)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: - 基础输入框

    private func textField(_ label: String,
                           text: Binding<String>,
                           placeholder: String,
                           mono: Bool = false,
                           keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.sans(10.5))
                .tracking(0.6)
                .foregroundColor(Theme.muted2)
                .padding(.leading, 3)

            TextField(placeholder, text: text)
                .font(mono ? Theme.mono(13.5) : Theme.sans(13.5))
                .foregroundColor(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.line, lineWidth: 1)
                )
        }
    }

    // MARK: - 分类

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("分类")
                .font(Theme.sans(10.5))
                .tracking(0.6)
                .foregroundColor(Theme.muted2)
                .padding(.leading, 3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.vault.usedCategories, id: \.self) { category in
                        CategoryChip(title: category, selected: draft.category == category) {
                            draft.category = (draft.category == category) ? "" : category
                        }
                    }

                    if addingCategory {
                        TextField("分类名", text: $newCategory)
                            .font(Theme.sans(12))
                            .foregroundColor(Theme.text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(commitCategory)
                            .padding(.horizontal, 10)
                            .frame(width: 110, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.accent.opacity(0.45), lineWidth: 1)
                            )
                    } else {
                        Button {
                            addingCategory = true
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
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func commitCategory() {
        let name = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            addingCategory = false
            return
        }
        store.addCategory(name)
        draft.category = name
        newCategory = ""
        addingCategory = false
    }

    // MARK: - 密码

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("密码")
                .font(Theme.sans(10.5))
                .tracking(0.6)
                .foregroundColor(Theme.muted2)
                .padding(.leading, 3)

            HStack(spacing: 8) {
                TextField("密码", text: $draft.password)
                    .font(Theme.mono(13.5))
                    .foregroundColor(Theme.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)

                Button {
                    draft.password = PasswordGen.password()
                    Haptics.tap()
                    store.showToast("生成了 16 位密码")
                } label: {
                    Text("随机生成")
                        .font(Theme.sans(11.5, .medium))
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .frame(height: 44)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
        }
    }

    // MARK: - 备注

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("备注（可不填）")
                .font(Theme.sans(10.5))
                .tracking(0.6)
                .foregroundColor(Theme.muted2)
                .padding(.leading, 3)

            ZStack(alignment: .topLeading) {
                if draft.note.isEmpty {
                    Text("记点只有自己看得懂的东西")
                        .font(Theme.sans(13))
                        .foregroundColor(Color(hex: 0x4E5A6B))
                        .padding(.horizontal, 13)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft.note)
                    .font(Theme.sans(13))
                    .foregroundColor(Theme.text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .frame(minHeight: 92)
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
        }
    }

    // MARK: - 存取

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if let itemID, let existing = store.item(itemID) {
            draft = existing
        } else if draft.category.isEmpty {
            draft.category = store.vault.usedCategories.first ?? ""
        }
    }

    private func save() {
        var value = draft
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.account = value.account.trimmingCharacters(in: .whitespacesAndNewlines)
        value.url = value.url.trimmingCharacters(in: .whitespacesAndNewlines)

        // 分类输入框里打了字但没按回车，保存时补上
        if addingCategory {
            let name = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                store.addCategory(name)
                value.category = name
            }
        }

        guard !value.title.isEmpty else {
            store.showToast("先起个名字")
            return
        }

        store.upsert(value)
        Haptics.success()
        store.showToast("已保存")
        dismiss()
    }
}
