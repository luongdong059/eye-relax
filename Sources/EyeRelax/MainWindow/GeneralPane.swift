import SwiftUI
import ServiceManagement

struct GeneralPane: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var updater: UpdateChecker

    @State private var launchAtLogin = false
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section("Hệ thống") {
                Toggle("Khởi động cùng máy", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        updateLoginItem(enabled: enabled)
                    }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle("Ẩn Dock icon (chỉ hiện trên menu bar)", isOn: $settings.hideDockIcon)
                Text("Khi ẩn Dock icon, mở lại cửa sổ này từ biểu tượng con mắt trên menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Màn hình") {
                LabeledContent("Overlay hiển thị trên",
                               value: "Màn hình đang có con trỏ chuột")
                Text("Bài tập xuất hiện trên màn hình bạn đang làm việc tại thời điểm bắt đầu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cập nhật") {
                Toggle("Tự kiểm tra bản mới khi mở app", isOn: $settings.autoCheckUpdates)

                updateStatus

                HStack(spacing: 10) {
                    Button("Kiểm tra ngay") {
                        Task { await updater.check() }
                    }
                    .disabled(updaterBusy)

                    if case .available = updater.state {
                        Button("Tải & cài đặt") {
                            Task { await updater.installLatest() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!updater.isRunningFromBundle)

                        Button("Mở trang phát hành") { updater.openReleasePage() }
                    }
                }

                if !updater.isRunningFromBundle {
                    Text("Đang chạy bản dev (swift run) — chỉ kiểm tra, không tự cài đặt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Giới thiệu") {
                LabeledContent("Phiên bản", value: appVersion)
                Text("Eye Relax nhắc bạn tập thể dục cho mắt theo chu kỳ: mắt nhìn theo icon di chuyển trên màn hình, kết hợp nghỉ ngơi theo quy tắc 20-20-20.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    private var updaterBusy: Bool {
        [.checking, .downloading, .installing].contains(updater.state)
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Đang kiểm tra…").foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("Bạn đang dùng bản mới nhất (\(appVersion)).", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .available(let version):
            VStack(alignment: .leading, spacing: 4) {
                Label("Đã có bản \(version) — bạn đang dùng \(appVersion).",
                      systemImage: "sparkles")
                    .foregroundStyle(.orange)
                if let notes = updater.latestRelease?.body, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        case .downloading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Đang tải bản mới…").foregroundStyle(.secondary)
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Đang cài đặt — app sẽ tự khởi động lại…").foregroundStyle(.secondary)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message).font(.caption).foregroundStyle(.red)
                Button("Mở trang phát hành") { updater.openReleasePage() }
                    .controlSize(.small)
            }
        }
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            // Chạy ngoài bundle (swift run) hoặc bị hệ thống từ chối.
            loginItemError = "Không đăng ký được: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
