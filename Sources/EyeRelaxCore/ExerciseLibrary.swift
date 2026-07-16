import Foundation
import Combine

/// Thư viện bài tập: nạp bộ built-in, cho phép người dùng chỉnh (tốc độ, số
/// vòng, bật/tắt) và lưu xuống Application Support dạng JSON.
public final class ExerciseLibrary: ObservableObject {

    @Published public var groups: [ExerciseGroup] {
        didSet { save() }
    }

    private let storageURL: URL?

    /// - Parameter storageURL: file JSON lưu chỉnh sửa của người dùng;
    ///   `nil` = chỉ chạy trong bộ nhớ (dùng cho test/preview).
    public init(storageURL: URL?) {
        self.storageURL = storageURL
        if let url = storageURL,
           let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([ExerciseGroup].self, from: data),
           !saved.isEmpty {
            self.groups = saved
        } else {
            self.groups = Self.builtinGroups()
        }
    }

    /// URL mặc định: ~/Library/Application Support/EyeRelax/exercises.json
    public static func defaultStorageURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("EyeRelax", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("exercises.json")
    }

    public func resetToBuiltin() {
        groups = Self.builtinGroups()
    }

    /// Playlist của một nhóm (hoặc mọi nhóm đang bật nếu `group == nil`).
    public func playlist(for group: ExerciseGroup? = nil) -> [Exercise] {
        if let group { return group.enabledExercises }
        return groups.filter(\.isEnabled).flatMap(\.enabledExercises)
    }

    public func updateExercise(_ exercise: Exercise) {
        for gi in groups.indices {
            if let ei = groups[gi].exercises.firstIndex(where: { $0.id == exercise.id }) {
                groups[gi].exercises[ei] = exercise
                return
            }
        }
    }

    private func save() {
        guard let url = storageURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(groups) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Bộ bài tập built-in

    public static func builtinGroups() -> [ExerciseGroup] {
        [
            ExerciseGroup(
                name: "Nhìn đuổi mượt",
                summary: "Mắt bám theo icon di chuyển liên tục (smooth pursuit).",
                exercises: [
                    Exercise(name: "Ngang", pathType: .horizontal, laps: 3),
                    Exercise(name: "Dọc", pathType: .vertical, laps: 3),
                    Exercise(name: "Chéo", pathType: .diagonal, laps: 4),
                    Exercise(name: "Vòng tròn", pathType: .circle, laps: 3),
                    Exercise(name: "Số 8 nằm ngang", pathType: .figureEight, laps: 3),
                    Exercise(name: "Sóng sin", pathType: .sineWave, laps: 2),
                    Exercise(name: "Xoắn ốc", pathType: .spiral, laps: 2),
                ]
            ),
            ExerciseGroup(
                name: "Nhảy điểm (Saccades)",
                summary: "Icon dừng rồi nhảy vị trí — luyện chuyển hướng nhìn nhanh.",
                exercises: [
                    Exercise(name: "Hai điểm ngang", pathType: .saccadeHorizontal, laps: 4),
                    Exercise(name: "Bốn góc màn hình", pathType: .saccadeCorners, laps: 3),
                    Exercise(name: "Điểm ngẫu nhiên", pathType: .saccadeRandom, laps: 2),
                ]
            ),
            ExerciseGroup(
                name: "Điều tiết",
                summary: "Icon phóng to/thu nhỏ — luyện điều tiết tiêu cự.",
                exercises: [
                    Exercise(name: "Gần – xa", pathType: .nearFar, laps: 2),
                    Exercise(name: "Chớp mắt", pathType: .blink, laps: 5),
                ]
            ),
            ExerciseGroup(
                name: "Nghỉ ngơi 20-20-20",
                summary: "Nhắc rời mắt khỏi màn hình, nhìn xa ≥ 6m trong 20 giây.",
                exercises: [
                    Exercise(name: "Nhìn xa nghỉ mắt", pathType: .restReminder, laps: 1),
                ]
            ),
        ]
    }
}
