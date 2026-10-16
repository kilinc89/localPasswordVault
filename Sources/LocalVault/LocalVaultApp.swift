import SwiftUI
import AppKit
import VaultCore

@main
struct LocalVaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("LocalVault") {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 760, minHeight: 480)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(L("Kasa", "Vault")) {
                Button(L("Kilitle", "Lock")) { state.lock() }
                    .keyboardShortcut("l", modifiers: .command)
                    .disabled(state.phase != .unlocked)
                Divider()
                LanguagePicker(state: state)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare SwiftPM executable (outside an .app bundle).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            switch state.phase {
            case .setup: SetupView()
            case .locked: UnlockView()
            case .unlocked: VaultView()
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = state.toast {
                Text(toast)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { state.toast = nil }
                    }
            }
        }
        .animation(.default, value: state.toast)
        // Strings are resolved when views are built, so rebuild the tree when the language changes.
        .id(state.language)
        .environment(\.locale, state.language.locale)
    }
}

/// Language submenu, used in the Settings toolbar menu and the Vault menu bar menu.
struct LanguagePicker: View {
    @ObservedObject var state: AppState

    var body: some View {
        Picker(L("Dil", "Language"), selection: $state.language) {
            ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.menu)
    }
}
