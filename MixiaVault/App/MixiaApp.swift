import SwiftUI
import UIKit
import Combine

@main
struct MixiaApp: App {
    @StateObject private var store = VaultStore()

    init() {
        UserDefaults.standard.register(defaults: [
            SettingsKeys.autoLockSeconds: 30.0,
            SettingsKeys.faceID: true,
            SettingsKeys.conceal: true
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 根视图

struct RootView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.conceal) private var conceal = true

    @State private var covered = false
    @State private var captured = false

    private var showCover: Bool {
        covered || (conceal && captured)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if store.isLocked {
                LockView()
            } else {
                MainView()
            }

            toastLayer

            if showCover {
                CoverView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: showCover)
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                store.appDidBecomeActive()
                covered = false
            case .inactive:
                covered = true
            case .background:
                covered = true
                store.appWillResignActive()
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            captured = UIScreen.main.isCaptured
        }
    }

    private var toastLayer: some View {
        VStack {
            if let text = store.toast {
                ToastView(text: text)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.easeOut(duration: 0.2), value: store.toast)
        .allowsHitTesting(false)
    }
}

// MARK: - 主框架

struct MainView: View {
    var body: some View {
        NavigationStack {
            VaultListView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .detail(let id):
                        ItemDetailView(itemID: id)
                    case .settings:
                        SettingsView()
                    case .editor(let id):
                        ItemEditorView(itemID: id)
                    }
                }
        }
        .tint(Theme.accent)
    }
}

// MARK: - 遮罩

struct CoverView: View {
    var body: some View {
        ZStack {
            Theme.bg
                .opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.logoGradient)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundColor(Color(hex: 0x04150F))
                    )

                Text("密匣 · 内容已隐藏")
                    .font(Theme.sans(11))
                    .tracking(1.4)
                    .foregroundColor(Theme.muted2)
            }
        }
        .transition(.opacity)
    }
}
