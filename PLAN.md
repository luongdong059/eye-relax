# Eye Relax — Kế hoạch phát triển ứng dụng macOS

Ứng dụng chạy nền trên macOS, hiển thị một icon di chuyển theo các quỹ đạo (bài tập) trên màn hình để người dùng luyện mắt nhìn theo. Icon hiển thị đè lên mọi ứng dụng khác, có hiệu ứng trail, tuỳ chỉnh được icon, tốc độ và lịch nhắc lại.

---

## 1. Mục tiêu & Phạm vi

> **Tiến độ (16/07/2026):** MVP đã chạy được — toàn bộ tính năng cốt lõi bên dưới đã hoàn thành, 15/15 unit test pass, đóng gói được `build/EyeRelax.app`. Xem [README.md](README.md) để build/chạy. Còn lại: hoàn thiện phát hành (M7).

### Tính năng cốt lõi (MVP)
- [x] Icon di chuyển trên màn hình theo các quỹ đạo định sẵn, **đè lên mọi ứng dụng** (kể cả app fullscreen).
- [x] Overlay **click-through**: không chặn chuột/bàn phím, người dùng vẫn làm việc bình thường.
- [x] **Trail effect** (vệt mờ dần) khi icon di chuyển.
- [x] Tuỳ chỉnh **tốc độ** di chuyển và **thời lượng** mỗi bài tập.
- [x] **Lịch nhắc lại**: tự động chạy bài tập sau mỗi X phút (ví dụ theo quy tắc 20-20-20).
- [x] **Nhóm bài tập** riêng, mỗi nhóm có các quỹ đạo di chuyển riêng.
- [x] **Custom icon**: chọn SF Symbol, emoji, hoặc import ảnh PNG của người dùng.
- [x] App có **Dock icon** (app icon dựng từ `cartoon.png`), click Dock icon mở cửa sổ chính.
- [x] **Cửa sổ chính (Settings UI)**: giao diện đầy đủ để người dùng cấu hình mọi thông số (lịch nhắc, bài tập, icon, trail).
- [x] Kèm **menu bar extra** để điều khiển nhanh (bắt đầu/tạm dừng) mà không cần mở cửa sổ chính.

### Ngoài phạm vi MVP (làm sau)
- Thống kê lịch sử luyện tập, streak.
- Đồng bộ iCloud.
- Hỗ trợ đa màn hình nâng cao (icon chạy xuyên qua các màn hình).
- Âm thanh hướng dẫn / giọng đọc.

---

## 2. Tech Stack

| Hạng mục | Lựa chọn | Ghi chú |
|---|---|---|
| Ngôn ngữ | Swift 5.9+ | |
| UI | SwiftUI + AppKit (hybrid) | SwiftUI cho Settings/menu bar; AppKit (`NSPanel`) cho cửa sổ overlay |
| macOS tối thiểu | macOS 13.0 (Ventura) | Để dùng `MenuBarExtra`, `SMAppService` |
| Animation | `TimelineView(.animation)` hoặc `CVDisplayLink` | 60–120 fps, đồng bộ tần số quét màn hình |
| Vẽ trail | SwiftUI `Canvas` | Ring buffer vị trí + vẽ bản sao mờ dần |
| Lưu trữ | `UserDefaults` (settings) + JSON/Codable (bài tập) | File JSON trong `~/Library/Application Support/EyeRelax/` |
| Khởi động cùng máy | `SMAppService.mainApp` | macOS 13+ |
| Build | Xcode 15+, không cần thư viện ngoài | Giữ app nhẹ, dễ notarize |

---

## 3. Kiến trúc tổng thể

