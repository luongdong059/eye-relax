import SwiftUI
import EyeRelaxCore

/// Vẽ icon bài tập theo `IconConfig` (dùng chung cho overlay, trail và preview
/// trong Settings).
struct IconView: View {
    let config: IconConfig
    /// Ghi đè kích thước (dùng cho trail thu nhỏ / scale gần-xa).
    var renderSize: Double?
    var withGlow: Bool = true

    private var size: Double { renderSize ?? config.size }

    var body: some View {
        content
            .frame(width: size, height: size)
            .opacity(config.opacity)
            .modifier(GlowModifier(enabled: withGlow && config.glow))
    }

    @ViewBuilder
    private var content: some View {
        switch config.source {
        case .builtinCartoon:
            if let image = IconAssets.cartoon {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                fallbackSymbol
            }
        case .sfSymbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(hex: config.colorHex))
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: size * 0.82))
                .minimumScaleFactor(0.5)
        case .customImage(let filename):
            if let image = IconAssets.customImage(named: filename) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                fallbackSymbol
            }
        }
    }

    private var fallbackSymbol: some View {
        Image(systemName: "eye.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color(hex: config.colorHex))
    }
}

/// Viền sáng + bóng tối kép để icon nổi bật trên cả nền sáng lẫn nền tối.
private struct GlowModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .shadow(color: .white.opacity(0.9), radius: 6)
                .shadow(color: .black.opacity(0.55), radius: 3)
        } else {
            content
        }
    }
}
