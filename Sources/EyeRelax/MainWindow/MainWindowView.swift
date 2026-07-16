import SwiftUI
import EyeRelaxCore

/// Cửa sổ chính: sidebar trái + pane cấu hình bên phải.
struct MainWindowView: View {
    @EnvironmentObject var appState: AppState

    enum Pane: String, CaseIterable, Identifiable {
        case general, exercises, icon, trail, schedule

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "Chung"
            case .exercises: return "Bài tập"
            case .icon: return "Icon"
            case .trail: return "Trail"
            case .schedule: return "Lịch nhắc"
            }
        }

        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .exercises: return "figure.run"
            case .icon: return "eye"
            case .trail: return "sparkles"
            case .schedule: return "clock"
            }
        }
    }

    @State private var pane: Pane? = .schedule

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { pane in
                Label(pane.title, systemImage: pane.systemImage).tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 185, max: 220)
            .safeAreaInset(edge: .bottom) {
                startNowButton
            }
        } detail: {
            switch pane ?? .schedule {
            case .general:
                GeneralPane(settings: appState.settings)
            case .exercises:
                ExercisesPane(library: appState.library)
            case .icon:
                IconPane(settings: appState.settings)
            case .trail:
                TrailPane(settings: appState.settings)
            case .schedule:
                SchedulePane(settings: appState.settings, scheduler: appState.scheduler)
            }
        }
        .frame(minWidth: 740, minHeight: 480)
        .navigationTitle("Eye Relax")
    }

    private var startNowButton: some View {
        Button {
            appState.startSession()
        } label: {
            Label("Tập ngay", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .padding(12)
    }
}
