import Foundation
import Combine

/// Hẹn giờ lặp lại phiên tập. Dùng `Timer` bắn tại `nextFireDate` tuyệt đối
/// nên sống sót qua sleep/wake (gọi `handleWake()` khi máy thức dậy để resync).
public final class ExerciseScheduler: ObservableObject {

    @Published public private(set) var nextFireDate: Date?

    /// Gọi khi tới giờ tập.
    public var onFire: (() -> Void)?

    private var timer: Timer?

    public init() {}

    public func schedule(after interval: TimeInterval, from date: Date = Date()) {
        schedule(at: date.addingTimeInterval(interval))
    }

    public func schedule(at date: Date) {
        cancel()
        nextFireDate = date
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.nextFireDate = nil
            self.timer = nil
            self.onFire?()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Hoãn: đẩy lùi mốc hẹn hiện tại (hoặc tạo mốc mới nếu chưa có).
    public func snooze(_ interval: TimeInterval, from date: Date = Date()) {
        let base = nextFireDate ?? date
        schedule(at: max(base, date).addingTimeInterval(interval))
    }

    public func cancel() {
        timer?.invalidate()
        timer = nil
        nextFireDate = nil
    }

    /// Sau khi máy sleep, Timer có thể đã trôi qua mốc hẹn — bắn lại sau 30s
    /// để người dùng kịp ổn định thay vì tập ngay khi vừa mở máy.
    public func handleWake(now: Date = Date()) {
        guard let fire = nextFireDate, fire <= now else { return }
        schedule(at: now.addingTimeInterval(30))
    }
}
