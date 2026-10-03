# Checklist trước khi phát hành

## Cấu hình (một lần)
- [ ] Task 0 đã xong: identifiers, app record, API key (Admin), secrets trên GitHub.
- [ ] CloudKit Console (icloud.developer.apple.com) — bản TestFlight/App Store dùng CloudKit
      **Production**, môi trường này không tự tạo record type; không có Xcode trên máy này nên
      không có bản build ký development để tạo record type trực tiếp. Cách làm:
      - Trên một Mac có Xcode: chạy một bản build ký development trên thiết bị thật, tạo một
        lượt đếm cử động (kick session) và một lịch hẹn (appointment) để SwiftData tự sinh đúng các
        record type (`CD_KickSession`, `CD_Kick`, `CD_Appointment`) trong Development, kiểm tra trong
        CloudKit Console, rồi **Deploy Schema Changes** từ Development lên Production.
      - **Không** tự tạo record type bằng tay: cách NSPersistentCloudKitContainer/SwiftData lưu quan
        hệ và các field hệ thống (vd. `CD_entityName`) dễ bị đoán sai, mà field đã deploy lên
        Production thì không xóa hay đổi kiểu được — một field sai sẽ làm hỏng đồng bộ vĩnh viễn.
        Nếu buộc phải làm tay, đối chiếu tài liệu Apple "Reading CloudKit Records for Core Data"
        trước khi deploy.
      Cho tới khi schema được deploy lên Production, bộ test thủ công đồng bộ hai máy (v1 và
      Giai đoạn 2, bên dưới) **sẽ thất bại như dự kiến**.
- [ ] Icon 1024×1024 trong `App/Assets.xcassets/AppIcon.appiconset` (không trong suốt, không bo góc) —
      hiện là icon tạm (trái tim trắng trên nền san hô), cần thay bằng icon thiết kế thật trước khi phát hành App Store.

## Kiểm thử thủ công trên iPhone thật qua TestFlight (ngôn ngữ vi và en)
- [ ] Onboarding hiện lần đầu, không hiện lại sau khi đồng ý.
- [ ] Chạm lần đầu → hỏi quyền thông báo; Live Activity xuất hiện trên màn hình khóa.
- [ ] Khóa máy, bấm "+1" trên màn hình khóa 3 lần → số đếm tăng; mở app thấy đúng số.
- [ ] Dynamic Island (iPhone 14 Pro trở lên): compact hiện "n/10"; nhấn giữ hiện nút "+1".
- [ ] Đủ 10 lần từ màn hình khóa → Live Activity hiện "Xong!" và tự biến mất sau ~15 phút; mở app thấy lượt trong Lịch sử.
- [ ] Bắt đầu một lượt và để quá 2 giờ → nhận thông báo cảnh báo; banner hiện trong app; Live Activity hiện dòng cảnh báo.
- [ ] Nhắc hằng ngày: đặt giờ sau 2 phút → nhận thông báo.
- [ ] Từ chối quyền thông báo → app vẫn đếm được; Cài đặt hiện mục Quyền.
- [ ] Tắt Live Activities trong Settings → app vẫn đếm; Cài đặt hiện dòng nhắc.
- [ ] Buộc tắt app khi đang đếm → mở lại thấy lượt đang đếm còn nguyên.
- [ ] Hai máy cùng Apple ID: lượt hoàn thành trên máy A hiện trong Lịch sử máy B.
      (Dự kiến thất bại cho tới khi schema CloudKit được deploy lên Production — xem mục "Cấu hình".)
- [ ] Bắt đầu một lượt rồi bỏ đó; mở lại app sau hơn 8 giờ → không có Live Activity mới; sau hơn 12 giờ → lượt cũ hiện "Đã hủy", bấm tiếp bắt đầu lượt mới.
- [ ] Đủ 10 lần rồi mở app ngay (trong 15 phút) → Live Activity "Xong!" vẫn còn trên màn hình khóa.
- [ ] Chế độ tối, Dynamic Type lớn nhất, VoiceOver đọc "Ghi nhận cử động, đã có n trên 10 cử động".

## App Store Connect
- [ ] Danh mục: Health & Fitness.
- [ ] App Privacy: "Data Not Collected".
- [ ] Mô tả có câu miễn trừ y tế (dùng nội dung `medical.body`).
- [ ] Ảnh chụp màn hình vi + en: lấy từ `ci-artifacts/screenshots/` hoặc chụp trên máy thật.
- [ ] Ghi chú cho reviewer: cách thử Live Activity (chạm một lần trong app rồi khóa máy).

## Giai đoạn 2 — Hành trình thai kỳ

