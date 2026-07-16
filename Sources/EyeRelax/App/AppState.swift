import AppKit
import Combine
import EyeRelaxCore

/// Đầu não của app: nối settings ↔ scheduler ↔ runner ↔ overlay.
final class AppState: ObservableObject {

    static let shared = AppState()

    let settings = SettingsStore()
    let library = ExerciseLibrary(storageURL: ExerciseLibrary.defaultStorageURL())
    let runner = ExerciseRunner()
    let scheduler = ExerciseScheduler()
    @MainActor lazy var updater = UpdateChecker()

    private let overlay = OverlayController()
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        scheduler.onFire = { [weak self] in self?.handleScheduledFire() }

        // Phiên tập bắt đầu → hiện overlay; kết thúc → ẩn + hẹn phiên sau.
        runner.$session
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                if session != nil {
                    self.overlay.show(runner: self.runner, settings: self.settings)
                } else {
                    self.overlay.hide()
                    self.rescheduleFromNow()
                }
            }
            .store(in: &cancellables)

        // Đổi chu kỳ / bật tắt lịch trong lúc rảnh → hẹn lại từ bây giờ.
        settings.$intervalMinutes
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.runner.session == nil else { return }
                self.rescheduleFromNow()
            }
            .store(in: &cancellables)
        settings.$schedulingEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled { self.rescheduleFromNow() } else { self.scheduler.cancel() }
            }
            .store(in: &cancellables)

        settings.$hideDockIcon
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { hide in
                NSApp.setActivationPolicy(hide ? .accessory : .regular)
            }
            .store(in: &cancellables)

        // Máy thức dậy sau sleep → resync mốc hẹn đã trôi qua.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduler.handleWake()
        }

        rescheduleFromNow()
    }

    func applyActivationPolicy() {
        NSApp.setActivationPolicy(settings.hideDockIcon ? .accessory : .regular)
    }

    /// Kiểm tra bản mới trong nền, chờ vài giây cho app ổn định sau khi mở.
    func autoCheckUpdatesIfEnabled() {
        guard settings.autoCheckUpdates else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await updater.check(silent: true)
        }
    }

    // MARK: - Điều khiển phiên tập

    /// Chạy playlist của một nhóm (hoặc mọi nhóm đang bật nếu `group == nil`).
    func startSession(group: ExerciseGroup? = nil) {
        guard runner.session == nil else { return }
        scheduler.cancel()
        let playlist = library.playlist(for: group)
        guard !playlist.isEmpty else {
            rescheduleFromNow()
            return
        }
        runner.start(exercises: playlist)
    }

    /// Xem thử một bài từ Settings (chạy cả khi bài đang bị tắt).
    func preview(_ exercise: Exercise) {
        runner.stop()
        var ex = exercise
        ex.isEnabled = true
        scheduler.cancel()
        runner.start(exercises: [ex])
    }

    func stopSession() { runner.stop() }
    func skipExercise() { runner.skipCurrent() }

    func snooze(_ interval: TimeInterval? = nil) {
        scheduler.snooze(interval ?? settings.snoozeInterval)
    }

    // MARK: - Lịch

    private func rescheduleFromNow() {
        guard settings.schedulingEnabled else {
            scheduler.cancel()
            return
        }
        scheduler.schedule(after: settings.interval)
    }

    private func handleScheduledFire() {
        guard runner.session == nil else { return }
        switch settings.triggerMode {
        case .autoRun:
            startSession()
        case .notifyOnly:
            Notifier.postSessionReady()
            // Người dùng tự bắt đầu từ menu bar; nhắc lại sau một chu kỳ nữa.
            rescheduleFromNow()
        }
    }
}
