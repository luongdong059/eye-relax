import AppKit
import SwiftUI
import EyeRelaxCore

/// NSPanel trong suốt, không nhận focus — nền tảng của overlay.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(frame: NSRect, clickThrough: Bool) {
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver                    // đè lên mọi cửa sổ thường
        ignoresMouseEvents = clickThrough
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces,    // hiện trên mọi Space
                              .fullScreenAuxiliary, // hiện cả trên app fullscreen
                              .stationary]
    }
}

/// Quản lý vòng đời hai panel: overlay toàn màn hình (click-through) và badge
/// điều khiển nhỏ dưới đáy màn hình (nhận chuột để bấm Dừng/Bỏ qua).
final class OverlayController {

    private var iconPanel: OverlayPanel?
    private var controlPanel: OverlayPanel?
    private var runner: ExerciseRunner?
    private var settings: SettingsStore?

    init() {
        // Màn hình thay đổi (tháo/gắn, đổi độ phân giải) → dựng lại panel.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.iconPanel != nil,
                  let runner = self.runner, let settings = self.settings else { return }
            self.show(runner: runner, settings: settings)
        }
    }

    var isVisible: Bool { iconPanel != nil }

    func show(runner: ExerciseRunner, settings: SettingsStore) {
        hide()
        self.runner = runner
        self.settings = settings
        let screen = Self.targetScreen()

        let icon = OverlayPanel(frame: screen.frame, clickThrough: true)
        icon.contentView = NSHostingView(
            rootView: OverlayContentView(runner: runner, settings: settings))
        icon.orderFrontRegardless()
        iconPanel = icon

        // Badge điều khiển: giữa đáy màn hình, cần nhận chuột.
        let badgeSize = NSSize(width: 300, height: 52)
        let badgeFrame = NSRect(x: screen.frame.midX - badgeSize.width / 2,
                                y: screen.frame.minY + 40,
                                width: badgeSize.width, height: badgeSize.height)
        let control = OverlayPanel(frame: badgeFrame, clickThrough: false)
        control.contentView = NSHostingView(
            rootView: ControlBadgeView(runner: runner))
        control.orderFrontRegardless()
        controlPanel = control
    }

    func hide() {
        iconPanel?.close()
        controlPanel?.close()
        iconPanel = nil
        controlPanel = nil
        runner = nil
        settings = nil
    }

    /// Màn hình đang chứa con trỏ chuột (mặc định: màn hình chính).
    static func targetScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
