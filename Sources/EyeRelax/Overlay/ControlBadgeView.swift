import SwiftUI
import EyeRelaxCore

/// Badge nhỏ dưới đáy màn hình khi đang tập: tên bài + nút Bỏ qua / Dừng.
struct ControlBadgeView: View {
    @ObservedObject var runner: ExerciseRunner

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            HStack(spacing: 14) {
                Text(runner.currentItem(at: context.date)?.exercise.name ?? "Eye Relax")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    runner.skipCurrent()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .buttonStyle(.borderless)
                .help("Bỏ qua bài này")

                Button {
                    runner.stop()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Dừng phiên tập")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .shadow(radius: 8)
        }
    }
}
