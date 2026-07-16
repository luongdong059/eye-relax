import AppKit
import UserNotifications

/// Gửi thông báo "tới giờ tập mắt". `UNUserNotificationCenter` yêu cầu app
/// chạy trong bundle (.app) — khi chạy `swift run` (không có bundle id) thì
/// fallback sang beep để dev vẫn thấy tín hiệu.
enum Notifier {

    private static var isBundled: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestPermissionIfNeeded() {
        guard isBundled else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func postSessionReady() {
        guard isBundled else {
            NSSound.beep()
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Đến giờ tập mắt 👀"
        content.body = "Mở menu bar (biểu tượng con mắt) và bấm Bắt đầu ngay."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
