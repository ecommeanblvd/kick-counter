# Thiết kế: Giai đoạn 2 — Hành trình thai kỳ (Luna Mom)

- **Ngày:** 2026-10-02
- **Trạng thái:** Đã duyệt hướng thiết kế, chờ review spec
- **Nền:** spec v1 `2026-09-29-fetal-kick-counter-design.md` (đếm cử động thai). Giữ nguyên toàn bộ ràng buộc của v1: iOS 17+, Swift 6, không server, không SDK bên thứ ba, song ngữ vi/en, KickCore không import SwiftData, máy dev không có Xcode (xác minh qua CI).

## 1. Mục tiêu

Biến app từ công cụ đếm cử động thành người bạn đồng hành suốt thai kỳ. Mẹ mở app thấy ngay mình đang ở tuần nào, bé đang phát triển ra sao, tuần này nên chú ý gì và lịch khám sắp tới.

**Tiêu chí thành công:**
- Nhập ngày dự sinh **hoặc** ngày đầu kỳ kinh cuối (LMP) → app hiện đúng tuần + ngày, tam cá nguyệt, số ngày còn lại.
- Xem nội dung bé + mẹ cho mọi tuần 4–42, vuốt qua lại giữa các tuần.
- Thêm lịch hẹn khám thật, được nhắc trước 1 ngày, đánh dấu đã khám; lịch hẹn đồng bộ iCloud như lượt đếm.
- Nội dung y tế được bác sĩ sản khoa duyệt trước khi phát hành App Store.

**Ngoài phạm vi (YAGNI):** chế độ "Mong con" và theo dõi chu kỳ kinh nguyệt (giai đoạn 3, spec riêng), nhật ký cân nặng/huyết áp, chia sẻ với người thân, hình minh họa thai nhi, nội dung tải từ server, đổi tên hiển thị của app.

## 2. Quyết định chính

| Hạng mục | Quyết định |
|---|---|
| Nhập ngày thai | Ngày dự sinh **hoặc** LMP; dự sinh = LMP + 280 ngày |
| Lưu nội dung | File JSON song ngữ đóng gói trong `KickCore` (resource), validate bằng unit test chạy local |
| Nguồn nội dung | Claude soạn dựa trên khuyến nghị phổ biến (WHO, ACOG, NHS, Bộ Y tế VN); bác sĩ sản khoa duyệt; cờ `reviewed` từng tuần |
| Điều hướng | 4 tab: **Thai kỳ** (trang chủ) · Đếm · Lịch sử · Cài đặt |
| Lịch khám | Danh sách mốc gợi ý (từ JSON) + lịch hẹn do mẹ tạo (SwiftData, iCloud) |
| Nhắc lịch hẹn | Thông báo cục bộ lúc 9:00 sáng **ngày hôm trước**; nếu thời điểm đó đã qua thì không đặt |
| Minh họa kích thước bé | Emoji loại quả (không dùng ảnh để tránh bản quyền) |

## 3. Dữ liệu

### 3.1 Hồ sơ thai kỳ (App Group `UserDefaults`, không đồng bộ — như v1)
- Giữ khóa `dueDate` (Double, 0 = chưa đặt) làm **nguồn sự thật** cho mọi tính toán.
- Thêm `pregnancyDateSource` (`"dueDate"` | `"lmp"`, mặc định `"dueDate"`) và `lmpDate` (Double, 0 = chưa đặt).
- Khi mẹ nhập LMP: lưu `lmpDate` và ghi `dueDate = LMP + 280 ngày`. Khi nhập ngày dự sinh: ghi `dueDate`, xóa `lmpDate`.
- Người dùng v1 đã có `dueDate` tiếp tục hoạt động, không cần migrate.

### 3.2 Lịch hẹn khám (SwiftData `KickData`, CloudKit)
```swift
@Model final class Appointment {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var note: String = ""
    var isDone: Bool = false
    var milestoneID: String?   // id mốc gợi ý nếu tạo từ mốc
}
```
Tuân thủ quy tắc CloudKit của v1 (default/optional, không unique). Thêm vào `KickPersistence.schema` (thay đổi schema bổ sung, SwiftData tự migrate nhẹ).

