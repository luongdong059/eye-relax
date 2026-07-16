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
            // Khoá 60fps: trên màn ProMotion 120Hz giảm nửa tải CPU mà mắt
            // thường không phân biệt được với chuyển động chậm cỡ này.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
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

                    case .celebration(let remaining):
                        CelebrationView(
                            elapsed: ExerciseRunner.celebrationDuration - remaining,
                            seed: celebrationSeed)

                    case nil:
                        EmptyView()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .allowsHitTesting(false)
    }

    /// Seed pháo bông theo phiên: mỗi phiên một dàn pháo và lời chúc riêng.
    private var celebrationSeed: UInt64 {
        UInt64(bitPattern: Int64((runner.session?.startDate.timeIntervalSince1970 ?? 0) * 1000))
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
        // Dots & line vẽ trong MỘT Canvas: một draw pass mỗi frame thay vì
        // hàng chục view reposition — giảm hẳn CPU khi animation chạy.
        case .dots:
            Canvas { context, _ in
                for i in trail.indices {
                    let point = OverlayContentView.mapToScreen(trail[i], in: size)
                    let d = dotSize(i)
                    let rect = CGRect(x: point.x - d / 2, y: point.y - d / 2,
                                      width: d, height: d)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(dotColor.opacity(fade(i) * 0.8)))
                }
            }
            .allowsHitTesting(false)
        case .line:
            Canvas { context, _ in
                guard let first = trail.first else { return }
                var path = Path()
                path.move(to: OverlayContentView.mapToScreen(first, in: size))
                for sample in trail.dropFirst() {
                    path.addLine(to: OverlayContentView.mapToScreen(sample, in: size))
                }
                context.addFilter(.shadow(color: .black.opacity(0.3), radius: 2))
                context.stroke(path, with: .color(dotColor.opacity(0.55)),
                               style: StrokeStyle(lineWidth: max(3, icon.size * 0.1),
                                                  lineCap: .round, lineJoin: .round))
            }
            .allowsHitTesting(false)
        // Bản sao icon cần render view đầy đủ (ảnh/emoji/symbol) — chấp nhận
        // nặng hơn hai kiểu trên.
        case .iconCopies:
            ForEach(trail.indices, id: \.self) { i in
                IconView(config: icon,
                         renderSize: icon.size * trail[i].scale * (0.35 + 0.5 * fade(i)),
                         withGlow: false)
                    .opacity(fade(i) * 0.7)
                    .position(OverlayContentView.mapToScreen(trail[i], in: size))
            }
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
