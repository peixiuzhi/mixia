import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.faceID) private var faceIDEnabled = true
    @AppStorage(SettingsKeys.autoLockSeconds) private var autoLockSeconds = 30.0
    @AppStorage(SettingsKeys.conceal) private var conceal = true

    @State private var days: Int?
    @State private var showAutoLock = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var backupData = Data()
    @State private var pendingImport: Data?
    @State private var showImportPIN = false
    @State private var importPIN = ""
    @State private var showChangePIN = false
    @State private var showWipe = false

    private let backupType = UTType(exportedAs: "com.mixia.vault.backup")

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    signatureCard
                    unlockGroup
                    dataGroup
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { days = Provisioning.daysLeft() }
        .onChange(of: faceIDEnabled) { _ in
            store.syncFaceIDKey()
        }
        .confirmationDialog("离开多久后自动上锁", isPresented: $showAutoLock, titleVisibility: .visible) {
            Button("立即") { autoLockSeconds = 0 }
            Button("30 秒") { autoLockSeconds = 30 }
            Button("1 分钟") { autoLockSeconds = 60 }
            Button("5 分钟") { autoLockSeconds = 300 }
            Button("永不") { autoLockSeconds = -1 }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("清空所有密码？", isPresented: $showWipe, titleVisibility: .visible) {
            Button("清空，删掉全部数据", role: .destructive) { store.wipeAll() }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showChangePIN) {
            ChangePINSheet()
                .environmentObject(store)
        }
        .fileExporter(isPresented: $showExporter,
                      document: BackupDocument(data: backupData),
                      contentType: backupType,
                      defaultFilename: "密匣备份") { result in
            switch result {
            case .success: store.showToast("备份已导出")
            case .failure: store.showToast("导出取消")
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [backupType, .data],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert("恢复备份", isPresented: $showImportPIN) {
            SecureField("备份的数字密码", text: $importPIN)
            Button("取消", role: .cancel) {
                pendingImport = nil
                importPIN = ""
            }
            Button("恢复") { performImport() }
        } message: {
            Text("需要这个备份当初的 6 位数字密码")
        }
    }

    // MARK: - 顶部

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

            Text("设置")
                .font(Theme.sans(13.5, .semibold))
                .foregroundColor(Theme.text)

            Spacer()

            Color.clear.frame(width: 40, height: 36)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: - 签名有效期

    private var signatureCard: some View {
        let left = days ?? 7
        let warning = left <= 2
        let progress: CGFloat = min(1, CGFloat(left) / 7)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("签名有效期")
                    .font(Theme.sans(10.5))
                    .tracking(1.2)
                    .foregroundColor(Theme.muted2)
                Spacer()
                Text("剩 \(left) 天")
                    .font(Theme.sans(17, .semibold))
                    .foregroundColor(warning ? Theme.amber : Theme.accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(warning ? Theme.amber : Theme.accent)
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 6)
            .padding(.top, 11)

            HStack {
                Text(Provisioning.expiryText())
                    .font(Theme.sans(10.5))
                    .foregroundColor(Theme.muted2)
                Spacer()
                Text("免费 Apple ID · 7 天")
                    .font(Theme.sans(10.5))
                    .foregroundColor(Theme.muted2)
            }
            .padding(.top, 8)

            Text("到期前用爱思助手「覆盖安装」重签，别卸载。到期后 App 打不开，但数据还在。")
                .font(Theme.sans(11))
                .foregroundColor(Color(hex: 0x8E9AAB))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        .padding(14)
        .background(warning ? Theme.amber.opacity(0.06) : Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(warning ? Theme.amber.opacity(0.28) : Theme.line, lineWidth: 1)
        )
        .padding(.top, 8)
    }

    // MARK: - 解锁

    private var unlockGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupLabel(text: "解 锁")

            VStack(spacing: 0) {
                HStack {
                    Text("Face ID 解锁")
                        .font(Theme.sans(13.5))
                        .foregroundColor(Theme.text)
                    Spacer()
                    Toggle("", isOn: $faceIDEnabled)
                        .labelsHidden()
                        .tint(Theme.accentDeep)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)

                divider

                Button {
                    showAutoLock = true
                } label: {
                    HStack {
                        Text("自动锁定")
                            .font(Theme.sans(13.5))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Text(autoLockLabel)
                            .font(Theme.sans(11.5))
                            .foregroundColor(Theme.muted2)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: 0x48576A))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                divider

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("录屏时隐藏内容")
                            .font(Theme.sans(13.5))
                            .foregroundColor(Theme.text)
                        Text("录屏、投屏时整屏盖上遮罩")
                            .font(Theme.sans(10.5))
                            .foregroundColor(Theme.muted2)
                    }
                    Spacer()
                    Toggle("", isOn: $conceal)
                        .labelsHidden()
                        .tint(Theme.accentDeep)
                }
                .padding(.horizontal, 14)
                .frame(height: 58)

                divider

                Button {
                    store.lock()
                } label: {
                    HStack {
                        Text("立即锁定")
                            .font(Theme.sans(13.5))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: 0x48576A))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
        }
    }

    // MARK: - 数据

    private var dataGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupLabel(text: "数 据")

            VStack(spacing: 0) {
                Button {
                    backupData = store.exportData() ?? Data()
                    showExporter = true
                } label: {
                    HStack {
                        Text("导出备份文件")
                            .font(Theme.sans(13.5))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Text(".mxvault")
                            .font(Theme.mono(11))
                            .foregroundColor(Theme.muted2)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                divider

                Button {
                    showImporter = true
                } label: {
                    HStack {
                        Text("从备份恢复")
                            .font(Theme.sans(13.5))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: 0x48576A))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                divider

                Button {
                    showChangePIN = true
                } label: {
                    HStack {
                        Text("改数字密码")
                            .font(Theme.sans(13.5))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: 0x48576A))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                divider

                Button {
                    showWipe = true
                } label: {
                    HStack {
                        Text("清空所有密码")
                            .font(Theme.sans(13.5))
                            .foregroundColor(Theme.red)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
            .padding(.leading, 14)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("密匣 1.0 · \(store.vault.items.count) 个条目")
                .font(Theme.sans(10.5))
                .foregroundColor(Color(hex: 0x475262))
            Text("数据只存在这台手机里，不联网、不上传")
                .font(Theme.sans(10.5))
                .foregroundColor(Color(hex: 0x475262))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    private var autoLockLabel: String {
        let value = autoLockSeconds
        if value < 0 { return "永不" }
        if value == 0 { return "立即" }
        if value < 60 { return "\(Int(value)) 秒" }
        return "\(Int(value / 60)) 分钟"
    }

    // MARK: - 恢复备份

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            store.showToast("读不到这个文件")
            return
        }
        pendingImport = data
        importPIN = ""
        showImportPIN = true
    }

    private func performImport() {
        guard let data = pendingImport, importPIN.count == 6 else {
            store.showToast("请输入 6 位数字密码")
            return
        }
        let pin = importPIN
        pendingImport = nil
        importPIN = ""
        Task {
            do {
                try await store.importBackup(data, pin: pin)
            } catch {
                store.showToast(error.localizedDescription)
            }
        }
    }
}

// MARK: - 备份文件

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(exportedAs: "com.mixia.vault.backup"), .data]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 改密码

struct ChangePINSheet: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    @State private var fresh = ""
    @State private var confirm = ""
    @State private var error = ""

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("改数字密码")
                .font(Theme.sans(16, .semibold))
                .foregroundColor(Theme.text)

            pinField("新密码（6 位数字）", text: $fresh)
            pinField("再输一次", text: $confirm)

            if !error.isEmpty {
                Text(error)
                    .font(Theme.sans(11))
                    .foregroundColor(Theme.red)
            }

            Button {
                submit()
            } label: {
                Text("确认修改")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func pinField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.sans(10.5))
                .foregroundColor(Theme.muted2)
                .padding(.leading, 3)
            SecureField("6 位数字", text: text)
                .keyboardType(.numberPad)
                .font(Theme.mono(15))
                .foregroundColor(Theme.text)
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

    private func submit() {
        error = ""
        guard fresh.count == 6, fresh.allSatisfy(\.isNumber) else {
            error = "新密码要 6 位数字"
            return
        }
        guard fresh == confirm else {
            error = "两次输入不一致"
            return
        }
        do {
            try store.changePIN(to: fresh)
            Haptics.success()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