```
┌─────────────────────────────────────────────────────┐
│                    EyeRelaxApp                       │
│        (App thường: Dock icon + MenuBarExtra)        │
├──────────────┬──────────────────┬───────────────────┤
│  MenuBarView │   MainWindow     │  OverlayWindow    │
│  (điều khiển │  (Settings UI    │  (NSPanel trong   │
│   nhanh)     │   đầy đủ)        │   suốt, toàn màn) │
├──────────────┴──────────────────┴───────────────────┤
│                 ExerciseEngine (core)                │
│   - ExerciseScheduler  (hẹn giờ nhắc lại)            │
│   - ExerciseRunner     (vòng lặp animation, t → xy)  │
│   - PathGenerator      (hàm quỹ đạo tham số)         │
│   - TrailRenderer      (ring buffer + fade)          │
├──────────────────────────────────────────────────────┤
│                  Persistence Layer                   │
│   - SettingsStore (UserDefaults/@AppStorage)         │
│   - ExerciseLibrary (JSON built-in + user custom)    │
│   - IconLibrary (SF Symbols/emoji/ảnh import)        │
└──────────────────────────────────────────────────────┘
```

### 3.1. Cửa sổ Overlay (thành phần quan trọng nhất)

Dùng `NSPanel` với cấu hình:

```swift
panel.styleMask = [.borderless, .nonactivatingPanel]
panel.level = .screenSaver              // đè lên mọi cửa sổ thường
panel.backgroundColor = .clear
panel.isOpaque = false
panel.hasShadow = false
panel.ignoresMouseEvents = true         // click-through hoàn toàn
panel.collectionBehavior = [
    .canJoinAllSpaces,                  // hiện trên mọi Space
    .fullScreenAuxiliary,               // hiện cả trên app fullscreen
    .stationary
]
panel.setFrame(screen.frame, display: true)
```

- Nội dung panel là `NSHostingView` chứa SwiftUI view vẽ icon + trail.
- Mỗi màn hình vật lý một panel (MVP: chỉ màn hình chính hoặc màn hình có chuột).
- Không cần quyền Accessibility/Screen Recording — overlay thuần túy vẽ, không đọc màn hình.

### 3.2. Animation Engine

- Mỗi quỹ đạo là một **hàm tham số** `position(progress: Double) -> CGPoint` với `progress ∈ [0, 1]`, toạ độ chuẩn hoá `[0,1]²` rồi map ra frame màn hình (trừ lề an toàn ~5%).
- `ExerciseRunner` tick theo `TimelineView(.animation)`: tính `progress = (elapsed × speed) / duration_of_lap`, hỗ trợ lặp nhiều vòng.
- **Easing**: với bài smooth pursuit dùng chuyển động đều hoặc ease-in-out nhẹ ở điểm đảo chiều; với bài saccade (nhảy điểm) icon dừng ở mỗi điểm 0.5–1s rồi nhảy tức thời.

### 3.3. Trail Effect

- Ring buffer lưu ~20–40 vị trí gần nhất (kèm timestamp).
- Vẽ bằng `Canvas`: mỗi điểm cũ vẽ một bản sao icon (hoặc chấm tròn màu icon) với opacity và scale giảm dần theo tuổi của điểm.
- Tuỳ chỉnh: bật/tắt, độ dài trail (số điểm), kiểu trail (bản sao icon / chấm tròn / nét vẽ liền `Path`).

---

## 4. Nhóm bài tập & Quỹ đạo

Mỗi **nhóm bài tập** (ExerciseGroup) gồm nhiều **bài tập** (Exercise). Mỗi bài tập = quỹ đạo + tốc độ mặc định + số vòng lặp + mô tả.

### Nhóm 1 — Smooth Pursuit (nhìn đuổi mượt)
| Bài tập | Quỹ đạo | Công thức |
|---|---|---|
| Ngang | Trái ↔ phải | `x = t`, `y = 0.5` (ping-pong) |
| Dọc | Trên ↕ dưới | `x = 0.5`, `y = t` |
| Chéo | 2 đường chéo | Tuyến tính giữa các góc |
| Vòng tròn | Hình tròn | `x = cx + r·cos(2πt)`, `y = cy + r·sin(2πt)` |
| Số 8 nằm (∞) | Lemniscate | `x = 0.5 + A·sin(2πt)`, `y = 0.5 + B·sin(4πt)/2` |
| Sóng sin | Lượn sóng ngang | `x = t`, `y = 0.5 + A·sin(4πt)` |
| Xoắn ốc | Trong → ngoài | `r(t) = r_max·t`, quay N vòng |

