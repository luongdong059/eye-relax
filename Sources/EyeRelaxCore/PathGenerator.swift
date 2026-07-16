import Foundation

/// Một mẫu vị trí trên quỹ đạo, toạ độ chuẩn hoá [0,1]² (gốc trên-trái).
public struct PathSample: Equatable, Sendable {
    public var x: Double
    public var y: Double
    /// Hệ số phóng to icon (bài gần–xa).
    public var scale: Double
    /// Độ mờ icon (bài chớp mắt).
    public var opacity: Double

    public init(x: Double, y: Double, scale: Double = 1, opacity: Double = 1) {
        self.x = x
        self.y = y
        self.scale = scale
        self.opacity = opacity
    }
}

/// Sinh vị trí theo quỹ đạo: hàm thuần `(loại, phase, vòng, seed) → PathSample`.
/// `phase ∈ [0,1)` là tiến độ trong MỘT vòng; hàm thuần giúp trail tính ngược
/// thời gian mà không cần buffer.
public enum PathGenerator {

    public static func sample(_ type: PathType, phase rawPhase: Double,
                              lapIndex: Int = 0, seed: UInt64 = 0) -> PathSample {
        let phase = normalized(rawPhase)
        switch type {
        case .horizontal:
            return PathSample(x: pingPong(phase), y: 0.5)

        case .vertical:
            return PathSample(x: 0.5, y: pingPong(phase))

        case .diagonal:
            // Vòng chẵn: chéo ↘, vòng lẻ: chéo ↙ — luyện cả hai đường chéo.
            let t = pingPong(phase)
            return lapIndex.isMultiple(of: 2)
                ? PathSample(x: t, y: t)
                : PathSample(x: t, y: 1 - t)

        case .circle:
            let a = 2 * .pi * phase
            return PathSample(x: 0.5 + 0.45 * cos(a), y: 0.5 + 0.45 * sin(a))

        case .figureEight:
            // Lissajous ∞: ngang full biên, dọc gọn lại.
            let a = 2 * .pi * phase
            return PathSample(x: 0.5 + 0.45 * sin(a), y: 0.5 + 0.22 * sin(2 * a))

        case .sineWave:
            let x = pingPong(phase)
            return PathSample(x: x, y: 0.5 + 0.25 * sin(4 * .pi * x))

        case .spiral:
            // Bán kính ping-pong (ra rồi vào), góc quay liên tục 3 vòng.
            let r = 0.05 + 0.4 * pingPong(phase)
            let a = 2 * .pi * 3 * phase
            return PathSample(x: 0.5 + r * cos(a), y: 0.5 + r * sin(a))

        case .saccadeHorizontal:
            let points = [(0.08, 0.5), (0.92, 0.5)]
            let p = points[step(phase, count: points.count)]
            return PathSample(x: p.0, y: p.1)

        case .saccadeCorners:
            let points = [(0.08, 0.1), (0.92, 0.1), (0.92, 0.9), (0.08, 0.9)]
            let p = points[step(phase, count: points.count)]
            return PathSample(x: p.0, y: p.1)

        case .saccadeRandom:
            let stepsPerLap = 6
            let globalStep = lapIndex * stepsPerLap + step(phase, count: stepsPerLap)
            return randomPoint(step: globalStep, seed: seed)

        case .nearFar:
            // Đứng giữa màn hình, scale 0.5 → 2.0 → 0.5 (mô phỏng gần–xa).
            let s = 1.25 - 0.75 * cos(2 * .pi * phase)
            return PathSample(x: 0.5, y: 0.5, scale: s)

        case .blink:
            // Mờ dần rồi hiện lại — nhắc nhịp chớp mắt.
            let o = 0.1 + 0.9 * (0.5 + 0.5 * cos(2 * .pi * phase))
            return PathSample(x: 0.5, y: 0.5, opacity: o)

        case .restReminder:
            return PathSample(x: 0.5, y: 0.5)
        }
    }

    // MARK: - Helpers

    /// Đưa phase về [0,1) (chấp nhận cả giá trị âm khi tính trail lùi thời gian).
    static func normalized(_ p: Double) -> Double {
        let f = p.truncatingRemainder(dividingBy: 1)
        return f < 0 ? f + 1 : f
    }

    /// Sóng tam giác 0→1→0 trên một vòng: chuyển động khứ hồi mượt.
    static func pingPong(_ phase: Double) -> Double {
        1 - abs(1 - 2 * phase)
    }

    /// Chỉ số điểm dừng hiện tại cho quỹ đạo saccade.
    static func step(_ phase: Double, count: Int) -> Int {
        min(Int(phase * Double(count)), count - 1)
    }

    /// Điểm giả-ngẫu-nhiên tất định theo (seed, step); đảm bảo cách điểm trước
    /// tối thiểu 0.3 để mắt phải thực sự "nhảy". Chuỗi điểm được dựng tuần tự
    /// từ bước 0 để mỗi lần điều chỉnh đều so với điểm ĐÃ điều chỉnh trước đó.
    static func randomPoint(step: Int, seed: UInt64) -> PathSample {
        func rawPoint(_ n: Int) -> PathSample {
            PathSample(x: 0.1 + 0.8 * hash01(UInt64(n) &* 2 &+ 1, seed: seed),
                       y: 0.12 + 0.76 * hash01(UInt64(n) &* 2 &+ 2, seed: seed))
        }
        var cur = rawPoint(0)
        guard step > 0 else { return cur }
        for n in 1...step {
            var next = rawPoint(n)
            if hypot(next.x - cur.x, next.y - cur.y) < 0.3 {
                // Đẩy ngang sang nửa đối diện (dịch ≥ 0.4) thay vì lấy điểm mới,
                // giữ tính tất định.
                next.x = cur.x < 0.5 ? min(0.9, cur.x + 0.5) : max(0.1, cur.x - 0.5)
            }
            cur = next
        }
        return cur
    }

    /// Hash tất định → [0,1) (SplitMix64 rút gọn).
    static func hash01(_ n: UInt64, seed: UInt64) -> Double {
        var z = n &+ seed &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
}
