import AppKit
import Combine
import EyeRelaxCore

/// Kiểm tra & cài bản mới qua GitHub Releases:
/// 1. Gọi `releases/latest`, so tag (semver) với `CFBundleShortVersionString`.
/// 2. Nếu có bản mới: tải asset .zip, giải nén, đưa bản cũ vào Thùng rác,
///    copy bản mới vào đúng vị trí rồi khởi động lại app.
/// Khi chạy dev (`swift run`, không có bundle) chỉ báo kết quả, không tự cài.
@MainActor
final class UpdateChecker: ObservableObject {

    static let repo = "luongdong059/eye-relax"

    struct Release: Decodable, Equatable {
        struct Asset: Decodable, Equatable {
            let name: String
            let browserDownloadUrl: URL
        }
        let tagName: String
        let htmlUrl: URL
        let body: String?
        let assets: [Asset]
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var latestRelease: Release?

    private enum UpdateError: LocalizedError {
        case noRelease
        case badTag(String)
        case badArchive
        case processFailed(String, Int32)

        var errorDescription: String? {
            switch self {
            case .noRelease:
                return "Chưa có bản phát hành nào trên GitHub."
            case .badTag(let tag):
                return "Tag \"\(tag)\" không phải dạng semver (vd: v0.2.0)."
            case .badArchive:
                return "File tải về không chứa EyeRelax.app."
            case .processFailed(let tool, let code):
                return "\(tool) thoát với mã \(code)."
            }
        }
    }

    var currentVersion: AppVersion? {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            .flatMap(AppVersion.init)
    }

    var isRunningFromBundle: Bool { Bundle.main.bundleIdentifier != nil }

    // MARK: - Kiểm tra

    /// `silent`: chạy nền lúc mở app — lỗi mạng thì im lặng, có bản mới thì
    /// bắn notification thay vì chỉ đổi state.
    func check(silent: Bool = false) async {
        guard state != .checking, state != .downloading, state != .installing else { return }
        state = .checking
        do {
            let release = try await fetchLatestRelease()
            latestRelease = release
            guard let remote = AppVersion(release.tagName) else {
                throw UpdateError.badTag(release.tagName)
            }
            if let current = currentVersion, remote > current {
                state = .available(version: remote.description)
                if silent { Notifier.postUpdateAvailable(remote.description) }
            } else {
                state = .upToDate
            }
        } catch {
            state = silent ? .idle : .failed(error.localizedDescription)
        }
    }

    private func fetchLatestRelease() async throws -> Release {
        let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status != 404 else { throw UpdateError.noRelease }
        guard status == 200 else { throw UpdateError.processFailed("GitHub API", Int32(status)) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Release.self, from: data)
    }

    // MARK: - Cài đặt

    func installLatest() async {
        guard let release = latestRelease else { return }
        guard isRunningFromBundle else {
            openReleasePage()
            return
        }
        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            // Release không đính kèm .zip → để người dùng tải tay.
            openReleasePage()
            return
        }
        do {
            state = .downloading
            let (zipURL, _) = try await URLSession.shared.download(from: asset.browserDownloadUrl)

            state = .installing
            let workDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("EyeRelaxUpdate-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
            try await runProcess("/usr/bin/ditto", ["-x", "-k", zipURL.path, workDir.path])

            let contents = try FileManager.default.contentsOfDirectory(
                at: workDir, includingPropertiesForKeys: nil)
            guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
                throw UpdateError.badArchive
            }
            // Gỡ cờ quarantine để bản mới chạy được ngay (asset do chính CI build).
            _ = try? await runProcess("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

            let target = Bundle.main.bundleURL
            try FileManager.default.trashItem(at: target, resultingItemURL: nil)
            try await runProcess("/usr/bin/ditto", [newApp.path, target.path])

            try await runProcess("/usr/bin/open", ["-n", target.path])
            NSApp.terminate(nil)
        } catch {
            state = .failed("Không cài được: \(error.localizedDescription) — bạn có thể tải tay từ trang phát hành.")
        }
    }

    func openReleasePage() {
        let fallback = URL(string: "https://github.com/\(Self.repo)/releases")!
        NSWorkspace.shared.open(latestRelease?.htmlUrl ?? fallback)
    }

    @discardableResult
    private func runProcess(_ path: String, _ args: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: 0)
                } else {
                    continuation.resume(throwing: UpdateError.processFailed(
                        (path as NSString).lastPathComponent, proc.terminationStatus))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