### Nhóm 2 — Saccades (nhảy điểm nhanh)
| Bài tập | Mô tả |
|---|---|
| Hai điểm ngang | Icon xuất hiện luân phiên trái/phải, dừng ~0.8s |
| Bốn góc | Nhảy theo 4 góc màn hình |
| Điểm ngẫu nhiên | Nhảy tới vị trí ngẫu nhiên (có khoảng cách tối thiểu) |

### Nhóm 3 — Focus / Điều tiết
| Bài tập | Mô tả |
|---|---|
| Gần – xa | Icon đứng giữa màn hình, phóng to ↔ thu nhỏ chậm (mô phỏng tiêu cự) |
| Zoom + tròn | Kết hợp vòng tròn nhỏ dần/lớn dần |

### Nhóm 4 — Nghỉ ngơi (20-20-20)
| Bài tập | Mô tả |
|---|---|
| Nhắc nhìn xa | Overlay hiện thông điệp "Nhìn xa 6m trong 20 giây" + đếm ngược, không có icon di chuyển |
| Chớp mắt | Icon nhấp nháy nhịp chậm nhắc chớp mắt |

### Data model

```swift
enum PathType: String, Codable {
    case horizontal, vertical, diagonal, circle,
         figureEight, sineWave, spiral,
         saccadeHorizontal, saccadeCorners, saccadeRandom,
         nearFar, blink, restReminder
}

struct Exercise: Codable, Identifiable {
    let id: UUID
    var name: String
    var pathType: PathType
    var speed: Double          // 0.5x – 3x
    var laps: Int              // số vòng lặp
    var duration: TimeInterval // hoặc tính từ laps × chu kỳ
}

struct ExerciseGroup: Codable, Identifiable {
    let id: UUID
    var name: String           // "Smooth Pursuit", "Saccades", ...
    var exercises: [Exercise]
    var isEnabled: Bool
}
```

- Bài tập built-in định nghĩa bằng code (`ExerciseLibrary.builtinGroups()` — an toàn kiểu, không rủi ro decode thay vì JSON trong bundle như dự kiến ban đầu). Người dùng chỉnh tốc độ/số vòng từng bài và bật/tắt từng nhóm; bản chỉnh sửa lưu JSON ở `~/Library/Application Support/EyeRelax/exercises.json`.

---

## 5. Tuỳ chỉnh Icon

- **Icon mặc định**: `cartoon.png` (đôi mắt hoạt hình, 128×128 có alpha — đóng gói vào bundle), đồng bộ nhận diện với app icon.
- **Nguồn icon khác**:
  1. SF Symbols có sẵn (danh sách chọn lọc: chấm tròn, ngôi sao, mặt cười, con bướm…).
  2. Emoji (nhập bằng emoji picker).
  3. Ảnh của người dùng (PNG/JPEG có alpha, import qua file picker, copy vào Application Support, tự resize về ≤128px).
- **Tuỳ chỉnh**: kích thước (24–96 pt), màu (với SF Symbol), độ trong suốt, có/không glow (shadow màu) để nổi bật trên mọi nền.

---

## 6. Scheduler (nhắc lại theo chu kỳ)

- Cài đặt: khoảng cách giữa các phiên (5–120 phút, mặc định 20), bật/tắt tự động chạy.
- Hai chế độ khi tới giờ:
  1. **Tự chạy ngay**: overlay xuất hiện, chạy playlist bài tập của nhóm được chọn.
  2. **Thông báo trước**: bắn `UserNotification` với nút "Bắt đầu" / "Bỏ qua" / "Hoãn 5 phút".
