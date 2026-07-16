import SwiftUI
import UserNotifications

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

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.applyActivationPolicy()
        Notifier.requestPermissionIfNeeded()
        AppState.shared.autoCheckUpdatesIfEnabled()
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    // Đóng cửa sổ chính app vẫn chạy nền (scheduler + menu bar).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Nút hành động trên thông báo

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            let appState = AppState.shared
            switch response.actionIdentifier {
            case Notifier.startAction:
                appState.startSession()
            case Notifier.snoozeAction:
                appState.snooze()
            case UNNotificationDefaultActionIdentifier:
                // Click vào thân thông báo → mở app.
                NSApp.activate(ignoringOtherApps: true)
            default:
                break
            }
            completionHandler()
        }
    }

    // Hiện thông báo cả khi app đang ở foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
