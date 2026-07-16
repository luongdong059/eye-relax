import AppKit
import UserNotifications

/// Gửi thông báo "tới giờ tập mắt" với nút hành động Bắt đầu / Hoãn.
/// `UNUserNotificationCenter` yêu cầu app chạy trong bundle (.app) — khi chạy
/// `swift run` (không có bundle id) thì fallback sang beep để dev vẫn thấy tín hiệu.
enum Notifier {

    static let sessionReadyCategory = "SESSION_READY"
    static let startAction = "START_SESSION"
    static let snoozeAction = "SNOOZE_SESSION"

    private static var isBundled: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestPermissionIfNeeded() {
        guard isBundled else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Nút hành động ngay trên thông báo — không cần mở app.
        let start = UNNotificationAction(identifier: startAction,
                                         title: "Bắt đầu ngay",
                                         options: [])
        let snooze = UNNotificationAction(identifier: snoozeAction,
                                          title: "Hoãn lại",
                                          options: [])
        let category = UNNotificationCategory(identifier: sessionReadyCategory,
                                              actions: [start, snooze],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
    }

    static func postSessionReady() {
        post(title: "Đến giờ tập mắt 👀",
             body: "Bấm Bắt đầu ngay, hoặc Hoãn nếu bạn đang bận.",
             category: sessionReadyCategory)
    }

    static func postUpdateAvailable(_ version: String) {
        post(title: "Eye Relax \(version) đã có 🎉",
             body: "Mở Eye Relax → Chung → Cập nhật để tải và cài bản mới.")
    }

    private static func post(title: String, body: String, category: String? = nil) {
        guard isBundled else {
            NSSound.beep()
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category { content.categoryIdentifier = category }
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