- Tạm hoãn thông minh (nice-to-have): không kích hoạt khi đang có app trình chiếu/họp fullscreen — kiểm tra bằng `NSWorkspace.frontmostApplication` với danh sách loại trừ do người dùng cấu hình.
- Dùng `Timer` + lưu `nextFireDate` để khôi phục đúng lịch sau khi máy sleep/wake (`NSWorkspace.didWakeNotification`).

---

## 7. Giao diện

### 7.1. Dock icon & App icon

- App chạy dạng **app thường** (không đặt `LSUIElement`): có Dock icon, click Dock icon mở **cửa sổ chính** (Settings UI). Đóng cửa sổ chính app **vẫn chạy nền** (scheduler tiếp tục hoạt động).
- **App icon dựng từ `cartoon.png`** (đôi mắt hoạt hình có sẵn trong repo):
  - File gốc hiện tại là **128×128 px** — đủ cho các cỡ nhỏ nhưng **thiếu cho chuẩn macOS (cần tới 1024×1024)**. Hướng xử lý: vẽ lại dạng vector (SVG → export PNG) hoặc upscale chất lượng cao; vì hình là line-art đen trắng đơn giản nên vẽ lại rất nhanh và cho kết quả sắc nét nhất.
  - Theo style macOS Big Sur+: đặt hình đôi mắt lên nền rounded-rect (squircle) màu sáng dịu (ví dụ nền trắng kem/xanh mint) với padding chuẩn ~10%.
  - Tạo `AppIcon.appiconset` đủ các cỡ: 16/32/64/128/256/512/1024 (@1x và @2x). Có thể generate tự động bằng script `sips` + `iconutil` từ file 1024px:
    ```bash
    # từ icon-1024.png sinh đủ cỡ rồi đóng .icns
    for s in 16 32 64 128 256 512 1024; do
      sips -z $s $s icon-1024.png --out AppIcon.iconset/icon_${s}x${s}.png
    done
    iconutil -c icns AppIcon.iconset
    ```
- Dock icon có thể hiện **badge đếm ngược** tới phiên tập tiếp theo (`NSApp.dockTile.badgeLabel`) — nice-to-have.
- Tuỳ chọn nâng cao trong Settings: "Ẩn Dock icon, chỉ dùng menu bar" (`NSApp.setActivationPolicy(.accessory)`) cho người thích gọn.

### 7.2. Menu bar (MenuBarExtra)
- Trạng thái: thời gian đến phiên tiếp theo.
- Nút: **Bắt đầu ngay** (chọn nhóm bài tập), **Tạm dừng nhắc 1 giờ**, **Mở cửa sổ chính…**, **Quit**.

### 7.3. Cửa sổ chính — Settings UI (SwiftUI)

Cửa sổ chính là nơi người dùng cấu hình **toàn bộ thông số**. Layout dạng **sidebar trái + vùng nội dung phải** (`NavigationSplitView`), kích thước ~720×480:

```
┌────────────┬──────────────────────────────────────────┐
│ ⚙ Chung    │  Khoảng nhắc lại      [ 20 phút  ▾]      │
│ 👁 Bài tập │  Khi tới giờ          (•) Tự chạy        │
│ 🎨 Icon    │                       ( ) Thông báo trước │
│ ✨ Trail   │  Thời lượng phiên     [──●────] 2 phút    │
│ ⏰ Lịch    │  Khởi động cùng máy   [✓]                 │
│            │  Màn hình hiển thị    [ Màn hình chính ▾] │
│            │  Ẩn Dock icon         [ ]                 │
│  [Preview] │                                          │
└────────────┴──────────────────────────────────────────┘
```

Chi tiết từng mục và thông số cấu hình:

