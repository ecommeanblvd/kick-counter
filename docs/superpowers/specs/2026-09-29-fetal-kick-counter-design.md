# Thiết kế: App đếm cử động thai (Kick Counter)

- **Ngày:** 2026-09-29
- **Trạng thái:** Đã duyệt thiết kế, chờ review spec
- **Nền tảng:** iOS 17+ (iPhone), SwiftUI, phát hành App Store

## 1. Mục tiêu

App iPhone giúp mẹ bầu (từ tuần thai 28) đếm cử động thai theo phương pháp
**đếm đến 10 (Cardiff)** một cách dễ dàng nhất có thể — kể cả khi nằm nghiêng
buổi tối, không cần mở khóa máy.

**Tiêu chí thành công v1:**
- Mẹ bắt đầu đếm và bấm "+1" được từ màn hình khóa / Dynamic Island.
- Mẹ biết ngay khi đạt 10 lần (và mất bao lâu), hoặc được cảnh báo khi quá
  2 giờ chưa đủ 10 lần.
- Xem lại được lịch sử và xu hướng 14 ngày.
- Qua được duyệt App Store (có miễn trừ y tế, không thu thập dữ liệu ra ngoài).

**Ngoài phạm vi v1 (YAGNI):** xuất PDF cho bác sĩ, đếm theo khung 1 giờ, chia
sẻ với người khác, server/tài khoản, Apple Watch, iPad.

## 2. Quyết định chính

| Hạng mục | Quyết định |
|---|---|
| Phương pháp | Đếm đến 10; ngưỡng cảnh báo 2 giờ |
| Ngôn ngữ | Tiếng Việt + Tiếng Anh (String Catalog, theo ngôn ngữ máy) |
| Lưu trữ | SwiftData, đặt trong App Group, đồng bộ iCloud riêng của người dùng (CloudKit private DB) |
| Live Activity | Hướng A — có nút "+1" tương tác (`LiveActivityIntent`) |
| iOS tối thiểu | 17.0 (SwiftData + Live Activity tương tác) |
| Test | Swift Testing (unit), XCTest UI test |
| Môi trường build | Máy dev **không cài Xcode** (thiếu dung lượng). Build, UI test và ảnh chụp simulator chạy trên GitHub Actions (repo public). Bản TestFlight được đẩy lên qua workflow dùng App Store Connect API key |

## 3. Màn hình

### 3.1 Onboarding (3 trang, chỉ hiện lần đầu)
1. Cách đếm: mỗi lần thai máy (đạp, xoay, trườn) bấm một lần; đủ 10 lần là xong.
2. Khi nào nên đếm: từ tuần 28, mỗi ngày vào khoảng thời gian thai hay cử động.
3. Miễn trừ y tế: app không thay thế tư vấn y tế; nếu thấy thai cử động ít đi,
   liên hệ bác sĩ ngay, không chờ kết quả app. Nút "Tôi đã hiểu" để tiếp tục.

### 3.2 Đếm (màn hình chính)
- Nút tròn lớn ở giữa (~60% chiều rộng màn hình) — bấm = +1, rung nhẹ (haptic).
- Vòng tiến độ `n/10` bao quanh nút; đồng hồ thời gian đã trôi qua.
- Khi chưa có session: nút hiển thị "Bắt đầu đếm"; lần bấm đầu tiên vừa tạo
  session vừa tính là cử động thứ 1.
- Nút "Hoàn tác" (xóa lần bấm cuối), nút "Hủy lượt đếm" (có xác nhận).
- Đạt 10: màn hình hoàn thành — "Hoàn thành trong 23 phút".
- Quá 2 giờ chưa đủ 10: banner cảnh báo nhẹ nhàng, khuyên liên hệ bác sĩ /
  cơ sở y tế. Session vẫn tiếp tục đếm được; khi đạt 10 được đánh dấu
  `completed` kèm cờ `exceededThreshold`.

### 3.3 Lịch sử
- Biểu đồ cột (Swift Charts): thời gian đạt 10 lần theo ngày, 14 ngày gần nhất
  (một ngày nhiều lượt → lấy lượt hoàn thành gần nhất). Đường tham chiếu 2 giờ.
