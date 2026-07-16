import SwiftUI
import EyeRelaxCore

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var runner: ExerciseRunner
    @ObservedObject var scheduler: ExerciseScheduler
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if runner.session != nil {
            Text("Đang tập…")
            Button("Bỏ qua bài hiện tại") { appState.skipExercise() }
            Button("Dừng phiên tập") { appState.stopSession() }
        } else {
            if let next = scheduler.nextFireDate {
                Text("Phiên tiếp theo: \(next.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("Chưa hẹn lịch")
            }

            Button("Bắt đầu ngay") { appState.startSession() }

            Menu("Bắt đầu một nhóm") {
                ForEach(appState.library.groups) { group in
                    Button(group.name) { appState.startSession(group: group) }
                        .disabled(group.enabledExercises.isEmpty)
                }
            }

            Button("Hoãn 1 giờ") { appState.snooze(3600) }
                .disabled(scheduler.nextFireDate == nil)
        }

        Divider()

        Button("Mở Eye Relax…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Thoát Eye Relax") { NSApp.terminate(nil) }
    }
}