| Mục | Thông số | Control |
|---|---|---|
| **Chung** | Khởi động cùng máy; màn hình hiển thị; ẩn Dock icon; ngôn ngữ | Toggle, Picker |
| **Bài tập** | Bật/tắt từng nhóm và từng bài; **tốc độ** (slider 0.5x–3x); **số vòng lặp** (stepper); thời lượng mỗi bài; thứ tự bài trong playlist (kéo thả) | List 2 cấp + slider/stepper, nút **Xem thử** từng bài |
| **Icon** | Nguồn (SF Symbol / emoji / ảnh import); kích thước (24–96 pt); màu; độ trong suốt; glow | Picker, slider, ColorPicker, nút Import…, **preview trực tiếp** |
| **Trail** | Bật/tắt; độ dài (số điểm); kiểu (bản sao icon / chấm tròn / nét liền); độ mờ | Toggle, slider, Picker, **preview động** (icon chạy vòng tròn nhỏ ngay trong pane) |
| **Lịch** | Khoảng thời gian nhắc lại (5–120 phút); chế độ khi tới giờ (tự chạy / thông báo); hoãn mặc định (5/10/15 phút); khung giờ hoạt động (ví dụ chỉ 9h–18h); danh sách app loại trừ (đang họp/trình chiếu thì không nhắc) | Slider, Radio, Picker, List |

- Mọi thay đổi **áp dụng ngay** (không cần nút Save) — chuẩn macOS, lưu qua `@AppStorage`/JSON.
- Nút **Preview** ở góc sidebar: chạy thử bài tập đang chọn với đúng icon + trail hiện tại trong 10 giây.

### 7.4. Trong lúc chạy bài tập
- Icon + trail di chuyển; góc màn hình hiện tên bài tập + nút **Bỏ qua bài** / **Dừng** (vùng nhỏ này là panel thứ hai **có nhận** chuột, tách khỏi overlay click-through).
- Hoàn thành bài cuối → **màn chúc mừng 6s**: pháo bông nổ (Canvas, hàm thuần theo thời gian), câu chúc ngẫu nhiên theo phiên, nhắc uống nước 💧 và bổ sung vitamin A 🥕, footer "Design by Dong".
- Phím tắt `Esc` (global hotkey — nice-to-have) hoặc click menu bar để dừng.

---

## 8. Cấu trúc thư mục dự án (thực tế)

Dùng **Swift Package Manager** thay vì `.xcodeproj`: build được từ CLI (`swift build`/`swift test`), Xcode mở trực tiếp bằng `open Package.swift`. Đóng gói `.app` bằng script.

```
eye-relax/
├── PLAN.md / README.md
├── cartoon.png                        # nguồn icon gốc (128px)
├── Package.swift                      # SPM: EyeRelaxCore (logic) + EyeRelax (UI)
├── Support/
│   ├── Info.plist                     # bundle id, icon, LSMinimumSystemVersion…
│   └── AppIcon.icns                   # sinh bởi scripts/make-appicon.sh
├── scripts/
│   ├── render-appicon.swift           # cartoon.png → squircle gradient 1024px
│   ├── make-appicon.sh                # → Support/AppIcon.icns (đủ 10 cỡ)
│   └── build-app.sh                   # swift build -c release + đóng gói + ký ad-hoc
├── Sources/
│   ├── EyeRelaxCore/                  # logic thuần, không UI — unit test được
│   │   ├── Models.swift               # PathType, Exercise, ExerciseGroup, IconConfig, TrailConfig
│   │   ├── PathGenerator.swift        # hàm quỹ đạo thuần (phase → PathSample)
│   │   ├── ExerciseRunner.swift       # phiên tập: playlist, intermission, frame(at:)
│   │   ├── ExerciseScheduler.swift    # hẹn giờ + snooze + sleep/wake resync
│   │   └── ExerciseLibrary.swift      # bộ bài tập built-in + lưu chỉnh sửa (JSON)
│   └── EyeRelax/                      # app SwiftUI/AppKit
│       ├── EyeRelaxApp.swift          # @main: Window + MenuBarExtra + AppDelegate
│       ├── App/                       # AppState (đầu não), Notifier
│       ├── Overlay/                   # OverlayController/Panel, OverlayContentView,
│       │                              #   IconView, ControlBadgeView (badge Dừng/Bỏ qua)
│       ├── MainWindow/                # MainWindowView + 5 pane (Chung/Bài tập/Icon/Trail/Lịch)
│       ├── MenuBar/MenuBarView.swift
│       ├── Persistence/SettingsStore.swift
│       ├── Support/Utilities.swift    # Color↔hex, cache icon import
│       └── Resources/cartoon.png      # icon mặc định trên overlay
├── Tests/EyeRelaxCoreTests/           # 15 test: biên quỹ đạo, liên tục, runner, scheduler…
└── build/EyeRelax.app                 # sản phẩm của scripts/build-app.sh
```

