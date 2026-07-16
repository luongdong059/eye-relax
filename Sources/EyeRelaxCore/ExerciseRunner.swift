import Foundation
import Combine

/// Điều khiển một phiên tập: playlist bài tập chạy tuần tự, mỗi bài có đoạn
/// "chuẩn bị" (intermission) hiện tên bài trước khi icon chạy.
///
/// Rendering là hàm thuần theo thời gian (`frame(at:)`) — view gọi mỗi frame,
/// runner không giữ state animation; chỉ một timer thưa để chuyển bài/kết thúc.
public final class ExerciseRunner: ObservableObject {

    public struct Item {
        public let exercise: Exercise
        /// Thời điểm bắt đầu (giây, tính từ đầu phiên) — gồm cả intermission.
        public let start: TimeInterval
        public let intermission: TimeInterval
        public let duration: TimeInterval
        public var end: TimeInterval { start + intermission + duration }
    }

    public struct Session {
        public let startDate: Date
        public let items: [Item]
        public var totalDuration: TimeInterval { items.last?.end ?? 0 }
    }

    public enum Frame {
        /// Đang đếm ngược chuẩn bị vào bài.
        case intermission(exercise: Exercise, remaining: TimeInterval)
        /// Icon đang chạy theo quỹ đạo.
        case active(exercise: Exercise, sample: PathSample, trail: [PathSample])
        /// Bài nghỉ 20-20-20: hiện thông điệp + đếm ngược.
        case rest(exercise: Exercise, remaining: TimeInterval)
    }

    @Published public private(set) var session: Session?

    /// Gọi khi phiên kết thúc tự nhiên hoặc bị dừng.
    public var onFinish: (() -> Void)?

    public static let intermissionDuration: TimeInterval = 2

    /// Bù thời gian khi người dùng bấm "bỏ qua bài".
    private var skipOffset: TimeInterval = 0
    private var housekeeper: Timer?

    public init() {}

    // MARK: - Điều khiển

    public func start(exercises: [Exercise], at date: Date = Date()) {
        stopTimer()
        var items: [Item] = []
        var cursor: TimeInterval = 0
        for ex in exercises where ex.isEnabled {
            let item = Item(exercise: ex, start: cursor,
                            intermission: Self.intermissionDuration,
                            duration: ex.duration)
            items.append(item)
            cursor = item.end
        }
        guard !items.isEmpty else { return }
        skipOffset = 0
        session = Session(startDate: date, items: items)

        // Timer thưa chỉ để phát hiện hết phiên; render không phụ thuộc nó.
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let session = self.session else { return }
            if self.elapsed(at: Date()) >= session.totalDuration {
                self.finish()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        housekeeper = timer
    }

    public func stop() {
        guard session != nil else { return }
        finish()
    }

    /// Nhảy tới bài kế tiếp (hoặc kết thúc nếu là bài cuối).
    public func skipCurrent(at date: Date = Date()) {
        guard let item = currentItem(at: date) else { return }
        skipOffset += item.end - elapsed(at: date)
    }

    private func finish() {
        stopTimer()
        session = nil
        onFinish?()
    }

    private func stopTimer() {
        housekeeper?.invalidate()
        housekeeper = nil
    }

    // MARK: - Truy vấn theo thời gian

    public func elapsed(at date: Date) -> TimeInterval {
        guard let session else { return 0 }
        return date.timeIntervalSince(session.startDate) + skipOffset
    }

    public func currentItem(at date: Date) -> Item? {
        guard let session else { return nil }
        let t = elapsed(at: date)
        return session.items.first { t >= $0.start && t < $0.end }
    }

    /// Trạng thái render tại một thời điểm. `trailSpacing` là khoảng cách thời
    /// gian giữa các điểm trail (giây).
    public func frame(at date: Date, trailCount: Int = 0,
                      trailSpacing: TimeInterval = 0.045) -> Frame? {
        guard let item = currentItem(at: date) else { return nil }
        let ex = item.exercise
        let t = elapsed(at: date) - item.start

        if t < item.intermission {
            return .intermission(exercise: ex, remaining: item.intermission - t)
        }

        let active = t - item.intermission
        if ex.pathType == .restReminder {
            return .rest(exercise: ex, remaining: item.duration - active)
        }

        var trail: [PathSample] = []
        if ex.pathType.supportsTrail && trailCount > 0 {
            for i in 1...trailCount {
                let tt = active - Double(i) * trailSpacing
                guard tt >= 0 else { break }
                trail.append(sample(ex, activeTime: tt))
            }
        }
        return .active(exercise: ex, sample: sample(ex, activeTime: active), trail: trail)
    }

    /// Vị trí của một bài tại thời điểm `activeTime` (giây kể từ khi icon bắt đầu chạy).
    func sample(_ exercise: Exercise, activeTime: TimeInterval) -> PathSample {
        let cycles = activeTime * exercise.speed / exercise.pathType.baseCycleDuration
        let lap = Int(cycles)
        let phase = cycles - Double(lap)
        return PathGenerator.sample(exercise.pathType, phase: phase,
                                    lapIndex: lap, seed: exercise.randomSeed)
    }
}
