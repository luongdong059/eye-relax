import SwiftUI
import EyeRelaxCore

struct TrailPane: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                TrailPreview(settings: settings)
            }

            Section("Trail Effect") {
                Toggle("Bật trail khi icon di chuyển", isOn: $settings.trail.enabled)

                Picker("Kiểu trail", selection: $settings.trail.style) {
                    ForEach(TrailConfig.Style.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!settings.trail.enabled)

                LabeledContent("Độ dài") {
                    HStack(spacing: 8) {
                        Slider(value: trailLengthBinding, in: 4...30, step: 1)
                            .frame(width: 240)
                        Text("\(settings.trail.length) điểm")
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                .disabled(!settings.trail.enabled)

                Text("Trail chỉ áp dụng cho các bài nhìn đuổi mượt; bài nhảy điểm (saccade) không có trail để tránh gây rối mắt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var trailLengthBinding: Binding<Double> {
        Binding {
            Double(settings.trail.length)
        } set: {
            settings.trail.length = Int($0)
        }
    }
}

/// Preview động: icon chạy quỹ đạo số 8 thu nhỏ ngay trong pane, dùng đúng
/// pipeline PathGenerator + TrailView của overlay thật.
private struct TrailPreview: View {
    @ObservedObject var settings: SettingsStore

    private static let cycleDuration = 5.0
    private let start = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(start)
                let phase = (elapsed / Self.cycleDuration)
                    .truncatingRemainder(dividingBy: 1)
                let sample = PathGenerator.sample(.figureEight, phase: phase)
                let trail = trailSamples(phase: phase)
                let miniIcon = miniIconConfig

                ZStack {
                    Color(nsColor: .underPageBackgroundColor)
                    if settings.trail.enabled {
                        TrailView(trail: trail, config: settings.trail,
                                  icon: miniIcon, size: geo.size)
                    }
                    IconView(config: miniIcon)
                        .position(OverlayContentView.mapToScreen(sample, in: geo.size))
                }
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func trailSamples(phase: Double) -> [PathSample] {
        let spacing = 0.045 / Self.cycleDuration
        return (1...settings.trail.length).compactMap { i in
            let p = phase - Double(i) * spacing
            guard p >= 0 else { return nil }
            return PathGenerator.sample(.figureEight, phase: p)
        }
    }

    private var miniIconConfig: IconConfig {
        var config = settings.icon
        config.size = min(config.size * 0.6, 40)
        return config
    }
}