### Trước khi gửi App Store
- [ ] Bác sĩ sản khoa đã duyệt `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`;
      mỗi tuần/mốc đã duyệt được đổi `reviewed` thành `true` (commit riêng, ghi tên người duyệt và ngày duyệt trong commit message).
      `scripts/test-core.sh` xanh sau khi đổi.
- [ ] Checklist chi tiết cho bác sĩ (14 điểm cần quyết định y khoa, cách duyệt nội dung): [`docs/content-review-for-doctor.md`](content-review-for-doctor.md).
- [ ] Không còn mục chưa duyệt — lệnh sau in ra `[] []`:
      `python3 -c "import json;d=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'));print([w['week'] for w in d['weeks'] if not w['reviewed']],[m['id'] for m in d['milestones'] if not m['reviewed']])"`
- [ ] Bản build gửi App Store Review **không** bật `CONTENT_PREVIEW` — kiểm tra bằng
      `LunaContentPreview = NO` trong Info.plist của bản build / trong App Store Connect build
      metadata. Chạy TestFlight với `content_preview=true` (workflow_dispatch input, mặc định
      `false`) **chỉ** để thử nội bộ/cho bác sĩ: `gh workflow run testflight.yml -f content_preview=true`.
      Bản gửi lên App Store Review phải được tải lên với `content_preview=false` (giá trị mặc định).
- [ ] CloudKit Console: record type `CD_Appointment` có trong Development (sinh tự động theo cách
      ở mục "Cấu hình" phía trên, sau khi một lịch hẹn đã được lưu từ bản build ký development), rồi
      **Deploy Schema Changes** lên Production — làm cùng lần với bước deploy schema của v1.
- [ ] Ảnh chụp App Store mới cho tab Thai kỳ (vi + en): `ci-artifacts/screenshots/pregnancy-home-24-*`, `week-24-*`, `appointments-*`.
- [ ] Ghi chú phát hành: tab Thai kỳ; nội dung bé + mẹ tuần 4–42; lịch khám có nhắc trước 1 ngày; nhập ngày dự sinh hoặc ngày đầu kỳ kinh cuối.

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en)
- [ ] TestFlight hiện build number bằng số run của workflow TestFlight (không còn "1").
- [ ] Chạy bản TestFlight này với `content_preview=true`: tuần chưa duyệt hiện nhãn "Nội dung đang
      chờ bác sĩ duyệt" (chứng tỏ `CONTENT_PREVIEW` có hiệu lực trên bản Release) và
      `LunaContentPreview = YES` trong Info.plist của bản build.
- [ ] Cài mới: onboarding bước 4 nhập kỳ kinh cuối → tab Thai kỳ hiện đúng tuần + ngày, tam cá nguyệt, số ngày còn lại; "Để sau" → màn mời nhập ngày.
- [ ] Người dùng v1 đã có ngày dự sinh: cập nhật app → tab Thai kỳ hiện đúng tuần, không phải nhập lại.
- [ ] Cài đặt → Thai kỳ: đổi giữa ngày dự sinh/kỳ kinh cuối; "Xóa thông tin thai kỳ" → tab Thai kỳ về màn mời nhập, tab Đếm mất dòng tuần.
- [ ] Chi tiết tuần: vuốt trái/phải từ tuần 4 đến 42; mục "Khi nào cần đi khám ngay" màu cam.
- [ ] Thêm lịch hẹn cho ngày kia → 9:00 sáng mai nhận thông báo "Ngày mai mẹ có lịch khám" kèm tên lịch hẹn.
- [ ] Lịch hẹn trong quá khứ lưu được, nằm trong "Đã qua", không có thông báo.
- [ ] Đánh dấu đã khám hoặc xóa một lịch hẹn có nhắc → không còn nhận thông báo của nó.
- [ ] Từ chối quyền thông báo → vẫn lưu lịch hẹn; màn Lịch khám hiện dòng nhắc bật thông báo.
- [ ] Hai máy cùng Apple ID: lịch hẹn thêm trên máy A hiện trên máy B sau khi mở app, và máy B cũng nhắc.
      (Dự kiến thất bại cho tới khi schema CloudKit được deploy lên Production — xem mục "Cấu hình".)
- [ ] Từ tuần 28: thẻ "Đếm cử động thai hôm nay" chuyển sang tab Đếm.
- [ ] Dynamic Type lớn nhất: thẻ không bị cắt chữ; VoiceOver đọc mỗi thẻ thành một câu (tên loại quả chỉ đọc một lần, qua dòng tiêu đề; emoji được ẩn).
- [ ] Thông tin y tế → "Nguồn tham khảo" liệt kê đủ nguồn.
