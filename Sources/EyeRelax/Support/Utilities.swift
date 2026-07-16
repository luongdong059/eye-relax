import SwiftUI
import AppKit

extension Color {
    /// Khởi tạo từ chuỗi hex "#RRGGBB".
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    var hexString: String {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return "#FFD60A" }
        return String(format: "#%02X%02X%02X",
                      Int(rgb.redComponent * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent * 255))
    }
}

/// Cache ảnh icon (bundle + icon người dùng import).
enum IconAssets {
    static let cartoon: NSImage? = Bundle.module
        .url(forResource: "cartoon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }

    private static var customCache: [String: NSImage] = [:]

    static func customImage(named filename: String) -> NSImage? {
        if let cached = customCache[filename] { return cached }
        guard let dir = customIconsDirectory() else { return nil }
        let image = NSImage(contentsOf: dir.appendingPathComponent(filename))
        if let image { customCache[filename] = image }
        return image
    }

    static func customIconsDirectory() -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("EyeRelax/icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Copy ảnh người dùng chọn vào Application Support, trả về tên file.
    static func importCustomImage(from source: URL) throws -> String {
        guard let dir = customIconsDirectory() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let filename = UUID().uuidString + "-" + source.lastPathComponent
        try FileManager.default.copyItem(at: source, to: dir.appendingPathComponent(filename))
        return filename
    }
}