- Danh sách lượt đếm nhóm theo ngày: giờ bắt đầu, thời gian, số lần, trạng thái.
- Vuốt để xóa một lượt (có xác nhận).

### 3.4 Cài đặt
- Nhắc hằng ngày: bật/tắt + chọn giờ (mặc định 20:00).
- Ngày dự sinh → hiển thị tuần thai ở màn hình đếm.
- Trang "Thông tin y tế" (nội dung miễn trừ), phiên bản app.
- Trạng thái quyền thông báo / Live Activity, kèm nút mở Settings nếu bị tắt.

## 4. Kiến trúc

### 4.1 Targets
| Target | Nội dung | Phụ thuộc |
|---|---|---|
| `KickCore` (Swift package cục bộ) | Logic thuần: `SessionEngine`, `SessionRepository` (protocol), tóm tắt lịch sử, scheduler thông báo, `KickCoordinator`. Test được trên máy không có Xcode | Foundation, Observation, UserNotifications |
| `KickData` (Swift package cục bộ) | Model SwiftData, `KickPersistence`, `KickStore: SessionRepository`. Chỉ build/test trên CI | KickCore, SwiftData |
| `Shared/` (biên dịch vào App + Widgets) | `KickActivityAttributes`, `AddKickIntent`, `L10n`, String Catalog | ActivityKit, AppIntents |
| `KickCounter` (app) | Giao diện SwiftUI, `SystemLiveActivityManager` | KickCore, KickData |
| `KickCounterWidgets` (extension) | Giao diện Live Activity (màn hình khóa + Dynamic Island) | KickCore |

App và extension cùng thuộc App Group `group.<bundle-prefix>.kickcounter`.

### 4.2 Model (SwiftData, tương thích CloudKit)
Mọi thuộc tính có giá trị mặc định hoặc optional; quan hệ optional; không dùng
`@Attribute(.unique)`.

```swift
@Model final class KickSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?            // set khi completed/cancelled
    var targetCount: Int = 10
    var statusRaw: String = "active"   // active | completed | cancelled
    var exceededThreshold: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Kick.session)
    var kicks: [Kick]? = []
}

@Model final class Kick {
    var timestamp: Date = Date()
    var session: KickSession?
}
```

Cài đặt (giờ nhắc, ngày dự sinh, đã xem onboarding) lưu trong `UserDefaults`
của App Group — không cần đồng bộ.

### 4.3 `SessionEngine` (logic thuần, không phụ thuộc đồng hồ thật)
Nhận trạng thái hiện tại + `now: Date`, trả về trạng thái mới / kết quả:
- `addKick(at:)` → `.added(count)`, `.completed(duration)`, hoặc
  `.ignoredDebounce` nếu cách lần trước < 0,5 giây.
- `undoLastKick()` → không có tác dụng nếu chưa có kick; không hoàn tác được
  sau khi session đã `completed`.
- `isOverdue(now:)` → `now - startedAt >= 2h` và chưa completed.
- Hằng số: `target = 10`, `overdueThreshold = 7200s`, `debounce = 0.5s`.

### 4.4 `KickStore`
Bao quanh `ModelContext`: `activeSession()`, `startSession(now:)`,
`addKick(now:)`, `undo()`, `cancel()`, `sessions(since:)`, `delete(_:)`.
Bất biến: **tối đa một session `active`**. Khi khởi động, nếu có nhiều hơn một
(do đồng bộ iCloud giữa hai máy), giữ session mới nhất, đánh dấu các session
còn lại `cancelled`.

### 4.5 Luồng Live Activity
1. Bắt đầu session → `LiveActivityController.start(session)` với
   `KickActivityAttributes(startedAt:)` và `ContentState(count: 1, isCompleted: false)`.
2. Mẹ bấm "+1" trên màn hình khóa → `AddKickIntent: LiveActivityIntent`.
   iOS chạy `perform()` **trong tiến trình app chính** → `KickStore.addKick`
   → `Activity.update(ContentState)`. Chỉ app ghi SwiftData — không có tranh
   chấp ghi giữa hai tiến trình.
