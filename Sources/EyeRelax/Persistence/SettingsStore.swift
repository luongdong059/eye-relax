import Foundation
import Combine
import EyeRelaxCore

/// Cấu hình người dùng, lưu UserDefaults, áp dụng ngay khi thay đổi.
final class SettingsStore: ObservableObject {

    @Published var intervalMinutes: Int {
        didSet { defaults.set(intervalMinutes, forKey: Keys.interval) }
    }
    @Published var triggerMode: SessionTriggerMode {
        didSet { defaults.set(triggerMode.rawValue, forKey: Keys.triggerMode) }
    }
    @Published var snoozeMinutes: Int {
        didSet { defaults.set(snoozeMinutes, forKey: Keys.snooze) }
    }
    @Published var schedulingEnabled: Bool {
        didSet { defaults.set(schedulingEnabled, forKey: Keys.schedulingEnabled) }
    }
    @Published var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: Keys.hideDock) }
    }
    @Published var autoCheckUpdates: Bool {
        didSet { defaults.set(autoCheckUpdates, forKey: Keys.autoCheckUpdates) }
    }
    @Published var icon: IconConfig {
        didSet { saveCodable(icon, key: Keys.icon) }
    }
    @Published var trail: TrailConfig {
        didSet { saveCodable(trail, key: Keys.trail) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        intervalMinutes = defaults.object(forKey: Keys.interval) as? Int ?? 20
        triggerMode = (defaults.string(forKey: Keys.triggerMode)
            .flatMap(SessionTriggerMode.init(rawValue:))) ?? .autoRun
        snoozeMinutes = defaults.object(forKey: Keys.snooze) as? Int ?? 5
        schedulingEnabled = defaults.object(forKey: Keys.schedulingEnabled) as? Bool ?? true
        hideDockIcon = defaults.bool(forKey: Keys.hideDock)
        autoCheckUpdates = defaults.object(forKey: Keys.autoCheckUpdates) as? Bool ?? true
        icon = Self.loadCodable(IconConfig.self, key: Keys.icon, from: defaults) ?? IconConfig()
        trail = Self.loadCodable(TrailConfig.self, key: Keys.trail, from: defaults) ?? TrailConfig()
    }

    var interval: TimeInterval { TimeInterval(intervalMinutes * 60) }
    var snoozeInterval: TimeInterval { TimeInterval(snoozeMinutes * 60) }

    /// Thư mục chứa icon người dùng import.
    static func customIconsDirectory() -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("EyeRelax/icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    // MARK: - Codable helpers

    private func saveCodable<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, key: String,
                                                  from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private enum Keys {
        static let interval = "intervalMinutes"
        static let triggerMode = "triggerMode"
        static let snooze = "snoozeMinutes"
        static let schedulingEnabled = "schedulingEnabled"
        static let hideDock = "hideDockIcon"
        static let autoCheckUpdates = "autoCheckUpdates"
        static let icon = "iconConfig"
        static let trail = "trailConfig"
    }
}
