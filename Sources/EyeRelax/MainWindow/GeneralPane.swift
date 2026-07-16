import SwiftUI
import ServiceManagement

struct GeneralPane: View {
    @ObservedObject var settings: SettingsStore

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