### 3.3 Nội dung theo tuần (`Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`)
```json
{
  "version": 1,
  "sources": ["WHO ...", "ACOG ...", "NHS ...", "Bộ Y tế ..."],
  "weeks": [
    {
      "week": 24,
      "reviewed": false,
      "size": { "emoji": "🌽", "en": "an ear of corn", "vi": "một bắp ngô" },
      "lengthCm": 30.0,
      "weightG": 600,
      "baby": { "en": ["..."], "vi": ["..."] },
      "mom":  { "en": ["..."], "vi": ["..."] },
      "tips": { "en": ["..."], "vi": ["..."] },
      "warnings": { "en": ["..."], "vi": ["..."] }
    }
  ],
  "milestones": [
    {
      "id": "nt-scan",
      "fromWeek": 11, "toWeek": 14,
      "title": { "en": "...", "vi": "Siêu âm đo độ mờ da gáy" },
      "detail": { "en": "...", "vi": "..." },
      "reviewed": false
    }
  ]
}
```
- Đủ tuần **4 → 42**, mỗi tuần có đủ `baby`, `mom`, `tips` (≥ 2 ý mỗi mục) và `warnings` (≥ 1 ý), cả `en` và `vi`.
- `lengthCm` / `weightG` tăng không giảm theo tuần (bỏ trống được cho tuần < 8 → hiển thị "—").
- Mốc khám gợi ý (≈ 8–10): xác nhận thai (6–8), độ mờ da gáy + double test (11–14), triple test (15–18), siêu âm hình thái (18–22), tầm soát tiểu đường thai kỳ (24–28), tiêm phòng uốn ván/ho gà theo hướng dẫn (27–36), siêu âm tăng trưởng (30–32), cấy GBS (35–37), khám hằng tuần từ 37, theo dõi khi quá ngày dự sinh (40+). Nội dung chính xác do bác sĩ duyệt.

## 4. Kiến trúc

### 4.1 KickCore (logic thuần, test local)
| Thành phần | Trách nhiệm |
|---|---|
| `PregnancyTimeline` | Từ `dueDate` + `now`: tuần, ngày, tam cá nguyệt (1: tuần 0–13, 2: 14–27, 3: 28+), ngày còn lại (≥ 0), tiến độ 0…1 trên 280 ngày, cờ `isPastDue`. Tái dùng `GestationalAge` |
| `PregnancyDates` | `dueDate(fromLMP:)` = LMP + 280 ngày (theo lịch, không theo giây) |
| `WeeklyContentLibrary` | Decode JSON từ `Bundle.module`; `content(forWeek:)` kẹp vào 4…42; `milestones`; `upcomingMilestones(atWeek:)`; ngôn ngữ chọn theo `Locale` (vi nếu ngôn ngữ ưu tiên là vi, còn lại en) |
| `AppointmentReminders` | Mở rộng `NotificationScheduler`: `scheduleAppointmentReminder(id:date:title:now:text:)` (id `appointment-<uuid>`, lúc 9:00 ngày trước; bỏ qua nếu đã qua), `cancelAppointmentReminder(id:)` |

Package `KickCore` thêm `resources: [.process("Resources")]`.

### 4.2 KickData
- `Appointment` model + `AppointmentStore: AppointmentRepository` (`@MainActor`): `upcoming(now:)`, `past(now:)`, `add/update/delete/markDone`, mỗi lần ghi `save()` có rollback khi lỗi (như `KickStore`). Store chỉ lưu trữ, không đụng tới thông báo.
- KickCore định nghĩa protocol `AppointmentRepository` (làm việc với value type `AppointmentRecord`) và `AppointmentCoordinator` (`@MainActor @Observable`, cùng mẫu với `KickCoordinator`). Coordinator là nơi **duy nhất** đồng bộ lịch nhắc: thêm/sửa → đặt lại nhắc; xóa/đánh dấu đã khám → hủy nhắc. Test local bằng fake repository.

### 4.3 App (SwiftUI)
- **`PregnancyHomeView`** (tab 1, mặc định):
  - Chưa có ngày → màn mời nhập (nút mở sheet nhập ngày).
  - Thẻ tuần: "Tuần 24 + 3 ngày", tam cá nguyệt, "còn 109 ngày", thanh tiến độ; quá ngày dự sinh → thông điệp riêng khuyên liên hệ bác sĩ.
  - Thẻ bé: emoji + "Bé to bằng một bắp ngô", chiều dài, cân nặng → mở chi tiết tuần.
  - Thẻ lời khuyên tuần này (2 ý đầu) → chi tiết tuần.
  - Thẻ lịch khám sắp tới (lịch hẹn gần nhất, hoặc mốc gợi ý đang tới nếu chưa có lịch hẹn).
  - Từ tuần 28: thẻ "Đếm cử động thai hôm nay" chuyển sang tab Đếm.
- **`WeekDetailView`:** `TabView` dạng trang, tuần 4–42, mở ở tuần hiện tại; các mục Bé · Mẹ · Lời khuyên · **Khi nào cần đi khám ngay** (nổi bật, màu cam như banner quá giờ).
- **`AppointmentsView`:** Sắp tới / Đã qua; thêm/sửa (sheet: ngày giờ, tiêu đề, ghi chú), vuốt xóa, đánh dấu đã khám; mục "Mốc gợi ý" với nút "Thêm vào lịch" (điền sẵn tiêu đề + ngày ước tính đầu khoảng tuần).
- **`PregnancyDateSheet`:** chọn "Ngày dự sinh" hoặc "Ngày đầu kỳ kinh cuối" + DatePicker; dùng ở trang chủ, Cài đặt và onboarding.
- **Onboarding:** thêm trang 4 "Thai kỳ của bạn" với `PregnancyDateSheet` (có nút "Để sau").
- **Cài đặt:** mục Thai kỳ thay toggle ngày dự sinh bằng dòng hiện ngày + nguồn, mở `PregnancyDateSheet`; nút xóa thông tin thai kỳ.
- **Thông tin y tế:** thêm mục "Nguồn tham khảo" (liệt kê `sources`).
- Tab Đếm giữ nguyên; dòng "Tuần X + Y ngày" ở tab Đếm dùng chung `PregnancyTimeline`.

