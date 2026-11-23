import SwiftUI

struct LockView: View {
    @EnvironmentObject private var store: VaultStore
    @AppStorage(SettingsKeys.faceID) private var faceIDEnabled = true

    @State private var pin = ""
    @State private var firstPIN: String?
    @State private var message = ""
    @State private var working = false
    @State private var autoTried = false

    private var isCreating: Bool { !store.hasVault }

    private var prompt: String {
        if isCreating {
            return firstPIN == nil ? "设置 6 位数字密码" : "再输一次确认"
        }
        return "输入 6 位数字密码"
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 30)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.logoGradient)
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(Color(hex: 0x04150F))
                    )
                    .shadow(color: Theme.accent.opacity(0.45), radius: 18, y: 8)

                Text("密匣")
                    .font(Theme.sans(23, .bold))
                    .tracking(6)
                    .foregroundColor(Theme.text)
                    .padding(.top, 16)

                Text("本机加密 · 不上网")
                    .font(Theme.sans(11))
                    .tracking(0.6)
                    .foregroundColor(Theme.muted2)
                    .padding(.top, 7)

                HStack(spacing: 14) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(index < pin.count ? Theme.accent : Color.white.opacity(0.12))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle().stroke(index < pin.count ? Theme.accent : Color.white.opacity(0.16), lineWidth: 1)
                            )
                            .shadow(color: index < pin.count ? Theme.accent.opacity(0.6) : .clear, radius: 6)
                    }
                }
                .padding(.top, 32)
                .animation(.easeOut(duration: 0.12), value: pin.count)

                Text(message.isEmpty ? prompt : message)
                    .font(Theme.sans(11.5))
                    .foregroundColor(message.isEmpty ? Theme.muted2 : Theme.red)
                    .padding(.top, 13)
                    .frame(height: 18)

                keypad
                    .padding(.top, 18)

                Spacer(minLength: 6)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            // 等一拍再弹面容，避免 App 还没变成 active 就调起生物识别
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                autoUnlock()
            }
        }
    }

    // MARK: - 背景

    private var background: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.accent.opacity(0.14), .clear],
                           center: .top,
                           startRadius: 0,
                           endRadius: 420)
        }
        .ignoresSafeArea()
    }

    // MARK: - 键盘

    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 3), spacing: 11) {
            ForEach(1...9, id: \.self) { number in
                digitKey("\(number)")
            }
            faceIDKey
            digitKey("0")
            deleteKey
        }
        .frame(maxWidth: 282)
    }

    private func digitKey(_ text: String) -> some View {
        Button {
            tap(text)
        } label: {
            Text(text)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(Theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    private var faceIDKey: some View {
        Button {
            autoUnlock(force: true)
        } label: {
            Image(systemName: "faceid")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(isCreating ? Theme.muted2.opacity(0.4) : Theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCreating || working)
    }

    private var deleteKey: some View {
        Button {
            guard !pin.isEmpty else { return }
            pin.removeLast()
            message = ""
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 19, weight: .regular))
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(working)
    }

    // MARK: - 输入

    private func tap(_ digit: String) {
        guard !working, pin.count < 6 else { return }
        message = ""
        pin.append(digit)
        Haptics.tap()
        if pin.count == 6 {
            finish()
        }
    }

    private func finish() {
        let entered = pin

        if isCreating {
            if let first = firstPIN {
                guard first == entered else {
                    firstPIN = nil
                    fail("两次不一致，重新设置")
                    return
                }
                working = true
                Task {
                    do {
                        try await store.create(pin: entered)
                        pin = ""
                    } catch {
                        fail(error.localizedDescription)
                    }
                    working = false
                }
            } else {
                firstPIN = entered
                pin = ""
            }
            return
        }

        working = true
        Task {
            do {
                try await store.unlock(pin: entered)
                pin = ""
            } catch {
                fail("密码不对")
            }
            working = false
        }
    }

    private func fail(_ text: String) {
        message = text
        pin = ""
        Haptics.success()
    }

    private func autoUnlock(force: Bool = false) {
        guard !isCreating, faceIDEnabled, !working else { return }
        if !force && autoTried { return }
        autoTried = true
        guard BioKeychain.exists() else { return }

        working = true
        Task {
            let ok = await store.unlockWithFaceID()
            if !ok { message = "面容没通过，输密码吧" }
            working = false
        }
    }
}
