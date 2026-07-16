import SwiftUI
import UniformTypeIdentifiers
import EyeRelaxCore

struct IconPane: View {
    @ObservedObject var settings: SettingsStore
    @State private var emojiText = ""
    @State private var importError: String?

    private enum SourceKind: String, CaseIterable {
        case builtin = "Mặc định", symbol = "SF Symbol", emoji = "Emoji", custom = "Ảnh riêng"
    }

    private static let symbols = [
        "circle.fill", "star.fill", "heart.fill", "sun.max.fill",
        "moon.stars.fill", "leaf.fill", "pawprint.fill", "ladybug.fill",
        "sparkle", "eye.fill", "flame.fill", "drop.fill",
    ]

    var body: some View {
        Form {
            Section {
                preview
            }

            Section("Nguồn icon") {
                Picker("Nguồn", selection: sourceKindBinding) {
                    ForEach(SourceKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch sourceKindBinding.wrappedValue {
                case .builtin:
                    Text("Đôi mắt hoạt hình — icon nhận diện của Eye Relax.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .symbol:
                    symbolGrid
                    ColorPicker("Màu icon", selection: colorBinding, supportsOpacity: false)
                case .emoji:
                    TextField("Nhập một emoji (ví dụ 🎈)", text: $emojiText)
                        .onChange(of: emojiText) { text in
                            if let first = text.last.map(String.init) {
                                settings.icon.source = .emoji(first)
                            }
                        }
                case .custom:
                    Button("Chọn ảnh PNG/JPEG…") { importImage() }
                    if case .customImage(let filename) = settings.icon.source {
                        Text(filename)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let importError {
                        Text(importError).font(.caption).foregroundStyle(.red)
                    }
                }
            }

            Section("Hiển thị") {
                LabeledContent("Kích thước") {
                    Slider(value: $settings.icon.size, in: 24...96) {
                        Text("Kích thước")
                    } minimumValueLabel: {
                        Image(systemName: "circle.fill").font(.system(size: 8))
                    } maximumValueLabel: {
                        Image(systemName: "circle.fill").font(.system(size: 16))
                    }
                    .frame(width: 260)
                }
                LabeledContent("Độ đậm") {
                    Slider(value: $settings.icon.opacity, in: 0.4...1)
                        .frame(width: 260)
                }
                Toggle("Viền sáng (glow) — nổi bật trên mọi nền", isOn: $settings.icon.glow)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if case .emoji(let e) = settings.icon.source { emojiText = e }
        }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            // Nền hai nửa sáng/tối để thấy hiệu quả glow trên cả hai loại nền.
            HStack(spacing: 0) {
                Color(nsColor: .textBackgroundColor)
                Color(nsColor: .darkGray)
            }
            HStack(spacing: 60) {
                IconView(config: settings.icon)
                IconView(config: settings.icon)
            }
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var symbolGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
            ForEach(Self.symbols, id: \.self) { name in
                Button {
                    settings.icon.source = .sfSymbol(name)
                } label: {
                    Image(systemName: name)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 40)
                        .background(isSelected(name) ? Color.accentColor.opacity(0.25) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func isSelected(_ symbol: String) -> Bool {
        if case .sfSymbol(let current) = settings.icon.source { return current == symbol }
        return false
    }

    // MARK: - Bindings

    private var sourceKindBinding: Binding<SourceKind> {
        Binding {
            switch settings.icon.source {
            case .builtinCartoon: return .builtin
            case .sfSymbol: return .symbol
            case .emoji: return .emoji
            case .customImage: return .custom
            }
        } set: { kind in
            switch kind {
            case .builtin: settings.icon.source = .builtinCartoon
            case .symbol: settings.icon.source = .sfSymbol(Self.symbols[0])
            case .emoji: settings.icon.source = .emoji(emojiText.isEmpty ? "👀" : emojiText)
            case .custom:
                if case .customImage = settings.icon.source { break }
                importImage()
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding {
            Color(hex: settings.icon.colorHex)
        } set: {
            settings.icon.colorHex = $0.hexString
        }
    }

    private func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let filename = try IconAssets.importCustomImage(from: url)
            settings.icon.source = .customImage(filename: filename)
            importError = nil
        } catch {
            importError = "Không import được ảnh: \(error.localizedDescription)"
        }
    }
}
