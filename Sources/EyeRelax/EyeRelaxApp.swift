import SwiftUI

@main
struct EyeRelaxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        Window("Eye Relax", id: "main") {
            MainWindowView()
                .environmentObject(appState)
        }
        .defaultSize(width: 780, height: 540)

        MenuBarExtra("Eye Relax", systemImage: "eye") {
            MenuBarView(runner: appState.runner, scheduler: appState.scheduler)
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.applyActivationPolicy()
        Notifier.requestPermissionIfNeeded()
    }

    // Đóng cửa sổ chính app vẫn chạy nền (scheduler + menu bar).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
