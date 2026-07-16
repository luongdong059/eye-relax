# Eye Relax 👀

Ứng dụng macOS nhắc tập thể dục cho mắt: một icon di chuyển theo các quỹ đạo trên màn hình (đè lên mọi ứng dụng, click-through) để mắt nhìn theo, kèm hiệu ứng trail, lịch nhắc theo chu kỳ và bài nghỉ 20-20-20.

Kế hoạch chi tiết & tiến độ: [PLAN.md](PLAN.md).

## Yêu cầu

- macOS 13 (Ventura) trở lên
- Xcode 15+ / Swift 5.9+ (chỉ cần khi build từ source)

## Build & chạy

```bash
# Đóng gói app hoàn chỉnh (kèm app icon, ký ad-hoc)
./scripts/build-app.sh
open build/EyeRelax.app
```

Trong lúc phát triển:

```bash
swift run          # chạy nhanh không cần đóng gói (thiếu Dock icon/notification)
swift test         # 15 unit test cho engine (quỹ đạo, runner, scheduler, library)
open Package.swift # mở bằng Xcode để debug
```

Sinh lại app icon từ `cartoon.png` (khi đổi ảnh nguồn):

```bash
./scripts/make-appicon.sh   # → Support/AppIcon.icns
```

## Sử dụng

- **Cửa sổ chính** (mở khi click Dock icon): cấu hình lịch nhắc, bật/tắt và tinh chỉnh từng bài tập (tốc độ 0.5x–3x, số vòng), chọn icon (mắt hoạt hình mặc định / SF Symbol / emoji / ảnh riêng), chỉnh trail, nút **Tập ngay**.
- **Menu bar** (biểu tượng con mắt): xem giờ phiên tiếp theo, bắt đầu ngay / theo nhóm, hoãn 1 giờ, thoát app.
- Khi đang tập: badge dưới đáy màn hình có nút **Bỏ qua bài** / **Dừng phiên**. Overlay không chặn chuột — bạn vẫn làm việc bình thường.
- Đóng cửa sổ chính app vẫn chạy nền và nhắc theo lịch (mặc định 20 phút/lần).

## Kiến trúc nhanh

- `Sources/EyeRelaxCore` — logic thuần (models, quỹ đạo tham số, runner, scheduler), phủ unit test.
- `Sources/EyeRelax` — UI: overlay `NSPanel` click-through (`.screenSaver` + `.fullScreenAuxiliary`), cửa sổ chính SwiftUI, menu bar.
- Không cần quyền Accessibility/Screen Recording — overlay chỉ vẽ, không đọc màn hình.
