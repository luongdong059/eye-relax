import SwiftUI
import EyeRelaxCore

/// Màn chúc mừng cuối phiên: pháo bông nổ + lời chúc + nhắc uống nước và
/// bổ sung vitamin A. Mọi hạt pháo bông là hàm thuần của thời gian
/// (PathGenerator.hash01) nên render idempotent, không cần state.
struct CelebrationView: View {
    /// Thời gian đã chạy của màn chúc mừng (giây).
    let elapsed: TimeInterval
    /// Seed theo phiên — mỗi phiên một dàn pháo bông và lời chúc riêng.
    let seed: UInt64

    private static let congratulations = [
        "Tuyệt vời! Bạn đã hoàn thành phiên tập 🎉",
        "Xuất sắc! Đôi mắt cảm ơn bạn 💖",
        "Hoàn thành! Mắt bạn vừa được thư giãn 👏",
        "Giỏi lắm! Giữ thói quen này mỗi ngày nhé 🌟",
    ]

    var body: some View {
        ZStack {
            FireworksCanvas(elapsed: elapsed, seed: seed)
            card
        }
    }

    private var card: some View {
        VStack(spacing: 14) {
            Text("🎆")
                .font(.system(size: 52))
            Text(Self.congratulations[Int(seed % UInt64(Self.congratulations.count))])
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Divider().frame(width: 220)

            VStack(alignment: .leading, spacing: 8) {
                Label("Uống một cốc nước cho cơ thể đủ ẩm", systemImage: "drop.fill")
                    .foregroundStyle(.cyan)
                Label("Bổ sung vitamin A: cà rốt, bí đỏ, cá, trứng…", systemImage: "carrot.fill")
                    .foregroundStyle(.orange)
            }
            .font(.title3)

            Text("Design by Dong ✦")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 30)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 24)
        // Phóng nhẹ vào trong 0.35s đầu cho mượt.
        .scaleEffect(0.85 + 0.15 * min(1, elapsed / 0.35))
        .opacity(min(1, elapsed / 0.25))
    }
}

/// Pháo bông: các đợt nổ so le, mỗi đợt ~40 hạt bay toả tròn, rơi nhẹ theo
/// trọng lực và mờ dần.
private struct FireworksCanvas: View {
    let elapsed: TimeInterval
    let seed: UInt64

    private static let burstCount = 9
    private static let particlesPerBurst = 40
    private static let burstLife = 1.7

    var body: some View {
        Canvas { context, size in
            for burst in 0..<Self.burstCount {
                let b = UInt64(burst)
                // Đợt nổ so le nhau ~0.55s, lặp vô hạn nếu celebration kéo dài.
                let start = Double(burst) * 0.55
                let t = elapsed - start
                guard t > 0, t < Self.burstLife else { continue }
                let progress = t / Self.burstLife

                let cx = (0.12 + 0.76 * hash(b * 31 + 1)) * size.width
                let cy = (0.10 + 0.45 * hash(b * 31 + 2)) * size.height
                let hue = hash(b * 31 + 3)
                let maxRadius = (0.10 + 0.08 * hash(b * 31 + 4)) * min(size.width, size.height)

                // Bay nhanh lúc đầu rồi chậm dần (ease-out bậc ba).
                let spread = 1 - pow(1 - progress, 3)
                let fade = pow(1 - progress, 1.5)

                for i in 0..<Self.particlesPerBurst {
                    let p = UInt64(i)
                    let angle = 2 * .pi * Double(i) / Double(Self.particlesPerBurst)
                        + 0.25 * hash(b * 997 + p * 7 + 5)
                    let speed = 0.55 + 0.45 * hash(b * 997 + p * 7 + 6)
                    let radius = maxRadius * speed * spread
                    let gravity = 60.0 * progress * progress

                    let x = cx + cos(angle) * radius
                    let y = cy + sin(angle) * radius + gravity
                    let diameter = (2.5 + 3.5 * hash(b * 997 + p * 7 + 8)) * (0.4 + 0.6 * fade)

                    // Mỗi đợt một tông màu chủ đạo, hạt lệch nhẹ quanh tông đó.
                    let particleHue = (hue + 0.12 * hash(b * 997 + p * 7 + 9))
                        .truncatingRemainder(dividingBy: 1)
                    let color = Color(hue: particleHue, saturation: 0.85, brightness: 1)

                    let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2,
                                      width: diameter, height: diameter)
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(fade)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func hash(_ n: UInt64) -> Double {
        PathGenerator.hash01(n, seed: seed)
    }
}
