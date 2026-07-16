import SwiftUI
import EyeRelaxCore

struct ExercisesPane: View {
    @ObservedObject var library: ExerciseLibrary
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            ForEach($library.groups) { $group in
                Section {
                    ForEach($group.exercises) { $exercise in
                        ExerciseRow(exercise: $exercise) {
                            appState.preview(exercise)
                        }
                        .disabled(!group.isEnabled)
                    }
                } header: {
                    GroupHeader(group: $group) {
                        appState.startSession(group: group)
                    }
                }
            }

            Section {
                Button("Khôi phục bộ bài tập mặc định", role: .destructive) {
                    library.resetToBuiltin()
                }
            }
        }
    }
}

private struct GroupHeader: View {
    @Binding var group: ExerciseGroup
    var runGroup: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name).font(.headline)
                Text(group.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
            Spacer()
            Button {
                runGroup()
            } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.borderless)
            .help("Chạy cả nhóm này")
            .disabled(!group.isEnabled || group.enabledExercises.isEmpty)

            Toggle("", isOn: $group.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

private struct ExerciseRow: View {
    @Binding var exercise: Exercise
    var preview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $exercise.isEnabled)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                Text("\(exercise.pathType.displayName) · ~\(Int(exercise.duration.rounded()))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 130, alignment: .leading)

            Spacer()

            if exercise.pathType != .restReminder {
                Stepper("\(exercise.laps) vòng", value: $exercise.laps, in: 1...10)
                    .fixedSize()

                HStack(spacing: 6) {
                    Slider(value: $exercise.speed, in: 0.5...3, step: 0.25)
                        .frame(width: 130)
                    Text(String(format: "%.2gx", exercise.speed))
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 34, alignment: .trailing)
                }
            }

            Button(action: preview) {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.borderless)
            .help("Xem thử bài này")
        }
        .padding(.vertical, 2)
    }
}
