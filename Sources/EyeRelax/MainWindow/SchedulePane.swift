import SwiftUI
import EyeRelaxCore

struct SchedulePane: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var scheduler: ExerciseScheduler
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Chu kỳ nhắc") {
                Toggle("Tự động nhắc tập theo chu kỳ", isOn: $settings.schedulingEnabled)

                LabeledContent("Khoảng cách giữa các phiên") {
                    HStack(spacing: 8) {
                        Slider(value: intervalBinding, in: 5...120, step: 5)
                            .frame(width: 240)
                        Text("\(settings.intervalMinutes) phút")
                            .monospacedDigit()
                            .frame(width: 66, alignment: .trailing)
                    }
                }
                .disabled(!settings.schedulingEnabled)

                Text("Gợi ý: 20 phút theo quy tắc 20-20-20 (mỗi 20 phút nhìn xa 20 feet trong 20 giây).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Khi tới giờ") {
                Picker("Hành động", selection: $settings.triggerMode) {
                    ForEach(SessionTriggerMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .disabled(!settings.schedulingEnabled)

                Picker("Thời gian hoãn mặc định", selection: $settings.snoozeMinutes) {
                    Text("5 phút").tag(5)
                    Text("10 phút").tag(10)
                    Text("15 phút").tag(15)
                }
                .disabled(!settings.schedulingEnabled)
            }

            Section("Trạng thái") {
                if let next = scheduler.nextFireDate {
                    LabeledContent("Phiên tiếp theo") {
                        Text(next.formatted(date: .omitted, time: .shortened))
                            .monospacedDigit()
                    }
                } else {
                    LabeledContent("Phiên tiếp theo", value: "Chưa hẹn")
                }

                HStack {
                    Button("Tập ngay") { appState.startSession() }
                    Button("Hoãn \(settings.snoozeMinutes) phút") { appState.snooze() }
                        .disabled(scheduler.nextFireDate == nil)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var intervalBinding: Binding<Double> {
        Binding {
            Double(settings.intervalMinutes)
        } set: {
            settings.intervalMinutes = Int($0)
        }
    }
}