3. Đồng hồ dùng `Text(timerInterval:)`, tự chạy, không cần cập nhật định kỳ.
4. Đạt 10 → cập nhật trạng thái hoàn thành rồi `end(dismissalPolicy: .after(+15 phút))`.
5. Hủy session trong app → kết thúc Live Activity ngay.
6. Mở app → đồng bộ lại: nếu session active mà không có activity (và quyền
   cho phép) → tạo lại; nếu có activity mà không có session → kết thúc.

### 4.6 Thông báo
- **Nhắc hằng ngày:** `UNCalendarNotificationTrigger` lặp, id cố định
  `daily-reminder`; đổi giờ = thay thế.
- **Cảnh báo quá 2 giờ:** khi bắt đầu session, lên lịch thông báo tại
  `startedAt + 2h` với id `overdue-<sessionId>`; hủy khi session completed
  hoặc cancelled.
- Xin quyền thông báo khi mẹ bật nhắc lần đầu hoặc lần đầu bắt đầu đếm —
  không xin ngay khi mở app.

## 5. Xử lý lỗi & trường hợp biên

| Tình huống | Hành vi |
|---|---|
| Từ chối quyền thông báo | App vẫn hoạt động; Cài đặt hiện nhắc + nút mở Settings; cảnh báo 2h vẫn hiện dạng banner trong app |
| Tắt Live Activity trong Settings | Đếm trong app bình thường; không tạo activity |
| Không đăng nhập iCloud | SwiftData chạy cục bộ, không báo lỗi |
| Mở `ModelContainer` thất bại | Màn hình lỗi thân thiện + log `os.Logger`; không crash |
| Live Activity hết hạn (8h) | Session vẫn còn trong app |
| App bị kill khi đang đếm | Session khôi phục từ SwiftData khi mở lại |
| Bấm đúp nhầm | Debounce 0,5s trong `SessionEngine` |

## 6. Trợ năng & giao diện
- Dynamic Type toàn bộ; nút đếm có nhãn VoiceOver ("Ghi nhận cử động, đã có 3 trên 10").
- Hỗ trợ chế độ tối (mẹ thường đếm buổi tối); màu dịu, không dùng đỏ gắt
  cho cảnh báo.
- Vùng chạm nút chính ≫ 44pt.

## 7. Bản địa hóa
- `Localizable.xcstrings` cho app và extension; ngôn ngữ phát triển: tiếng Anh,
  bản dịch đầy đủ tiếng Việt.
- Định dạng thời gian/ngày dùng `FormatStyle` theo locale.

## 8. Kiểm thử
- **Unit (Swift Testing), KickCore:** `SessionEngine` — đạt 10, hoàn tác, debounce,
  quá 2h, biên đúng 2h, undo sau completed. `KickStore` với `ModelContainer`
  in-memory — tạo/khôi phục session, bất biến một session active, truy vấn 14 ngày.
- **UI test:** onboarding → bắt đầu → bấm 10 lần → thấy màn hoàn thành → thấy
  trong lịch sử.
- **Thủ công trên iPhone thật:** Live Activity, Dynamic Island, nút "+1" từ
  màn hình khóa, thông báo nhắc và cảnh báo 2h.
- **Pre-push hook** (`.githooks/pre-push`): chạy test KickCore ở local, đây là kiểm tra
  duy nhất chạy được khi không có Xcode. KickData, build iOS và UI test do CI GitHub
  Actions chặn. UI test chụp ảnh màn hình (sáng/tối, vi/en) để xác minh trực quan.
- **Thử trên máy thật:** qua TestFlight (workflow `testflight.yml`).

## 9. App Store
- Danh mục: Health & Fitness (Sức khỏe).
- Privacy nutrition label: "Data Not Collected" (dữ liệu chỉ ở máy + iCloud
  riêng của người dùng).
- Miễn trừ y tế trong onboarding, Cài đặt và mô tả App Store.