---

## 9. Lộ trình thực hiện (Milestones)

### M1 — Skeleton & Overlay (nền tảng) ✅ hoàn thành 16/07/2026
- [x] Tạo project (SPM): app thường có Dock icon, `Window` (cửa sổ chính) + `MenuBarExtra`; đóng cửa sổ app vẫn chạy nền.
- [x] Dựng **AppIcon từ `cartoon.png`**: script vẽ squircle gradient 1024px + generate `.icns` đủ 10 cỡ.
- [x] `OverlayPanel` trong suốt, click-through, `.screenSaver` level + `.fullScreenAuxiliary`, hiện trên màn hình có con trỏ chuột.
- [x] Overlay hiển thị trên mọi Space (`.canJoinAllSpaces`).

### M2 — Animation Engine ✅
- [x] `PathGenerator` với đủ 13 quỹ đạo (vượt kế hoạch: làm luôn thay vì 4 quỹ đạo đầu).
- [x] `ExerciseRunner`: chạy icon theo quỹ đạo, chỉnh được tốc độ, số vòng, ping-pong; render là hàm thuần theo thời gian qua `TimelineView(.animation)`.
- [x] Unit test cho các hàm quỹ đạo (trong biên [0,1]², liên tục, khớp đầu-cuối vòng).

### M3 — Trail Effect ✅
- [x] Trail tính ngược thời gian từ hàm quỹ đạo thuần (không cần ring buffer — đơn giản hơn thiết kế ban đầu).
- [x] Tuỳ chọn độ dài (4–30 điểm) và 3 kiểu trail (chấm tròn / bản sao icon / nét liền).

### M4 — Nhóm bài tập & Playlist ✅
- [x] Data model + bộ built-in đủ 4 nhóm (định nghĩa bằng code, chỉnh sửa lưu JSON ở Application Support).
- [x] Chạy tuần tự các bài trong nhóm (playlist), 2s chuẩn bị hiện tên bài trước mỗi bài.
- [x] Đủ các quỹ đạo: chéo, sóng sin, xoắn ốc, saccades, gần–xa, chớp mắt, nghỉ 20-20-20.

### M5 — Scheduler & Menu bar ✅
- [x] Hẹn giờ lặp lại, hoãn/bỏ qua; chế độ tự chạy hoặc chỉ thông báo (thông báo chưa có nút hành động — dời sang M7).
- [x] Xử lý sleep/wake (resync mốc hẹn), menu bar hiển thị giờ phiên tiếp theo.
- [x] Khởi động cùng máy (`SMAppService`, toggle trong pane Chung).

### M6 — Cửa sổ chính (Settings UI) & Custom Icon ✅
- [x] Cửa sổ chính `NavigationSplitView` 5 mục (Chung / Bài tập / Icon / Trail / Lịch), áp dụng ngay không cần Save (UserDefaults + JSON).
- [x] Import icon người dùng (PNG/JPEG), emoji, 12 SF Symbols + màu; preview nền sáng/tối trong pane Icon, preview động trong pane Trail.
- [x] Nút "Xem thử" từng bài / chạy cả nhóm; nút "Tập ngay" ở sidebar.
- [x] Tuỳ chọn ẩn Dock icon (`setActivationPolicy(.accessory)`).

