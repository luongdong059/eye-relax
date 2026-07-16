// Dựng app icon theo style macOS Big Sur+: đặt cartoon.png lên nền squircle
// gradient, xuất PNG 1024px. Chạy: swift scripts/render-appicon.swift <in> <out> [size]
import AppKit
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: swift render-appicon.swift <input.png> <output.png> [size]")
    exit(1)
}
let inputURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])
let size = args.count > 3 ? (Int(args[3]) ?? 1024) : 1024

guard let source = NSImage(contentsOf: inputURL),
      let sourceCG = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("error: không đọc được \(inputURL.path)")
    exit(1)
}

let canvas = CGFloat(size)
// Lưới icon của Apple: squircle chiếm ~80.5% canvas, phần còn lại là lề trong suốt.
let content = canvas * 0.805
let inset = (canvas - content) / 2
let radius = content * 0.225

guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    print("error: không tạo được context")
    exit(1)
}

let squircle = CGPath(roundedRect: CGRect(x: inset, y: inset, width: content, height: content),
                      cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(squircle)
ctx.clip()

// Nền gradient mint nhạt → dịu mắt, hợp chủ đề thư giãn.
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [CGColor(red: 0.95, green: 0.99, blue: 0.97, alpha: 1),
                                   CGColor(red: 0.72, green: 0.91, blue: 0.85, alpha: 1)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: canvas / 2, y: canvas),
                       end: CGPoint(x: canvas / 2, y: 0),
                       options: [])

// Đôi mắt cartoon ở giữa, chiếm ~58% squircle, giữ nguyên tỷ lệ ảnh gốc.
let targetWidth = content * 0.58
let aspect = CGFloat(sourceCG.height) / CGFloat(sourceCG.width)
let drawSize = CGSize(width: targetWidth, height: targetWidth * aspect)
let drawRect = CGRect(x: (canvas - drawSize.width) / 2,
                      y: (canvas - drawSize.height) / 2,
                      width: drawSize.width, height: drawSize.height)
ctx.interpolationQuality = .high
ctx.draw(sourceCG, in: drawRect)

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(outputURL as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else {
    print("error: không xuất được ảnh")
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("OK \(outputURL.path) (\(size)x\(size))")
