import SwiftUI
import EyeRelaxCore

/// Nội dung cửa sổ overlay: icon chạy theo quỹ đạo + trail, hoặc màn hình
/// chuẩn bị / nghỉ ngơi. Render mỗi frame qua `TimelineView(.animation)`;
/// mọi vị trí đều là hàm thuần của thời gian (không giữ state animation).
struct OverlayContentView: View {
    @ObservedObject var runner: ExerciseRunner
    @ObservedObject var settings: SettingsStore

    /// Lề an toàn quanh mép màn hình (tỷ lệ).
    private static let margin = 0.06

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let trailCount = settings.trail.enabled ? settings.trail.length : 0
                let frame = runner.frame(at: context.date, trailCount: trailCount)
                ZStack {
                    switch frame {
                    case .intermission(let exercise, let remaining):
                        IntermissionCard(exercise: exercise, remaining: remaining)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    case .active(_, let sample, let trail):
                        TrailView(trail: trail, config: settings.trail,
                                  icon: settings.icon, size: geo.size)
                        IconView(config: settings.icon,
                                 renderSize: settings.icon.size * sample.scale)
                            .opacity(sample.opacity)
                            .position(Self.mapToScreen(sample, in: geo.size))

                    case .rest(_, let remaining):
                        RestCard(remaining: remaining)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    case nil:
                        EmptyView()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .allowsHitTesting(false)
    }

    /// Toạ độ chuẩn hoá [0,1]² → toạ độ view, chừa lề an toàn.
    static func mapToScreen(_ sample: PathSample, in size: CGSize) -> CGPoint {
        let m = margin
        return CGPoint(x: (m + sample.x * (1 - 2 * m)) * size.width,
                       y: (m + sample.y * (1 - 2 * m)) * size.height)
    }
}

// MARK: - Trail

struct TrailView: View {
    let trail: [PathSample]
    let config: TrailConfig
    let icon: IconConfig
    let size: CGSize

    var body: some View {
        switch config.style {
        case .dots:
            ForEach(trail.indices, id: \.self) { i in
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize(i), height: dotSize(i))
                    .opacity(fade(i) * 0.8)
                    .position(OverlayContentView.mapToScreen(trail[i], in: size))
            }
        case .iconCopies:
            ForEach(trail.indices, id: \.self) { i in
                IconView(config: icon,
                         renderSize: icon.size * trail[i].scale * (0.35 + 0.5 * fade(i)),
                         withGlow: false)
                    .opacity(fade(i) * 0.7)
                    .position(OverlayContentView.mapToScreen(trail[i], in: size))
            }
        case .line:
            Path { path in
                guard let first = trail.first else { return }
                path.move(to: OverlayContentView.mapToScreen(first, in: size))
                for sample in trail.dropFirst() {
                    path.addLine(to: OverlayContentView.mapToScreen(sample, in: size))
                }
            }
            .stroke(dotColor.opacity(0.55),
                    style: StrokeStyle(lineWidth: max(3, icon.size * 0.1),
                                       lineCap: .round, lineJoin: .round))
            .shadow(color: .black.opacity(0.3), radius: 2)
        }
    }

    /// Điểm càng cũ (index lớn) càng mờ và nhỏ.
    private func fade(_ index: Int) -> Double {
        1 - Double(index + 1) / Double(trail.count + 1)
    }

    private func dotSize(_ index: Int) -> Double {
        max(4, icon.size * 0.22 * (0.4 + 0.6 * fade(index)))
    }

    private var dotColor: Color {
        if case .sfSymbol = icon.source { return Color(hex: icon.colorHex) }
        return .white
    }
}

// MARK: - Thẻ thông tin giữa màn hình

struct IntermissionCard: View {
    let exercise: Exercise
    let remaining: TimeInterval

    var body: some View {
        VStack(spacing: 10) {
            Text(exercise.name)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Chuẩn bị… \(Int(remaining.rounded(.up)))")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
    }
}

struct RestCard: View {
    let remaining: TimeInterval

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "binoculars.fill")
                .font(.system(size: 44))
                .foregroundStyle(.teal)
            Text("Rời mắt khỏi màn hình")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Nhìn một điểm ở xa (≥ 6 mét)")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("\(Int(remaining.rounded(.up)))s")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.teal)
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 20)
    }
}