### M7 — Hoàn thiện & Phát hành (gần xong)
- [x] Badge Dừng/Bỏ qua khi đang chạy; dựng lại overlay khi đổi độ phân giải/tháo màn hình.
- [x] Đẩy code lên GitHub (`luongdong059/eye-relax`) + **CI**: test & đóng gói mỗi push/PR (`ci.yml`), phát hành theo tag `v*` (`release.yml`).
- [x] **Tự cập nhật qua GitHub Releases**: so semver với `releases/latest`, tải zip, cài và tự khởi động lại (UpdateChecker + pane Chung → Cập nhật, kèm auto-check khi mở app).
- [x] **Pháo bông chúc mừng** khi hoàn thành cả phiên (6s, Canvas thuần theo thời gian) + lời chúc + nhắc uống nước / bổ sung vitamin A. Dừng tay thì bỏ qua.
- [x] Thông báo có nút hành động (Bắt đầu ngay / Hoãn lại) qua `UNNotificationAction` + delegate xử lý.
- [x] Badge đếm ngược phiên tiếp theo trên Dock icon (bật/tắt trong pane Chung).
- [x] Đóng gói **DMG** (`scripts/make-dmg.sh`, kèm symlink /Applications) — đính kèm cả zip lẫn DMG vào mỗi Release.
- [x] **LICENSE (MIT)** + credit "Design by Dong" (README, pane Giới thiệu, card chúc mừng, Info.plist).
- [ ] Đo và tinh chỉnh hiệu năng (CPU khi idle ~0%, khi chạy < 10%).
- [ ] Ký Developer ID + **notarize** (cần Apple Developer Program; hiện ký ad-hoc — máy khác cần chuột phải → Open lần đầu).

**Tổng ước tính: ~2-3 tuần** (part-time có thể 4-5 tuần).

---

## 10. Rủi ro & Lưu ý kỹ thuật

| Rủi ro | Giải pháp |
|---|---|
| Overlay không hiện trên app fullscreen | Phải dùng `.fullScreenAuxiliary` + `nonactivatingPanel`; test kỹ với Safari/QuickTime fullscreen |
| Icon gây khó chịu/che nội dung khi đang làm việc | Chỉ hiện khi tới phiên tập; cho phép hoãn; glow nhẹ thay vì nền đặc |
| Trail tốn CPU/GPU | Giới hạn buffer ≤ 40 điểm, dùng `Canvas` (Metal-backed), drawing chỉ khi đang chạy bài tập |
| Timer lệch sau khi Mac sleep | Lưu `nextFireDate` tuyệt đối, resync khi nhận `didWakeNotification` |
| Đa màn hình: icon chạy sai màn | MVP chọn 1 màn hình (mặc định màn có chuột); panel tạo lại khi nhận `NSApplication.didChangeScreenParametersNotification` |
| `cartoon.png` chỉ 128px, không đủ chuẩn app icon 1024px | Vẽ lại dạng vector (line-art đơn giản, nhanh) hoặc upscale; giữ file gốc làm icon mặc định cho overlay |
| App Store review với overlay | Không dùng private API; overlay là tính năng chính, mô tả rõ trong review notes |

---

## 11. Câu hỏi mở (quyết định sau)

1. Có cần chế độ **nền tối mờ** phía sau icon khi tập (giúp tập trung, che bớt nội dung) không? → Đề xuất: có, dạng tuỳ chọn, mặc định tắt.
2. Bài tập có **âm thanh** (tick khi đổi hướng) không? → Để sau MVP.
3. Người dùng có được **tự tạo bài tập mới** (chọn quỹ đạo + tham số) hay chỉ chỉnh bài có sẵn? → MVP: chỉ chỉnh tham số; editor tự tạo để v1.1.
4. Phát hành qua **App Store** hay **DMG + notarize**? → Ảnh hưởng sandbox và update mechanism (Sparkle nếu DMG).
