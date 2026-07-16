import Foundation

// MARK: - Quỹ đạo

public enum PathType: String, Codable, CaseIterable, Sendable {
    // Smooth pursuit — nhìn đuổi mượt
    case horizontal, vertical, diagonal, circle, figureEight, sineWave, spiral
    // Saccades — nhảy điểm
    case saccadeHorizontal, saccadeCorners, saccadeRandom
    // Focus / điều tiết
    case nearFar, blink
    // Nghỉ ngơi
    case restReminder

    /// Thời gian một vòng (giây) ở tốc độ 1x.
    public var baseCycleDuration: TimeInterval {
        switch self {
        case .horizontal, .vertical, .diagonal: return 4
        case .circle: return 5
        case .figureEight: return 6
        case .sineWave: return 5
        case .spiral: return 8
        case .saccadeHorizontal: return 2.4   // 1.2s mỗi điểm × 2 điểm
        case .saccadeCorners: return 4.8      // 1.2s × 4 góc
        case .saccadeRandom: return 7.2       // 1.2s × 6 điểm
        case .nearFar: return 6
        case .blink: return 2
        case .restReminder: return 20
        }
    }

    /// Quỹ đạo liên tục (có trail); saccade/blink/rest thì không.
    public var supportsTrail: Bool {
        switch self {
        case .horizontal, .vertical, .diagonal, .circle, .figureEight, .sineWave, .spiral:
            return true
        default:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .horizontal: return "Ngang"
        case .vertical: return "Dọc"
        case .diagonal: return "Chéo"
        case .circle: return "Vòng tròn"
        case .figureEight: return "Số 8 nằm ngang"
        case .sineWave: return "Sóng sin"
        case .spiral: return "Xoắn ốc"
        case .saccadeHorizontal: return "Nhảy hai điểm"
        case .saccadeCorners: return "Nhảy bốn góc"
        case .saccadeRandom: return "Nhảy ngẫu nhiên"
        case .nearFar: return "Gần – xa"
        case .blink: return "Chớp mắt"
        case .restReminder: return "Nhìn xa nghỉ mắt"
        }
    }
}

// MARK: - Bài tập

public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var pathType: PathType
    /// 0.5x – 3x
    public var speed: Double
    public var laps: Int
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, pathType: PathType,
                speed: Double = 1.0, laps: Int = 3, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.pathType = pathType
        self.speed = speed
        self.laps = laps
        self.isEnabled = isEnabled
    }

    /// Tổng thời gian chạy của bài (giây).
    public var duration: TimeInterval {
        if pathType == .restReminder { return pathType.baseCycleDuration }
        return Double(laps) * pathType.baseCycleDuration / max(speed, 0.1)
    }

    /// Seed ổn định cho quỹ đạo ngẫu nhiên (suy từ UUID).
    public var randomSeed: UInt64 {
        let b = id.uuid
        return UInt64(b.0) | UInt64(b.1) << 8 | UInt64(b.2) << 16 | UInt64(b.3) << 24
            | UInt64(b.4) << 32 | UInt64(b.5) << 40 | UInt64(b.6) << 48 | UInt64(b.7) << 56
    }
}

public struct ExerciseGroup: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var summary: String
    public var exercises: [Exercise]
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, summary: String,
                exercises: [Exercise], isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.summary = summary
        self.exercises = exercises
        self.isEnabled = isEnabled
    }

    public var enabledExercises: [Exercise] { exercises.filter(\.isEnabled) }
}

// MARK: - Cấu hình icon & trail

public struct IconConfig: Codable, Equatable {
    public enum Source: Codable, Equatable {
        case builtinCartoon
        case sfSymbol(String)
        case emoji(String)
        case customImage(filename: String)
    }

    public var source: Source
    /// Kích thước icon (pt), 24–96.
    public var size: Double
    /// Màu cho SF Symbol (hex, ví dụ "#FFD60A").
    public var colorHex: String
    public var glow: Bool
    public var opacity: Double

    public init(source: Source = .builtinCartoon, size: Double = 56,
                colorHex: String = "#FFD60A", glow: Bool = true, opacity: Double = 1.0) {
        self.source = source
        self.size = size
        self.colorHex = colorHex
        self.glow = glow
        self.opacity = opacity
    }
}

public struct TrailConfig: Codable, Equatable {
    public enum Style: String, Codable, CaseIterable {
        case dots, iconCopies, line

        public var displayName: String {
            switch self {
            case .dots: return "Chấm tròn"
            case .iconCopies: return "Bản sao icon"
            case .line: return "Nét liền"
            }
        }
    }

    public var enabled: Bool
    /// Số điểm trail, 4–30.
    public var length: Int
    public var style: Style

    public init(enabled: Bool = true, length: Int = 14, style: Style = .dots) {
        self.enabled = enabled
        self.length = length
        self.style = style
    }
}

// MARK: - Chế độ kích hoạt phiên

public enum SessionTriggerMode: String, Codable, CaseIterable {
    /// Tới giờ thì overlay tự chạy.
    case autoRun
    /// Chỉ thông báo, người dùng tự bắt đầu.
    case notifyOnly

    public var displayName: String {
        switch self {
        case .autoRun: return "Tự chạy bài tập"
        case .notifyOnly: return "Chỉ thông báo"
        }
    }
}