### 4.4 Cờ `reviewed`
- Bản **Release** chỉ hiện nội dung tuần/mốc có `reviewed == true`; tuần chưa duyệt hiện thông điệp "Nội dung tuần này đang được cập nhật".
- Bản **TestFlight/Debug** hiện mọi nội dung, kèm nhãn nhỏ "Nội dung đang chờ bác sĩ duyệt" ở tuần chưa duyệt.
- Phân biệt bằng cờ build `CONTENT_PREVIEW` (Swift compilation condition) bật cho cấu hình dùng trên TestFlight; lý do chọn: TestFlight dùng cấu hình Release, nên cần cờ riêng do workflow truyền vào (`testflight.yml` truyền `CONTENT_PREVIEW`, workflow phát hành App Store sau này không truyền).

## 5. Sửa lỗi kèm theo: số phiên bản / build
`project.yml` hiện không khai báo `CFBundleShortVersionString` / `CFBundleVersion` → XcodeGen dùng Info.plist mặc định ghi cứng `1.0` / `1`, nên `CURRENT_PROJECT_VERSION=$BUILD_NUMBER` của `release.sh` không có tác dụng (App Store Connect hiện build "1"; lần tải tiếp sẽ bị từ chối do trùng). Sửa: thêm vào `info.properties` của **cả app và widget**: `CFBundleShortVersionString: $(MARKETING_VERSION)`, `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`. Đây là task đầu tiên của kế hoạch.

## 6. Xử lý lỗi & trường hợp biên
| Tình huống | Hành vi |
|---|---|
| Chưa nhập ngày | Tab Thai kỳ hiện màn mời nhập; tab Đếm hoạt động như v1 |
| Ngày không hợp lý (tuần < 0 hoặc > 44) | `PregnancyTimeline` trả `nil` → hiện thông báo kiểm tra lại ngày + nút sửa |
| Quá ngày dự sinh | Hiện "Đã qua ngày dự sinh X ngày", khuyên liên hệ bác sĩ; nội dung tuần 41–42 |
| Lỗi đọc JSON | Không crash; log `os.Logger`; thẻ nội dung ẩn, phần tính tuần vẫn hoạt động (unit test đảm bảo file hợp lệ) |
| Từ chối quyền thông báo | Vẫn lưu lịch hẹn; hiện dòng nhắc bật thông báo trong màn Lịch khám |
| Lịch hẹn trong quá khứ | Cho phép (ghi lại lịch đã khám); không đặt nhắc |
| Lưu lịch hẹn lỗi | Rollback + alert "Không lưu được" (dùng chuỗi `error.save` có sẵn) |

## 7. Bản địa hóa & trợ năng
- Chuỗi giao diện mới qua `L10n` + `Localizable.xcstrings` (vi + en đầy đủ). Nội dung y tế nằm trong JSON (không vào String Catalog).
- Dynamic Type cho mọi thẻ (dùng font ngữ nghĩa, không cỡ cố định); thẻ có nhãn VoiceOver gộp; emoji có `accessibilityLabel` bằng tên loại quả.
- Chế độ tối dùng màu ngữ nghĩa + AccentColor như v1.

## 8. Kiểm thử
- **Unit (KickCore, local):** `PregnancyTimeline` (biên tuần 13/14, 27/28, ngày dự sinh hôm nay, quá hạn, ngày không hợp lý), `PregnancyDates` (LMP + 280, qua năm nhuận), **validate nội dung** (đủ tuần 4–42, đủ en/vi cho mọi mục, số ý tối thiểu, `lengthCm`/`weightG` không giảm, mốc gợi ý có khoảng tuần hợp lệ và không trùng id), lookup kẹp tuần, chọn ngôn ngữ, nhắc lịch hẹn (giờ 9:00 hôm trước, bỏ qua khi đã qua, hủy theo id).
- **KickData (CI):** `AppointmentStore` CRUD, upcoming/past, rollback.
- **UI test (CI):** nhập ngày bằng LMP → tab Thai kỳ hiện đúng tuần; thêm lịch hẹn → xuất hiện trong "Sắp tới".
- **Ảnh chụp (CI):** trang chủ Thai kỳ (tuần 12, 24, 38), chi tiết tuần, lịch khám, màn chưa nhập ngày — sáng/tối, vi/en. Ngày cố định qua launch argument `-fixedNow <ISO8601>` (chỉ khi `-uiTesting`).

## 9. Phát hành
- Bác sĩ duyệt `pregnancy-content.json`, chuyển `reviewed: true` từng tuần/mốc trước khi gửi App Store.
- Cập nhật CloudKit schema (thêm `Appointment`) cùng lúc với bước deploy schema đang chờ của v1.
- Ghi chú phát hành và ảnh chụp App Store mới cho tab Thai kỳ.
