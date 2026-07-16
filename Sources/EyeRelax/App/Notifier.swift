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
        post(title: "Đến giờ tập mắt 👀",
             body: "Mở menu bar (biểu tượng con mắt) và bấm Bắt đầu ngay.")
    }

    static func postUpdateAvailable(_ version: String) {
        post(title: "Eye Relax \(version) đã có 🎉",
             body: "Mở Eye Relax → Chung → Cập nhật để tải và cài bản mới.")
    }

    private static func post(title: String, body: String) {
        guard isBundled else {
            NSSound.beep()
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
