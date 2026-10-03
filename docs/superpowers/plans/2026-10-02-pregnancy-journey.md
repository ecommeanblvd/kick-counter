# Hành trình thai kỳ (Giai đoạn 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. For UI tasks (11–13), also apply the `ui-ux-pro-max` skill for visual polish — but do not change behaviour, accessibility identifiers, or strings defined here.

**Goal:** Biến Kick Counter thành người bạn đồng hành suốt thai kỳ: tab **Thai kỳ** (mặc định) cho biết tuần + ngày, tam cá nguyệt, số ngày còn lại, bé phát triển ra sao (nội dung song ngữ tuần 4–42), lịch khám (lịch hẹn của mẹ + mốc gợi ý) có nhắc 9:00 ngày hôm trước và đồng bộ iCloud.

**Architecture:** Logic mới nằm trong `KickCore` (Swift thuần, test local): `PregnancyTimeline`/`PregnancyDates` (tính tuần), `PregnancyProfile`/`PregnancyDateInput` (lưu và nhập ngày), mô hình + kiểm định nội dung (`WeeklyContentLibrary`, `ContentValidator`) đọc `pregnancy-content.json` qua `Bundle.module`, nhắc lịch hẹn (mở rộng `NotificationScheduler`), protocol `AppointmentRepository` và `AppointmentCoordinator` (nơi **duy nhất** đồng bộ nhắc lịch hẹn). `KickData` thêm model SwiftData `Appointment` + `AppointmentStore` (chỉ lưu trữ). App SwiftUI chỉ là lớp giao diện mỏng: 4 tab Thai kỳ · Đếm · Lịch sử · Cài đặt.

**Máy dev không có Xcode.** Chỉ `KickCore` chạy được local qua `scripts/test-core.sh`. `KickData`, app, UI test và ảnh chụp chỉ được xác minh trên GitHub Actions: commit → `git push` → `scripts/ci-wait.sh`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (+ CloudKit private DB), UserNotifications, Swift Testing, XCTest (UI), SwiftPM resources, XcodeGen, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-02-pregnancy-journey-design.md` (yêu cầu). Plan v1 tham khảo: `docs/superpowers/plans/2026-09-29-fetal-kick-counter.md`.

## Global Constraints

- iOS deployment target `17.0`; package platforms `.iOS(.v17), .macOS(.v14)` (macOS chỉ để chạy `swift test`); Swift language mode 6.
- Làm việc trên nhánh `feat/phase2-pregnancy-journey`. Mọi commit message kết thúc bằng một dòng trống rồi `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (dùng `git commit -F - <<'MSG' … MSG` như trong từng task).
- **Máy dev không có Xcode.** Local chỉ chạy được `scripts/test-core.sh` (thêm đường dẫn framework của Command Line Tools; cũng là nội dung pre-push hook). `KickData`, build app, UI test, ảnh chụp: chỉ trên CI qua `git push` + `scripts/ci-wait.sh` (ảnh tải về `ci-artifacts/screenshots/`).
- **`KickCore` không được import SwiftData.** Mọi `@Model` nằm trong `KickData`.
- Model SwiftData phải tương thích CloudKit: mọi thuộc tính có default hoặc optional, quan hệ optional, **không** dùng `@Attribute(.unique)`. `Appointment` được thêm vào `KickPersistence.schema` (thay đổi bổ sung, migrate nhẹ).
- Mọi chuỗi giao diện đi qua `L10n` (`Shared/L10n.swift`) và có trong `Shared/Localizable.xcstrings` với đủ `en` + `vi` (thêm bằng `scripts/add-strings.py`, tạo ở Task 10). **Nội dung y tế theo tuần nằm trong JSON** (`Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`), không vào String Catalog.
- Resource của SwiftPM trong `KickCore`: target dùng `resources: [.process("Resources")]` và đọc bằng `Bundle.module`; test target dùng `resources: [.copy("Fixtures")]`. Cả hai phải chạy được bằng `scripts/test-core.sh` (Command Line Tools) — đã kiểm chứng trên máy dev với package thử.
- `SettingsKey.dueDate` (Double, `timeIntervalSince1970`, 0 = chưa đặt) là **nguồn sự thật** cho mọi tính toán. Khóa mới: `pregnancyDateSource` (`"dueDate"` | `"lmp"`, mặc định `"dueDate"`), `lmpDate` (Double, 0 = chưa đặt). Người dùng v1 không cần migrate.
- Thai kỳ dài `280` ngày; ngày dự sinh = LMP + 280 ngày **theo lịch** (không theo giây). Tam cá nguyệt: 1 = tuần 0–13, 2 = tuần 14–27, 3 = tuần 28+. `PregnancyTimeline` hợp lệ cho tuần 0…44 (0…314 ngày), ngoài khoảng đó trả `nil`. Nội dung theo tuần: `4…42`, tra cứu kẹp vào khoảng này.
- Nhắc lịch hẹn: thông báo cục bộ id `appointment-<UUID>`, lúc **9:00 ngày hôm trước**; nếu thời điểm đó đã qua thì không đặt. `AppointmentCoordinator` là nơi duy nhất đặt/hủy nhắc lịch hẹn; `AppointmentStore` chỉ lưu trữ.
- `KickCoordinator` giữ nguyên. Thay đổi duy nhất ở tab Đếm: dòng "Tuần X + Y ngày" dùng `PregnancyTimeline`.
- Launch arguments cho UI test (chỉ có hiệu lực khi có `-uiTesting`): `-fixedNow <ISO8601>` (đồng hồ cố định cho màn thai kỳ/lịch khám) và `-seedDueDate <ISO8601>` (ghi sẵn ngày dự sinh). `KickCoordinator` **không bao giờ** dùng đồng hồ cố định (đồng hồ đứng yên sẽ debounce mọi cú chạm sau cú đầu). Giữ các argument v1: `-uiTesting`, `-skipOnboarding`, `-forceDarkMode`.
- Cờ `reviewed`: build có `DEBUG` hoặc `CONTENT_PREVIEW` hiện mọi nội dung (kèm nhãn "đang chờ bác sĩ duyệt" ở mục chưa duyệt); build Release không có `CONTENT_PREVIEW` (App Store) chỉ hiện mục `reviewed == true`. `testflight.yml` truyền `CONTENT_PREVIEW=1` cho `scripts/release.sh`.
- Mọi `reviewed` trong `pregnancy-content.json` là `false` cho tới khi bác sĩ sản khoa duyệt.
- Minh họa kích thước bé bằng emoji (không dùng ảnh). Không server, không SDK bên thứ ba, không thu thập dữ liệu.
- Dynamic Type: chỉ dùng font ngữ nghĩa (emoji dùng `@ScaledMetric`); thẻ gộp VoiceOver bằng `.accessibilityElement(children: .combine)`; chế độ tối dùng màu ngữ nghĩa + AccentColor; màu cảnh báo cam giống `OverdueBanner` (`Color.orange`, nền `Color.orange.opacity(0.12)`).
- Thứ tự tab: 0 Thai kỳ (mặc định) · 1 Đếm · 2 Lịch sử · 3 Cài đặt (từ Task 12).
- Accessibility identifiers cố định (ngoài các id v1 `kickButton`, `undoButton`, `cancelSessionButton`, `completionTitle`, `completionDone`, `onboardingNext`, `onboardingAgree`, `sessionRow`): `onboardingSaveDate`, `onboardingSkipDate`, `pregnancyDateSourcePicker`, `pregnancyDatePicker`, `pregnancyEstimatedDue`, `pregnancyDateSave`, `settingsPregnancyDates`, `settingsPregnancyClear`, `settingsMedicalInfo`, `medicalSources`, `pregnancyAddDateButton`, `pregnancyEditDateButton`, `pregnancyFixDateButton`, `weekProgressCard`, `babySizeCard`, `weekTipsCard`, `nextAppointmentCard`, `kickCountCard`, `pendingReviewBadge`, `weekWarnings`, `addAppointmentButton`, `appointmentRow`, `appointmentTitleField`, `appointmentDatePicker`, `appointmentSaveButton`, `appointmentMarkDoneButton`, `addMilestoneButton`, `upcomingHeader`, `milestonesHeader`, `pastHeader`.

## Quy trình xác minh

- **Local** (mọi task có code `KickCore`): `scripts/test-core.sh` (có thể thêm `--filter <TênSuite>`). Đây cũng là pre-push hook.
- **CI** (điều kiện hoàn thành của **mọi** task): commit, `git push`, rồi `scripts/ci-wait.sh`. Script chờ run CI của HEAD, in log lỗi nếu fail và tải artifact về `ci-artifacts/` (ảnh chụp ở `ci-artifacts/screenshots/`, tên file bắt đầu bằng tên ảnh trong test, ví dụ `pregnancy-home-24-vi-light_0_<UUID>.png`).
- Task có danh sách kiểm tra trực quan: mở từng PNG liên quan bằng **Read tool** và đối chiếu với checklist của task. Sai một mục là chưa xong.
- CI fail → dùng `superpowers:systematic-debugging`, sửa, commit, push lại. Không đánh dấu task hoàn thành khi CI còn đỏ. Không push khi `scripts/test-core.sh` local còn đỏ.

## File Structure

```
kick-counter/
├── project.yml                                  # T1: CFBundleShortVersionString/CFBundleVersion cho app + widget
├── scripts/
│   ├── check-bundle-versions.sh                 # T1 (mới): kiểm tra Info.plist đã build
│   ├── ci.sh                                    # T1: -derivedDataPath, build number = run number, gọi check
│   ├── add-strings.py                           # T10 (mới): thêm/xóa khóa trong Localizable.xcstrings
│   └── release.sh                               # T10: CONTENT_PREVIEW=1 → SWIFT_ACTIVE_COMPILATION_CONDITIONS
├── .github/workflows/testflight.yml             # T10: truyền CONTENT_PREVIEW=1
├── Packages/KickCore/
│   ├── Package.swift                            # T4: test resources Fixtures; T5: resources Resources
│   ├── Sources/KickCore/
│   │   ├── GestationalAge.swift                 # T2: tách elapsedDays (dùng chung)
│   │   ├── PregnancyTimeline.swift              # T2 (mới): Trimester, PregnancyTimeline
│   │   ├── PregnancyDates.swift                 # T2 (mới)
│   │   ├── Settings.swift                       # T3: khóa pregnancyDateSource, lmpDate
│   │   ├── PregnancyProfile.swift               # T3 (mới): PregnancyDateSource, PregnancyProfile
│   │   ├── PregnancyDateInput.swift             # T3 (mới): khoảng chọn, mặc định, đổi qua lại
│   │   ├── UITestLaunchOptions.swift            # T3 (mới): -fixedNow, -seedDueDate
│   │   ├── PregnancyContent.swift               # T4 (mới): model nội dung + ContentLanguage
│   │   ├── WeeklyContentLibrary.swift           # T4 (mới): tra cứu, hiển thị theo cờ reviewed
│   │   ├── ContentValidator.swift               # T4 (mới): kiểm định nội dung
│   │   ├── WeeklyContentLibrary+Bundle.swift    # T5 (mới): Bundle.module
│   │   ├── Resources/pregnancy-content.json     # T5 (mới, soạn nội dung)
│   │   ├── NotificationScheduler.swift          # T6: center → internal, isDenied()
│   │   ├── AppointmentReminders.swift           # T6 (mới)
│   │   ├── Appointments.swift                   # T7 (mới): AppointmentRecord, AppointmentRepository, AppointmentRules
│   │   ├── AppointmentPrefill.swift             # T7 (mới)
│   │   └── AppointmentCoordinator.swift         # T8 (mới)
│   └── Tests/KickCoreTests/
│       ├── Fixtures/content-fixture.json        # T4 (mới)
│       ├── TestSupport.swift                    # T4: fixtureContent; T8: FakeAppointmentRepository, gate add
│       └── <Tên>Tests.swift                     # một file test cho mỗi thành phần
├── Packages/KickData/
│   ├── Sources/KickData/{Models,KickPersistence,AppointmentStore}.swift   # T9
│   └── Tests/KickDataTests/{TestSupport,AppointmentStoreTests}.swift      # T9
├── Shared/{L10n.swift, Localizable.xcstrings}   # T10–T13: chuỗi mới
├── App/
│   ├── AppClock.swift                           # T10 (mới)
│   ├── ContentEnvironment.swift                 # T10 (mới): \.contentLibrary, BuildFlags
│   ├── AppEnvironment.swift, KickCounterApp.swift, RootView.swift   # T10, T12
│   ├── Formatting.swift                         # T12: chiều dài, cân nặng
│   ├── Counter/CounterView.swift                # T10: dòng tuần dùng PregnancyTimeline
│   ├── Pregnancy/                               # T11: PregnancyDateForm, PregnancyDateSheet
│   │                                            # T12: PregnancyHomeView, PregnancyCards, WeekDetailView
│   ├── Appointments/                            # T13: AppointmentsView, AppointmentEditorSheet, AppointmentRows
│   ├── Onboarding/OnboardingView.swift          # T11: bước "Thai kỳ của bạn"
│   └── Settings/{SettingsView,MedicalInfoView}.swift                 # T11
└── UITests/
    ├── UITestSupport.swift                      # T10 (mới): launchPinned, UITestDates, attachScreenshot; T12: AppTab/openTab
    ├── PregnancyUITests.swift                   # T10, T12, T13: luồng chức năng
    ├── PregnancyScreenshotTests.swift           # T12, T13: ảnh chụp thai kỳ/lịch khám
    ├── ScreenshotTests.swift, KickCounterUITests.swift               # T11, T12: cập nhật onboarding + tab
```

---

### Task 1: Sửa số phiên bản / build (spec §5)

`project.yml` không khai báo `CFBundleShortVersionString`/`CFBundleVersion`, nên Info.plist do XcodeGen sinh ghi cứng `1.0`/`1` và `CURRENT_PROJECT_VERSION=$BUILD_NUMBER` của `release.sh` không có tác dụng. Task này sửa `project.yml` cho cả app và widget, và thêm một kiểm tra trên CI đọc Info.plist **đã build** bằng `PlistBuddy`, với build number của CI là số run (khác `1`), nên lỗi này không thể quay lại mà không làm CI đỏ.

**Files:**
- Create: `scripts/check-bundle-versions.sh`
- Modify: `scripts/ci.sh:21-28` (lệnh `xcodebuild` + bước kiểm tra), `project.yml:33-40` (info app), `project.yml:68-71` (info widget)

**Interfaces:**
- Consumes: không.
- Produces: `scripts/check-bundle-versions.sh <path/to/KickCounter.app> <CFBundleVersion mong đợi> <CFBundleShortVersionString mong đợi>` — exit 0 khi cả `KickCounter.app/Info.plist` và `KickCounter.app/PlugIns/KickCounterWidgets.appex/Info.plist` khớp, exit 1 (in từng chỗ lệch ra stderr) nếu không. `scripts/ci.sh` build với `-derivedDataPath build/DerivedData` và `CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-4242}"`.

- [ ] **Step 1: Viết "test" cho script kiểm tra (chạy local, không cần Xcode)**

Tạo một `.app` giả với Info.plist ghi cứng `1`/`1.0` — đúng tình trạng lỗi hiện tại:

```bash
TMP="$(mktemp -d)"; APP="$TMP/KickCounter.app"
mkdir -p "$APP/PlugIns/KickCounterWidgets.appex"
for P in "$APP/Info.plist" "$APP/PlugIns/KickCounterWidgets.appex/Info.plist"; do
  /usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 1' -c 'Add :CFBundleShortVersionString string 1.0' "$P" >/dev/null
done
scripts/check-bundle-versions.sh "$APP" 4242 1.0.0; echo "exit=$?"
```

- [ ] **Step 2: Chạy, xác nhận fail**

Expected: `scripts/check-bundle-versions.sh: No such file or directory` và `exit=127`.

- [ ] **Step 3: Viết script**

`scripts/check-bundle-versions.sh`:
```bash
#!/usr/bin/env bash
# Fails unless the built app and its widget extension carry the expected
# version numbers (they must follow MARKETING_VERSION / CURRENT_PROJECT_VERSION).
# Usage: scripts/check-bundle-versions.sh <path/to/KickCounter.app> <expected CFBundleVersion> <expected CFBundleShortVersionString>
set -euo pipefail
APP="$1"
EXPECTED_BUILD="$2"
EXPECTED_VERSION="$3"
PLIST_BUDDY=/usr/libexec/PlistBuddy
STATUS=0
for PLIST in "$APP/Info.plist" "$APP/PlugIns/KickCounterWidgets.appex/Info.plist"; do
  if [[ ! -f "$PLIST" ]]; then
    echo "Missing $PLIST" >&2
    STATUS=1
    continue
  fi
  BUILD="$("$PLIST_BUDDY" -c 'Print :CFBundleVersion' "$PLIST" 2>/dev/null || echo '<missing>')"
  VERSION="$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || echo '<missing>')"
  if [[ "$BUILD" != "$EXPECTED_BUILD" || "$VERSION" != "$EXPECTED_VERSION" ]]; then
    echo "Version mismatch in $PLIST: CFBundleVersion=$BUILD (expected $EXPECTED_BUILD), CFBundleShortVersionString=$VERSION (expected $EXPECTED_VERSION)" >&2
    STATUS=1
  else
    echo "OK $PLIST: $VERSION ($BUILD)"
  fi
done
exit $STATUS
```
Run: `chmod +x scripts/check-bundle-versions.sh`

- [ ] **Step 4: Chạy lại Step 1, xác nhận phát hiện lỗi; rồi xác nhận trường hợp đúng**

Chạy lại khối lệnh Step 1. Expected: hai dòng `Version mismatch in …: CFBundleVersion=1 (expected 4242), CFBundleShortVersionString=1.0 (expected 1.0.0)` và `exit=1`.

Sau đó:
```bash
for P in "$APP/Info.plist" "$APP/PlugIns/KickCounterWidgets.appex/Info.plist"; do
  /usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 4242' -c 'Set :CFBundleShortVersionString 1.0.0' "$P"
done
scripts/check-bundle-versions.sh "$APP" 4242 1.0.0; echo "exit=$?"
rm -f "$APP/PlugIns/KickCounterWidgets.appex/Info.plist"
scripts/check-bundle-versions.sh "$APP" 4242 1.0.0; echo "exit=$?"
rm -rf "$TMP"
```
Expected: lần 1 in hai dòng `OK …: 1.0.0 (4242)` và `exit=0`; lần 2 in `Missing …/KickCounterWidgets.appex/Info.plist` và `exit=1`.

- [ ] **Step 5: Gọi kiểm tra từ `scripts/ci.sh`**

Trong `scripts/ci.sh`, thay khối:
```bash
XCODE_ACTION="test"
rm -rf build && mkdir -p build/screenshots
echo "==> xcodebuild $XCODE_ACTION on simulator $DEVICE_ID"
STATUS=0
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination "id=$DEVICE_ID" \
  -resultBundlePath build/KickCounter.xcresult \
  CODE_SIGNING_ALLOWED=NO -quiet "$XCODE_ACTION" || STATUS=$?
```
bằng:
```bash
XCODE_ACTION="test"
# A build number other than project.yml's "1", so a hard-coded CFBundleVersion is caught.
CI_BUILD_NUMBER="${GITHUB_RUN_NUMBER:-4242}"
MARKETING_VERSION="$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' project.yml | head -1)"
rm -rf build && mkdir -p build/screenshots
echo "==> xcodebuild $XCODE_ACTION on simulator $DEVICE_ID (build $CI_BUILD_NUMBER)"
STATUS=0
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/KickCounter.xcresult \
  CURRENT_PROJECT_VERSION="$CI_BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO -quiet "$XCODE_ACTION" || STATUS=$?

echo "==> Checking bundle versions"
scripts/check-bundle-versions.sh \
  build/DerivedData/Build/Products/Debug-iphonesimulator/KickCounter.app \
  "$CI_BUILD_NUMBER" "$MARKETING_VERSION" || STATUS=1
```

- [ ] **Step 6: Sửa `project.yml`**

Trong `targets.KickCounter.info.properties` thêm hai dòng (ngay dưới `CFBundleDisplayName: Kick Counter`):
```yaml
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
```
và trong `targets.KickCounterWidgets.info.properties` (ngay dưới `CFBundleDisplayName: Kick Counter`) thêm đúng hai dòng đó.

Kiểm tra cú pháp local:
```bash
bash -n scripts/ci.sh && grep -c 'CFBundleVersion: $(CURRENT_PROJECT_VERSION)' project.yml
```
Expected: không lỗi cú pháp, in `2`.

- [ ] **Step 7: Commit, push, xác minh trên CI**

```bash
git add scripts/check-bundle-versions.sh scripts/ci.sh project.yml
git commit -F - <<'MSG'
fix(build): take version and build number from build settings

Info.plist hard-coded 1.0/1, so release.sh's CURRENT_PROJECT_VERSION
had no effect. CI now builds with the run number and checks the built
app and widget Info.plist.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`. Xác nhận kiểm tra đã thực sự chạy với số run:
```bash
RUN_ID="$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId -q '.[0].databaseId')"
gh run view "$RUN_ID" --log | grep "OK build/DerivedData"
```
Expected: hai dòng `OK build/DerivedData/…/Info.plist: 1.0.0 (<số run>)` — một cho `KickCounter.app`, một cho `KickCounterWidgets.appex`. Nếu CI báo `Version mismatch`, XcodeGen không áp dụng `info.properties` → debug, không được bỏ kiểm tra.

---

### Task 2: PregnancyTimeline + PregnancyDates

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/GestationalAge.swift` (tách `elapsedDays`)
- Create: `Packages/KickCore/Sources/KickCore/PregnancyTimeline.swift`, `Packages/KickCore/Sources/KickCore/PregnancyDates.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/PregnancyTimelineTests.swift`, `Packages/KickCore/Tests/KickCoreTests/PregnancyDatesTests.swift`

**Interfaces:**
- Consumes: `GestationalWeek(weeks:days:)`, `GestationalAge.pregnancyLengthDays` (internal, `280`), test helpers `date(_:)`, `utcCalendar`.
- Produces:
  - `static func GestationalAge.elapsedDays(dueDate: Date, now: Date, calendar: Calendar) -> Int?` (internal).
  - `public enum Trimester: Int, Sendable, CaseIterable { case first = 1, second = 2, third = 3; public init(week: Int) }`.
  - `public struct PregnancyTimeline: Equatable, Sendable` với `public static let pregnancyLengthDays: Int` (280), `public static let maxWeeks: Int` (44), `public init?(dueDate: Date, now: Date, calendar: Calendar = .current)`, `public let dueDate: Date`, `public let elapsedDays: Int`, `public var week: GestationalWeek`, `public var trimester: Trimester`, `public var daysRemaining: Int` (≥ 0), `public var daysPastDue: Int` (≥ 0), `public var isPastDue: Bool`, `public var progress: Double` (0…1), `public var isKickCountingWeek: Bool` (tuần ≥ 28).
  - `public enum PregnancyDates` với `public static func dueDate(fromLMP lmp: Date, calendar: Calendar = .current) -> Date`, `public static func lmp(fromDueDate dueDate: Date, calendar: Calendar = .current) -> Date`, `public static func startOfWeek(_ week: Int, dueDate: Date, calendar: Calendar = .current) -> Date` (nửa đêm ngày đầu của tuần thai `week`).

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/PregnancyTimelineTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct PregnancyTimelineTests {
    let now = date("2026-10-02T12:00:00Z")

    /// A due date that puts `now` exactly `elapsedDays` into the pregnancy.
    private func makeTimeline(elapsedDays: Int) -> PregnancyTimeline? {
        let due = utcCalendar.date(byAdding: .day, value: 280 - elapsedDays, to: now)!
        return PregnancyTimeline(dueDate: due, now: now, calendar: utcCalendar)
    }

    @Test func specExampleIsWeek24Day3With109DaysToGo() throws {
        let timeline = try #require(PregnancyTimeline(dueDate: date("2027-01-19T12:00:00Z"), now: now, calendar: utcCalendar))
        #expect(timeline.week == GestationalWeek(weeks: 24, days: 3))
        #expect(timeline.elapsedDays == 171)
        #expect(timeline.daysRemaining == 109)
        #expect(timeline.trimester == .second)
        #expect(timeline.isPastDue == false)
        #expect(abs(timeline.progress - 171.0 / 280.0) < 0.000_001)
    }

    @Test func trimesterBoundariesAreWeeks13To14And27To28() {
        #expect(makeTimeline(elapsedDays: 97)?.trimester == .first)   // 13w6d
        #expect(makeTimeline(elapsedDays: 98)?.trimester == .second)  // 14w0d
        #expect(makeTimeline(elapsedDays: 195)?.trimester == .second) // 27w6d
        #expect(makeTimeline(elapsedDays: 196)?.trimester == .third)  // 28w0d
        #expect(Trimester(week: 0) == .first)
        #expect(Trimester(week: 44) == .third)
    }

    @Test func dueDateTodayIsWeek40WithNothingLeftButNotPastDue() throws {
        let timeline = try #require(makeTimeline(elapsedDays: 280))
        #expect(timeline.week == GestationalWeek(weeks: 40, days: 0))
        #expect(timeline.daysRemaining == 0)
        #expect(timeline.daysPastDue == 0)
        #expect(timeline.isPastDue == false)
        #expect(timeline.progress == 1)
    }

    @Test func pastDueReportsDaysPastAndFullProgress() throws {
        let timeline = try #require(makeTimeline(elapsedDays: 287))
        #expect(timeline.week == GestationalWeek(weeks: 41, days: 0))
        #expect(timeline.isPastDue)
        #expect(timeline.daysPastDue == 7)
        #expect(timeline.daysRemaining == 0)
        #expect(timeline.progress == 1)
    }

    @Test func implausibleDatesReturnNil() {
        #expect(makeTimeline(elapsedDays: -1) == nil)  // due more than 280 days away
        #expect(makeTimeline(elapsedDays: 315) == nil) // 45w0d
        #expect(makeTimeline(elapsedDays: 0)?.week == GestationalWeek(weeks: 0, days: 0))
        #expect(makeTimeline(elapsedDays: 0)?.progress == 0)
        #expect(makeTimeline(elapsedDays: 314)?.week == GestationalWeek(weeks: 44, days: 6))
    }

    @Test func timeOfDayIsIgnored() throws {
        let timeline = try #require(PregnancyTimeline(
            dueDate: date("2027-01-19T00:01:00Z"), now: date("2026-10-02T23:59:00Z"), calendar: utcCalendar
        ))
        #expect(timeline.week == GestationalWeek(weeks: 24, days: 3))
    }

    @Test func kickCountingStartsAtWeek28() {
        #expect(makeTimeline(elapsedDays: 195)?.isKickCountingWeek == false)
        #expect(makeTimeline(elapsedDays: 196)?.isKickCountingWeek == true)
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/PregnancyDatesTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct PregnancyDatesTests {
    @Test func dueDateIsLMPPlus280Days() {
        #expect(PregnancyDates.dueDate(fromLMP: date("2026-07-01T12:00:00Z"), calendar: utcCalendar) == date("2027-04-07T12:00:00Z"))
    }

    @Test func leapDayIsCountedAsACalendarDay() {
        // 2028 is a leap year: Feb 29 falls inside the 280 days.
        #expect(PregnancyDates.dueDate(fromLMP: date("2027-06-01T12:00:00Z"), calendar: utcCalendar) == date("2028-03-07T12:00:00Z"))
    }

    @Test func addsCalendarDaysNotSecondsAcrossDaylightSaving() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // 10:00 EST on Jan 1 → 10:00 EDT on Oct 8 (an hour earlier in UTC).
        #expect(PregnancyDates.dueDate(fromLMP: date("2026-01-01T15:00:00Z"), calendar: newYork) == date("2026-10-08T14:00:00Z"))
    }

    @Test func lmpAndDueDateRoundTrip() {
        let lmp = date("2026-04-14T12:00:00Z")
        let due = PregnancyDates.dueDate(fromLMP: lmp, calendar: utcCalendar)
        #expect(due == date("2027-01-19T12:00:00Z"))
        #expect(PregnancyDates.lmp(fromDueDate: due, calendar: utcCalendar) == lmp)
    }

    @Test func startOfWeekIsMidnightOfThatGestationalWeek() throws {
        let due = date("2027-01-19T12:00:00Z")
        let start = PregnancyDates.startOfWeek(24, dueDate: due, calendar: utcCalendar)
        #expect(start == date("2026-09-29T00:00:00Z"))
        let timeline = try #require(PregnancyTimeline(dueDate: due, now: start, calendar: utcCalendar))
        #expect(timeline.week == GestationalWeek(weeks: 24, days: 0))
    }
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `scripts/test-core.sh --filter "PregnancyTimelineTests|PregnancyDatesTests"`
Expected: FAIL khi biên dịch — `cannot find 'PregnancyTimeline' in scope`, `cannot find 'PregnancyDates' in scope`.

- [ ] **Step 3: Viết code**

Thay toàn bộ `Packages/KickCore/Sources/KickCore/GestationalAge.swift`:
```swift
import Foundation

public struct GestationalWeek: Equatable, Sendable {
    public let weeks: Int
    public let days: Int

    public init(weeks: Int, days: Int) {
        self.weeks = weeks
        self.days = days
    }
}

public enum GestationalAge {
    static let pregnancyLengthDays = 280
    /// Allow up to two weeks past the due date before treating it as implausible.
    static let maxDaysPastDue = 14

    /// Whole calendar days since the pregnancy started (280 days before
    /// `dueDate`). Negative when the due date is more than 280 days away.
    static func elapsedDays(dueDate: Date, now: Date, calendar: Calendar) -> Int? {
        let components = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)
        )
        guard let daysUntilDue = components.day else { return nil }
        return pregnancyLengthDays - daysUntilDue
    }

    public static func week(dueDate: Date, now: Date, calendar: Calendar = .current) -> GestationalWeek? {
        guard let elapsed = elapsedDays(dueDate: dueDate, now: now, calendar: calendar),
              (0...(pregnancyLengthDays + maxDaysPastDue)).contains(elapsed)
        else { return nil }
        return GestationalWeek(weeks: elapsed / 7, days: elapsed % 7)
    }
}
```

`Packages/KickCore/Sources/KickCore/PregnancyTimeline.swift`:
```swift
import Foundation

public enum Trimester: Int, Sendable, CaseIterable {
    case first = 1
    case second = 2
    case third = 3

    /// 1: weeks 0–13, 2: weeks 14–27, 3: week 28 onwards.
    public init(week: Int) {
        switch week {
        case ..<14: self = .first
        case 14..<28: self = .second
        default: self = .third
        }
    }
}

/// Where a pregnancy stands on a given day, derived from the due date.
/// `nil` when the due date doesn't describe a pregnancy of 0…44 weeks.
public struct PregnancyTimeline: Equatable, Sendable {
    public static let pregnancyLengthDays = GestationalAge.pregnancyLengthDays
    public static let maxWeeks = 44
    static let kickCountingFromWeek = 28

    public let dueDate: Date
    public let elapsedDays: Int

    public init?(dueDate: Date, now: Date, calendar: Calendar = .current) {
        guard let elapsed = GestationalAge.elapsedDays(dueDate: dueDate, now: now, calendar: calendar),
              (0...(Self.maxWeeks * 7 + 6)).contains(elapsed)
        else { return nil }
        self.dueDate = dueDate
        self.elapsedDays = elapsed
    }

    public var week: GestationalWeek {
        GestationalWeek(weeks: elapsedDays / 7, days: elapsedDays % 7)
    }

    public var trimester: Trimester { Trimester(week: week.weeks) }

    public var daysRemaining: Int { max(0, Self.pregnancyLengthDays - elapsedDays) }

    public var daysPastDue: Int { max(0, elapsedDays - Self.pregnancyLengthDays) }

    public var isPastDue: Bool { daysPastDue > 0 }

    /// 0 on the first day of the last period, 1 on (and after) the due date.
    public var progress: Double { min(1, Double(elapsedDays) / Double(Self.pregnancyLengthDays)) }

    /// From week 28 the home screen suggests a daily kick count.
    public var isKickCountingWeek: Bool { week.weeks >= Self.kickCountingFromWeek }
}
```

`Packages/KickCore/Sources/KickCore/PregnancyDates.swift`:
```swift
import Foundation

public enum PregnancyDates {
    /// Naegele's rule: due date = first day of the last period + 280 days.
    /// Adds calendar days, so a daylight-saving change never shifts the time of day.
    public static func dueDate(fromLMP lmp: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: GestationalAge.pregnancyLengthDays, to: lmp) ?? lmp
    }

    public static func lmp(fromDueDate dueDate: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -GestationalAge.pregnancyLengthDays, to: dueDate) ?? dueDate
    }

    /// Midnight starting gestational week `week` of a pregnancy due on `dueDate`.
    public static func startOfWeek(_ week: Int, dueDate: Date, calendar: Calendar = .current) -> Date {
        let due = calendar.startOfDay(for: dueDate)
        return calendar.date(byAdding: .day, value: week * 7 - GestationalAge.pregnancyLengthDays, to: due) ?? due
    }
}
```

- [ ] **Step 4: Chạy test, xác nhận pass (kể cả test cũ của GestationalAge)**

Run: `scripts/test-core.sh`
Expected: PASS toàn bộ, gồm `PregnancyTimelineTests`, `PregnancyDatesTests`, `GestationalAgeTests`.

- [ ] **Step 5: Commit, push, CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): add PregnancyTimeline and PregnancyDates

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 3: Hồ sơ thai kỳ, nhập ngày, launch options cho UI test

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/Settings.swift` (thêm 2 khóa)
- Create: `Packages/KickCore/Sources/KickCore/PregnancyProfile.swift`, `Packages/KickCore/Sources/KickCore/PregnancyDateInput.swift`, `Packages/KickCore/Sources/KickCore/UITestLaunchOptions.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/PregnancyProfileTests.swift`, `Packages/KickCore/Tests/KickCoreTests/PregnancyDateInputTests.swift`, `Packages/KickCore/Tests/KickCoreTests/UITestLaunchOptionsTests.swift`

**Interfaces:**
- Consumes: `PregnancyDates.dueDate(fromLMP:calendar:)`, `PregnancyDates.lmp(fromDueDate:calendar:)`, `PregnancyTimeline` (trong test), `GestationalAge.pregnancyLengthDays`.
- Produces:
  - `SettingsKey.pregnancyDateSource = "pregnancyDateSource"`, `SettingsKey.lmpDate = "lmpDate"`.
  - `public enum PregnancyDateSource: String, Sendable, CaseIterable { case dueDate, lmp }`.
  - `public struct PregnancyProfile: Equatable, Sendable { public let source: PregnancyDateSource; public let dueDate: Date?; public let lmpDate: Date?; public init(source:dueDate:lmpDate:) }` với `public static func load(from defaults: UserDefaults) -> PregnancyProfile`, `public static func saveDueDate(_ dueDate: Date, to defaults: UserDefaults)`, `public static func saveLMP(_ lmp: Date, to defaults: UserDefaults, calendar: Calendar = .current)`, `public static func save(source: PregnancyDateSource, date: Date, to defaults: UserDefaults, calendar: Calendar = .current)`, `public static func clear(_ defaults: UserDefaults)`.
  - `public struct PregnancyDateSelection: Equatable, Sendable { public var source: PregnancyDateSource; public var date: Date; public init(source:date:) }`.
  - `public enum PregnancyDateInput` với `range(for: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> ClosedRange<Date>`, `clamp(_ date: Date, for: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> Date`, `defaultDate(for: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> Date`, `convert(_ date: Date, to: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> Date`, `initialSelection(for profile: PregnancyProfile, now: Date, calendar: Calendar = .current) -> PregnancyDateSelection` (tất cả `public static`).
  - `public struct UITestLaunchOptions: Equatable, Sendable { public let isUITesting: Bool; public let fixedNow: Date?; public let seedDueDate: Date?; public init(arguments: [String]) }`.

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/PregnancyProfileTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct PregnancyProfileTests {
    /// A fresh, empty defaults domain per test.
    private func makeDefaults() -> UserDefaults {
        let name = "PregnancyProfileTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func emptyDefaultsHaveNoDates() {
        #expect(PregnancyProfile.load(from: makeDefaults()) == PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil))
    }

    @Test func version1DueDateKeepsWorkingWithoutMigration() {
        let defaults = makeDefaults()
        defaults.set(date("2027-01-19T12:00:00Z").timeIntervalSince1970, forKey: SettingsKey.dueDate)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(source: .dueDate, dueDate: date("2027-01-19T12:00:00Z"), lmpDate: nil))
    }

    @Test func savingLMPStoresItAndTheDerivedDueDate() {
        let defaults = makeDefaults()
        PregnancyProfile.saveLMP(date("2026-07-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(
            source: .lmp, dueDate: date("2027-04-07T12:00:00Z"), lmpDate: date("2026-07-01T12:00:00Z")
        ))
        #expect(defaults.double(forKey: SettingsKey.dueDate) == date("2027-04-07T12:00:00Z").timeIntervalSince1970)
    }

    @Test func savingDueDateClearsLMP() {
        let defaults = makeDefaults()
        PregnancyProfile.saveLMP(date("2026-07-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        PregnancyProfile.saveDueDate(date("2027-02-01T12:00:00Z"), to: defaults)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(source: .dueDate, dueDate: date("2027-02-01T12:00:00Z"), lmpDate: nil))
        #expect(defaults.double(forKey: SettingsKey.lmpDate) == 0)
    }

    @Test func saveDispatchesOnSource() {
        let defaults = makeDefaults()
        PregnancyProfile.save(source: .lmp, date: date("2026-07-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        #expect(PregnancyProfile.load(from: defaults).source == .lmp)
        PregnancyProfile.save(source: .dueDate, date: date("2027-02-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(source: .dueDate, dueDate: date("2027-02-01T12:00:00Z"), lmpDate: nil))
    }

    @Test func clearRemovesEverything() {
        let defaults = makeDefaults()
        PregnancyProfile.saveLMP(date("2026-07-01T12:00:00Z"), to: defaults, calendar: utcCalendar)
        PregnancyProfile.clear(defaults)
        #expect(PregnancyProfile.load(from: defaults) == PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil))
        #expect(defaults.double(forKey: SettingsKey.dueDate) == 0)
    }

    @Test func lmpSourceWithoutLMPDateFallsBackToDueDate() {
        let defaults = makeDefaults()
        defaults.set("lmp", forKey: SettingsKey.pregnancyDateSource)
        defaults.set(date("2027-01-19T12:00:00Z").timeIntervalSince1970, forKey: SettingsKey.dueDate)
        #expect(PregnancyProfile.load(from: defaults).source == .dueDate)
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/PregnancyDateInputTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct PregnancyDateInputTests {
    let now = date("2026-10-02T12:00:00Z")
    let oneDay: TimeInterval = 86_400

    private func timeline(due: Date) -> PregnancyTimeline? {
        PregnancyTimeline(dueDate: due, now: now, calendar: utcCalendar)
    }

    @Test func dueDateRangeCoversExactlyTheValidTimeline() {
        let range = PregnancyDateInput.range(for: .dueDate, now: now, calendar: utcCalendar)
        #expect(range.lowerBound == date("2026-08-29T00:00:00Z"))           // 44w6d today
        #expect(range.upperBound == date("2027-07-09T23:59:59Z"))           // 0w0d today
        #expect(timeline(due: range.lowerBound)?.week == GestationalWeek(weeks: 44, days: 6))
        #expect(timeline(due: range.lowerBound.addingTimeInterval(-oneDay)) == nil)
        #expect(timeline(due: range.upperBound)?.week == GestationalWeek(weeks: 0, days: 0))
        #expect(timeline(due: range.upperBound.addingTimeInterval(1)) == nil)
    }

    @Test func lastPeriodRangeEndsTodayAndCoversTheValidTimeline() {
        let range = PregnancyDateInput.range(for: .lmp, now: now, calendar: utcCalendar)
        #expect(range.upperBound == date("2026-10-02T23:59:59Z"))
        let earliestDue = PregnancyDates.dueDate(fromLMP: range.lowerBound, calendar: utcCalendar)
        #expect(timeline(due: earliestDue)?.week == GestationalWeek(weeks: 44, days: 6))
        let tooEarly = PregnancyDates.dueDate(fromLMP: range.lowerBound.addingTimeInterval(-oneDay), calendar: utcCalendar)
        #expect(timeline(due: tooEarly) == nil)
    }

    @Test func defaultsDescribeTheSamePregnancyAt20Weeks() {
        let due = PregnancyDateInput.defaultDate(for: .dueDate, now: now, calendar: utcCalendar)
        let lmp = PregnancyDateInput.defaultDate(for: .lmp, now: now, calendar: utcCalendar)
        #expect(due == date("2027-02-19T12:00:00Z"))
        #expect(PregnancyDates.dueDate(fromLMP: lmp, calendar: utcCalendar) == due)
        #expect(timeline(due: due)?.week == GestationalWeek(weeks: 20, days: 0))
    }

    @Test func convertKeepsTheSamePregnancy() {
        let lmp = PregnancyDateInput.convert(date("2027-01-19T12:00:00Z"), to: .lmp, now: now, calendar: utcCalendar)
        #expect(lmp == date("2026-04-14T12:00:00Z"))
        #expect(PregnancyDateInput.convert(lmp, to: .dueDate, now: now, calendar: utcCalendar) == date("2027-01-19T12:00:00Z"))
    }

    @Test func clampKeepsDatesInsideThePicker() {
        let dueRange = PregnancyDateInput.range(for: .dueDate, now: now, calendar: utcCalendar)
        let lmpRange = PregnancyDateInput.range(for: .lmp, now: now, calendar: utcCalendar)
        #expect(PregnancyDateInput.clamp(date("2030-01-01T00:00:00Z"), for: .dueDate, now: now, calendar: utcCalendar) == dueRange.upperBound)
        #expect(PregnancyDateInput.clamp(date("2020-01-01T00:00:00Z"), for: .lmp, now: now, calendar: utcCalendar) == lmpRange.lowerBound)
    }

    @Test func initialSelectionFollowsTheStoredProfile() {
        let empty = PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil)
        #expect(PregnancyDateInput.initialSelection(for: empty, now: now, calendar: utcCalendar)
            == PregnancyDateSelection(source: .dueDate, date: date("2027-02-19T12:00:00Z")))

        let due = PregnancyProfile(source: .dueDate, dueDate: date("2027-01-19T12:00:00Z"), lmpDate: nil)
        #expect(PregnancyDateInput.initialSelection(for: due, now: now, calendar: utcCalendar)
            == PregnancyDateSelection(source: .dueDate, date: date("2027-01-19T12:00:00Z")))

        let lmp = PregnancyProfile(source: .lmp, dueDate: date("2027-04-07T12:00:00Z"), lmpDate: date("2026-07-01T12:00:00Z"))
        #expect(PregnancyDateInput.initialSelection(for: lmp, now: now, calendar: utcCalendar)
            == PregnancyDateSelection(source: .lmp, date: date("2026-07-01T12:00:00Z")))
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/UITestLaunchOptionsTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct UITestLaunchOptionsTests {
    @Test func parsesFixedNowAndSeedDueDateWhenUITesting() {
        let options = UITestLaunchOptions(arguments: [
            "KickCounter", "-uiTesting", "-fixedNow", "2026-10-02T12:00:00Z", "-seedDueDate", "2027-01-19T12:00:00Z",
        ])
        #expect(options.isUITesting)
        #expect(options.fixedNow == date("2026-10-02T12:00:00Z"))
        #expect(options.seedDueDate == date("2027-01-19T12:00:00Z"))
    }

    @Test func ignoresDatesWithoutUITesting() {
        let options = UITestLaunchOptions(arguments: ["KickCounter", "-fixedNow", "2026-10-02T12:00:00Z"])
        #expect(options == UITestLaunchOptions(arguments: []))
        #expect(options.isUITesting == false)
        #expect(options.fixedNow == nil)
    }

    @Test func invalidOrMissingValuesAreNil() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-fixedNow", "tomorrow"]).fixedNow == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedDueDate"]).seedDueDate == nil)
    }
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `scripts/test-core.sh --filter "PregnancyProfileTests|PregnancyDateInputTests|UITestLaunchOptionsTests"`
Expected: FAIL khi biên dịch — `cannot find 'PregnancyProfile' in scope` (và `PregnancyDateInput`, `UITestLaunchOptions`, `SettingsKey.lmpDate`).

- [ ] **Step 3: Viết code**

Trong `Packages/KickCore/Sources/KickCore/Settings.swift`, thêm vào `enum SettingsKey` (ngay dưới `dueDate`):
```swift
    /// `"dueDate"` or `"lmp"`: which date the mother entered. `dueDate` stays the source of truth.
    public static let pregnancyDateSource = "pregnancyDateSource"
    /// First day of the last period, `timeIntervalSince1970`; 0 means "not set".
    public static let lmpDate = "lmpDate"
```

`Packages/KickCore/Sources/KickCore/PregnancyProfile.swift`:
```swift
import Foundation

public enum PregnancyDateSource: String, Sendable, CaseIterable {
    case dueDate
    case lmp
}

/// The pregnancy dates kept in `AppGroup.defaults` (not synced). `SettingsKey.dueDate`
/// is the single source of truth; the LMP is kept only to show what the mother entered.
/// Clearing writes 0 rather than removing keys so `@AppStorage` views update.
public struct PregnancyProfile: Equatable, Sendable {
    public let source: PregnancyDateSource
    public let dueDate: Date?
    public let lmpDate: Date?

    public init(source: PregnancyDateSource, dueDate: Date?, lmpDate: Date?) {
        self.source = source
        self.dueDate = dueDate
        self.lmpDate = lmpDate
    }

    public static func load(from defaults: UserDefaults) -> PregnancyProfile {
        let due = defaults.double(forKey: SettingsKey.dueDate)
        let lmp = defaults.double(forKey: SettingsKey.lmpDate)
        let lmpDate = lmp > 0 ? Date(timeIntervalSince1970: lmp) : nil
        let stored = defaults.string(forKey: SettingsKey.pregnancyDateSource).flatMap(PregnancyDateSource.init(rawValue:))
        return PregnancyProfile(
            source: stored == .lmp && lmpDate != nil ? .lmp : .dueDate,
            dueDate: due > 0 ? Date(timeIntervalSince1970: due) : nil,
            lmpDate: lmpDate
        )
    }

    public static func saveDueDate(_ dueDate: Date, to defaults: UserDefaults) {
        defaults.set(dueDate.timeIntervalSince1970, forKey: SettingsKey.dueDate)
        defaults.set(0.0, forKey: SettingsKey.lmpDate)
        defaults.set(PregnancyDateSource.dueDate.rawValue, forKey: SettingsKey.pregnancyDateSource)
    }

    public static func saveLMP(_ lmp: Date, to defaults: UserDefaults, calendar: Calendar = .current) {
        let due = PregnancyDates.dueDate(fromLMP: lmp, calendar: calendar)
        defaults.set(due.timeIntervalSince1970, forKey: SettingsKey.dueDate)
        defaults.set(lmp.timeIntervalSince1970, forKey: SettingsKey.lmpDate)
        defaults.set(PregnancyDateSource.lmp.rawValue, forKey: SettingsKey.pregnancyDateSource)
    }

    public static func save(source: PregnancyDateSource, date: Date, to defaults: UserDefaults, calendar: Calendar = .current) {
        switch source {
        case .dueDate: saveDueDate(date, to: defaults)
        case .lmp: saveLMP(date, to: defaults, calendar: calendar)
        }
    }

    public static func clear(_ defaults: UserDefaults) {
        defaults.set(0.0, forKey: SettingsKey.dueDate)
        defaults.set(0.0, forKey: SettingsKey.lmpDate)
        defaults.set(PregnancyDateSource.dueDate.rawValue, forKey: SettingsKey.pregnancyDateSource)
    }
}
```

`Packages/KickCore/Sources/KickCore/PregnancyDateInput.swift`:
```swift
import Foundation

public struct PregnancyDateSelection: Equatable, Sendable {
    public var source: PregnancyDateSource
    public var date: Date

    public init(source: PregnancyDateSource, date: Date) {
        self.source = source
        self.date = date
    }
}

/// Limits and defaults for the due date / last period picker. The ranges allow
/// exactly the dates `PregnancyTimeline` accepts today (0w0d…44w6d).
public enum PregnancyDateInput {
    /// Both defaults describe the same pregnancy at 20 weeks.
    static let defaultOffsetDays = 140
    /// Up to 44 weeks 6 days (the last day `PregnancyTimeline` accepts) = 280 + 34 days.
    static let maxDaysPastDue = (PregnancyTimeline.maxWeeks + 1) * 7 - 1 - GestationalAge.pregnancyLengthDays

    public static func range(for source: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        func startOfDay(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        let length = GestationalAge.pregnancyLengthDays
        switch source {
        case .dueDate:
            return startOfDay(-maxDaysPastDue)...startOfDay(length + 1).addingTimeInterval(-1)
        case .lmp:
            return startOfDay(-(length + maxDaysPastDue))...startOfDay(1).addingTimeInterval(-1)
        }
    }

    public static func clamp(_ date: Date, for source: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> Date {
        let bounds = range(for: source, now: now, calendar: calendar)
        return min(max(date, bounds.lowerBound), bounds.upperBound)
    }

    public static func defaultDate(for source: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let offset = source == .dueDate ? defaultOffsetDays : -defaultOffsetDays
        let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    /// Re-expresses the picked date when the mother switches between due date and last period.
    public static func convert(_ date: Date, to source: PregnancyDateSource, now: Date, calendar: Calendar = .current) -> Date {
        let converted = switch source {
        case .lmp: PregnancyDates.lmp(fromDueDate: date, calendar: calendar)
        case .dueDate: PregnancyDates.dueDate(fromLMP: date, calendar: calendar)
        }
        return clamp(converted, for: source, now: now, calendar: calendar)
    }

    public static func initialSelection(for profile: PregnancyProfile, now: Date, calendar: Calendar = .current) -> PregnancyDateSelection {
        if profile.source == .lmp, let lmp = profile.lmpDate {
            return PregnancyDateSelection(source: .lmp, date: clamp(lmp, for: .lmp, now: now, calendar: calendar))
        }
        if let due = profile.dueDate {
            return PregnancyDateSelection(source: .dueDate, date: clamp(due, for: .dueDate, now: now, calendar: calendar))
        }
        return PregnancyDateSelection(source: .dueDate, date: defaultDate(for: .dueDate, now: now, calendar: calendar))
    }
}
```

`Packages/KickCore/Sources/KickCore/UITestLaunchOptions.swift`:
```swift
import Foundation

/// Launch arguments that make UI tests and screenshots deterministic. They only
/// take effect together with `-uiTesting`:
/// - `-fixedNow <ISO8601>` pins the app's clock for the pregnancy and appointment screens.
/// - `-seedDueDate <ISO8601>` stores that due date at launch.
public struct UITestLaunchOptions: Equatable, Sendable {
    public let isUITesting: Bool
    public let fixedNow: Date?
    public let seedDueDate: Date?

    public init(arguments: [String]) {
        isUITesting = arguments.contains("-uiTesting")
        fixedNow = isUITesting ? Self.date(after: "-fixedNow", in: arguments) : nil
        seedDueDate = isUITesting ? Self.date(after: "-seedDueDate", in: arguments) : nil
    }

    private static func date(after flag: String, in arguments: [String]) -> Date? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return try? Date(arguments[index + 1], strategy: .iso8601)
    }
}
```

- [ ] **Step 4: Chạy test, xác nhận pass**

Run: `scripts/test-core.sh`
Expected: PASS toàn bộ.

- [ ] **Step 5: Commit, push, CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): store pregnancy dates from due date or last period

Adds PregnancyProfile (dueDate stays the source of truth), picker
ranges/defaults, and the -fixedNow/-seedDueDate UI-test options.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 4: Mô hình nội dung, thư viện tra cứu, kiểm định (với fixture nhỏ)

Task này chỉ định nghĩa kiểu Swift + logic, kiểm thử bằng một fixture JSON nhỏ (tuần 7–9) trong test target. File nội dung thật được soạn ở Task 5.

**Files:**
- Modify: `Packages/KickCore/Package.swift` (test target thêm `resources: [.copy("Fixtures")]`), `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift` (thêm `fixtureContent`)
- Create: `Packages/KickCore/Sources/KickCore/PregnancyContent.swift`, `Packages/KickCore/Sources/KickCore/WeeklyContentLibrary.swift`, `Packages/KickCore/Sources/KickCore/ContentValidator.swift`, `Packages/KickCore/Tests/KickCoreTests/Fixtures/content-fixture.json`
- Test: `Packages/KickCore/Tests/KickCoreTests/ContentValidatorTests.swift`, `Packages/KickCore/Tests/KickCoreTests/WeeklyContentLibraryTests.swift`

**Interfaces:**
- Consumes: không có gì mới.
- Produces:
  - `public enum ContentLanguage: String, Codable, Sendable, CaseIterable { case en, vi; public init(preferredLanguages: [String]); public static var current: ContentLanguage }` — ngôn ngữ đầu tiên trong danh sách ưu tiên là `vi` hoặc `en`; không có thì `en`.
  - `public struct LocalizedText: Codable, Equatable, Sendable { public var en: String; public var vi: String; public func text(_ language: ContentLanguage) -> String }`.
  - `public struct LocalizedList: Codable, Equatable, Sendable { public var en: [String]; public var vi: [String]; public func items(_ language: ContentLanguage) -> [String] }`.
  - `public struct FruitSize: Codable, Equatable, Sendable { public var emoji: String; public var en: String; public var vi: String; public func name(_ language: ContentLanguage) -> String }`.
  - `public struct WeekContent: Codable, Equatable, Sendable, Identifiable { public var week: Int; public var reviewed: Bool; public var size: FruitSize; public var lengthCm: Double?; public var weightG: Double?; public var baby, mom, tips, warnings: LocalizedList; public var id: Int }`.
  - `public struct Milestone: Codable, Equatable, Sendable, Identifiable { public var id: String; public var fromWeek: Int; public var toWeek: Int; public var title: LocalizedText; public var detail: LocalizedText; public var reviewed: Bool }`.
  - `public struct PregnancyContent: Codable, Equatable, Sendable { public var version: Int; public var sources: [String]; public var weeks: [WeekContent]; public var milestones: [Milestone] }`.
  - `public enum ContentVisibility: Sendable, Equatable { case reviewedOnly, all }`; `public enum WeekDisplay: Equatable, Sendable { case content(WeekContent, pendingReview: Bool); case underReview(week: Int) }`.
  - `public struct WeeklyContentLibrary: Sendable` với `public static let weekRange: ClosedRange<Int>` (`4...42`), `public let document: PregnancyContent`, `public init(document: PregnancyContent)`, `public init(data: Data) throws`, `public var sources: [String]`, `public var milestones: [Milestone]` (theo `fromWeek`, `toWeek`, `id`), `public static func clampedWeek(_ week: Int) -> Int`, `public func content(forWeek week: Int) -> WeekContent?`, `public func display(forWeek week: Int, visibility: ContentVisibility) -> WeekDisplay?`, `public func upcomingMilestones(atWeek week: Int, visibility: ContentVisibility = .all) -> [Milestone]` (mốc có `toWeek >= week`, gồm cả mốc đang diễn ra).
  - `public enum ContentIssue: Equatable, Sendable` (các case ở Step 3) và `public enum ContentValidator { public static let supportedVersion: Int; public static let measurementsRequiredFromWeek: Int; public static func validate(_ content: PregnancyContent, requiredWeeks: ClosedRange<Int> = WeeklyContentLibrary.weekRange) -> [ContentIssue] }`.
  - Test helper: `func fixtureContent(_ name: String = "content-fixture") throws -> PregnancyContent`.

- [ ] **Step 1: Thêm fixture + helper, viết test trước**

Trong `Packages/KickCore/Package.swift`, đổi dòng test target thành:
```swift
        .testTarget(name: "KickCoreTests", dependencies: ["KickCore"], resources: [.copy("Fixtures")]),
```

`Packages/KickCore/Tests/KickCoreTests/Fixtures/content-fixture.json` (hợp lệ theo mọi luật với `requiredWeeks: 7...9`; tuần 7 không có số đo; tuần 8 và mốc `m-late` chưa duyệt):
```json
{
  "version": 1,
  "sources": ["Fixture source A", "Fixture source B"],
  "weeks": [
    {
      "week": 7,
      "reviewed": true,
      "size": { "emoji": "🫐", "en": "a blueberry", "vi": "một quả việt quất" },
      "baby": { "en": ["Baby fact 7a.", "Baby fact 7b."], "vi": ["Bé tuần 7 ý a.", "Bé tuần 7 ý b."] },
      "mom": { "en": ["Mom fact 7a.", "Mom fact 7b."], "vi": ["Mẹ tuần 7 ý a.", "Mẹ tuần 7 ý b."] },
      "tips": { "en": ["Tip 7a.", "Tip 7b."], "vi": ["Lời khuyên 7a.", "Lời khuyên 7b."] },
      "warnings": { "en": ["Call your doctor about 7."], "vi": ["Gọi bác sĩ về 7."] }
    },
    {
      "week": 8,
      "reviewed": false,
      "size": { "emoji": "🍒", "en": "a cherry", "vi": "một quả anh đào" },
      "lengthCm": 1.6,
      "weightG": 1,
      "baby": { "en": ["Baby fact 8a.", "Baby fact 8b."], "vi": ["Bé tuần 8 ý a.", "Bé tuần 8 ý b."] },
      "mom": { "en": ["Mom fact 8a.", "Mom fact 8b."], "vi": ["Mẹ tuần 8 ý a.", "Mẹ tuần 8 ý b."] },
      "tips": { "en": ["Tip 8a.", "Tip 8b."], "vi": ["Lời khuyên 8a.", "Lời khuyên 8b."] },
      "warnings": { "en": ["Call your doctor about 8."], "vi": ["Gọi bác sĩ về 8."] }
    },
    {
      "week": 9,
      "reviewed": true,
      "size": { "emoji": "🍇", "en": "a grape", "vi": "một quả nho" },
      "lengthCm": 2.3,
      "weightG": 2,
      "baby": { "en": ["Baby fact 9a.", "Baby fact 9b."], "vi": ["Bé tuần 9 ý a.", "Bé tuần 9 ý b."] },
      "mom": { "en": ["Mom fact 9a.", "Mom fact 9b."], "vi": ["Mẹ tuần 9 ý a.", "Mẹ tuần 9 ý b."] },
      "tips": { "en": ["Tip 9a.", "Tip 9b."], "vi": ["Lời khuyên 9a.", "Lời khuyên 9b."] },
      "warnings": { "en": ["Call your doctor about 9."], "vi": ["Gọi bác sĩ về 9."] }
    }
  ],
  "milestones": [
    {
      "id": "m-early",
      "fromWeek": 6,
      "toWeek": 8,
      "title": { "en": "Early visit", "vi": "Khám sớm" },
      "detail": { "en": "Confirm the pregnancy.", "vi": "Xác nhận có thai." },
      "reviewed": true
    },
    {
      "id": "m-late",
      "fromWeek": 11,
      "toWeek": 14,
      "title": { "en": "Screening scan", "vi": "Siêu âm sàng lọc" },
      "detail": { "en": "A scan in weeks 11 to 14.", "vi": "Siêu âm vào tuần 11 đến 14." },
      "reviewed": false
    }
  ]
}
```

Thêm vào cuối `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`:
```swift
struct MissingFixture: Error {
    let name: String
}

/// Decodes `Tests/KickCoreTests/Fixtures/<name>.json`.
func fixtureContent(_ name: String = "content-fixture") throws -> PregnancyContent {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
        throw MissingFixture(name: name)
    }
    return try JSONDecoder().decode(PregnancyContent.self, from: Data(contentsOf: url))
}
```

`Packages/KickCore/Tests/KickCoreTests/ContentValidatorTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct ContentValidatorTests {
    private func issues(_ content: PregnancyContent) -> [ContentIssue] {
        ContentValidator.validate(content, requiredWeeks: 7...9)
    }

    @Test func fixtureIsValid() throws {
        #expect(issues(try fixtureContent()).isEmpty)
    }

    @Test func missingWeekIsReported() throws {
        var content = try fixtureContent()
        content.weeks.removeAll { $0.week == 8 }
        #expect(issues(content).contains(.missingWeek(8)))
    }

    @Test func duplicateAndUnexpectedWeeksAreReported() throws {
        var content = try fixtureContent()
        content.weeks.append(content.weeks[0])
        var extra = content.weeks[2]
        extra.week = 43
        content.weeks.append(extra)
        let found = issues(content)
        #expect(found.contains(.duplicateWeek(7)))
        #expect(found.contains(.unexpectedWeek(43)))
        #expect(found.contains(.weeksOutOfOrder))
    }

    @Test func tooFewItemsPerLanguageIsReported() throws {
        var content = try fixtureContent()
        content.weeks[1].tips.vi = ["Một ý."]
        let found = issues(content)
        #expect(found.contains(.tooFewItems(week: 8, section: "tips", language: .vi, minimum: 2)))
        #expect(found.contains(.translationCountMismatch(week: 8, section: "tips")))
    }

    @Test func everyWeekNeedsAWarning() throws {
        var content = try fixtureContent()
        content.weeks[0].warnings.en = []
        #expect(issues(content).contains(.tooFewItems(week: 7, section: "warnings", language: .en, minimum: 1)))
    }

    @Test func blankTextIsReported() throws {
        var content = try fixtureContent()
        content.weeks[0].baby.en[0] = "   "
        content.weeks[1].size.vi = ""
        let found = issues(content)
        #expect(found.contains(.blankText("week 7 baby.en")))
        #expect(found.contains(.blankText("week 8 size.vi")))
    }

    @Test func measurementsAreRequiredFromWeek8() throws {
        var content = try fixtureContent()
        content.weeks[1].lengthCm = nil
        let found = issues(content)
        #expect(found.contains(.missingMeasurement(week: 8, field: "lengthCm")))
        #expect(!found.contains(.missingMeasurement(week: 7, field: "lengthCm")))
    }

    @Test func decreasingOrNonPositiveMeasurementsAreReported() throws {
        var content = try fixtureContent()
        content.weeks[2].weightG = 0.5
        content.weeks[1].lengthCm = 0
        let found = issues(content)
        #expect(found.contains(.decreasingMeasurement(week: 9, field: "weightG")))
        #expect(found.contains(.nonPositiveMeasurement(week: 8, field: "lengthCm")))
    }

    @Test func invalidMilestoneRangesAreReported() throws {
        var content = try fixtureContent()
        content.milestones[0].fromWeek = 9
        content.milestones[0].toWeek = 8
        content.milestones[1].toWeek = 43
        let found = issues(content)
        #expect(found.contains(.invalidMilestoneRange(id: "m-early")))
        #expect(found.contains(.invalidMilestoneRange(id: "m-late")))
    }

    @Test func duplicateMilestoneIDsAreReported() throws {
        var content = try fixtureContent()
        content.milestones[1].id = "m-early"
        #expect(issues(content).contains(.duplicateMilestoneID("m-early")))
    }

    @Test func blankMilestoneTextIsReported() throws {
        var content = try fixtureContent()
        content.milestones[0].detail.vi = " "
        #expect(issues(content).contains(.blankText("milestone m-early detail.vi")))
    }

    @Test func versionAndSourcesAreChecked() throws {
        var content = try fixtureContent()
        content.version = 2
        content.sources = []
        let found = issues(content)
        #expect(found.contains(.unsupportedVersion(2)))
        #expect(found.contains(.noSources))
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/WeeklyContentLibraryTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct WeeklyContentLibraryTests {
    private func library() throws -> WeeklyContentLibrary {
        WeeklyContentLibrary(document: try fixtureContent())
    }

    @Test func decodesFromJSONData() throws {
        let data = try JSONEncoder().encode(try fixtureContent())
        let library = try WeeklyContentLibrary(data: data)
        #expect(library.document.weeks.map(\.week) == [7, 8, 9])
        #expect(library.sources == ["Fixture source A", "Fixture source B"])
        #expect(library.content(forWeek: 7)?.lengthCm == nil)
        #expect(library.content(forWeek: 8)?.weightG == 1)
    }

    @Test func malformedJSONThrows() {
        #expect(throws: DecodingError.self) {
            try WeeklyContentLibrary(data: Data("{}".utf8))
        }
    }

    @Test func weekLookupClampsTo4Through42() {
        #expect(WeeklyContentLibrary.clampedWeek(1) == 4)
        #expect(WeeklyContentLibrary.clampedWeek(4) == 4)
        #expect(WeeklyContentLibrary.clampedWeek(24) == 24)
        #expect(WeeklyContentLibrary.clampedWeek(42) == 42)
        #expect(WeeklyContentLibrary.clampedWeek(44) == 42)
    }

    @Test func lookupReturnsThatWeek() throws {
        let library = try library()
        #expect(library.content(forWeek: 8)?.size.emoji == "🍒")
        #expect(library.content(forWeek: 5) == nil) // clamped to 5, absent from the fixture
    }

    @Test func displayHonoursReviewedFlag() throws {
        let library = try library()
        let week7 = try #require(library.content(forWeek: 7))
        let week8 = try #require(library.content(forWeek: 8))
        #expect(library.display(forWeek: 7, visibility: .reviewedOnly) == .content(week7, pendingReview: false))
        #expect(library.display(forWeek: 8, visibility: .reviewedOnly) == .underReview(week: 8))
        #expect(library.display(forWeek: 8, visibility: .all) == .content(week8, pendingReview: true))
        #expect(library.display(forWeek: 7, visibility: .all) == .content(week7, pendingReview: false))
    }

    @Test func upcomingMilestonesIncludeOnesUnderway() throws {
        let library = try library()
        #expect(library.upcomingMilestones(atWeek: 7).map(\.id) == ["m-early", "m-late"])
        #expect(library.upcomingMilestones(atWeek: 8).map(\.id) == ["m-early", "m-late"])
        #expect(library.upcomingMilestones(atWeek: 9).map(\.id) == ["m-late"])
        #expect(library.upcomingMilestones(atWeek: 15).isEmpty)
        #expect(library.upcomingMilestones(atWeek: 7, visibility: .reviewedOnly).map(\.id) == ["m-early"])
    }

    @Test func milestonesAreSortedByWeek() throws {
        var content = try fixtureContent()
        content.milestones.reverse()
        #expect(WeeklyContentLibrary(document: content).milestones.map(\.id) == ["m-early", "m-late"])
    }

    @Test func localizedAccessorsPickTheLanguage() throws {
        let library = try library()
        let week8 = try #require(library.content(forWeek: 8))
        #expect(week8.size.name(.vi) == "một quả anh đào")
        #expect(week8.size.name(.en) == "a cherry")
        #expect(week8.baby.items(.en) == ["Baby fact 8a.", "Baby fact 8b."])
        #expect(week8.warnings.items(.vi) == ["Gọi bác sĩ về 8."])
        #expect(library.milestones[0].title.text(.vi) == "Khám sớm")
    }

    @Test func contentLanguageFollowsTheFirstSupportedPreference() {
        #expect(ContentLanguage(preferredLanguages: ["vi-VN"]) == .vi)
        #expect(ContentLanguage(preferredLanguages: ["vi"]) == .vi)
        #expect(ContentLanguage(preferredLanguages: ["en-GB"]) == .en)
        #expect(ContentLanguage(preferredLanguages: ["fr-FR", "vi-VN"]) == .vi)
        #expect(ContentLanguage(preferredLanguages: ["fr-FR"]) == .en)
        #expect(ContentLanguage(preferredLanguages: []) == .en)
    }
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `scripts/test-core.sh --filter "ContentValidatorTests|WeeklyContentLibraryTests"`
Expected: FAIL khi biên dịch — `cannot find type 'PregnancyContent' in scope`.

- [ ] **Step 3: Viết code**

`Packages/KickCore/Sources/KickCore/PregnancyContent.swift`:
```swift
import Foundation

/// Language of the bundled medical content: the first of the user's preferred
/// languages that the content supports (the same rule the app's own
/// localization follows), falling back to English.
public enum ContentLanguage: String, Codable, Sendable, CaseIterable {
    case en
    case vi

    public init(preferredLanguages: [String]) {
        for identifier in preferredLanguages {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "vi":
                self = .vi
                return
            case "en":
                self = .en
                return
            default:
                continue
            }
        }
        self = .en
    }

    public static var current: ContentLanguage {
        ContentLanguage(preferredLanguages: Locale.preferredLanguages)
    }
}

public struct LocalizedText: Codable, Equatable, Sendable {
    public var en: String
    public var vi: String

    public func text(_ language: ContentLanguage) -> String {
        language == .vi ? vi : en
    }
}

public struct LocalizedList: Codable, Equatable, Sendable {
    public var en: [String]
    public var vi: [String]

    public func items(_ language: ContentLanguage) -> [String] {
        language == .vi ? vi : en
    }
}

/// "Your baby is about the size of …", illustrated by an emoji (no images).
public struct FruitSize: Codable, Equatable, Sendable {
    public var emoji: String
    public var en: String
    public var vi: String

    public func name(_ language: ContentLanguage) -> String {
        language == .vi ? vi : en
    }
}

public struct WeekContent: Codable, Equatable, Sendable, Identifiable {
    public var week: Int
    /// Set to true by the reviewing obstetrician; Release builds hide unreviewed weeks.
    public var reviewed: Bool
    public var size: FruitSize
    /// Absent before week 8 (shown as "—").
    public var lengthCm: Double?
    public var weightG: Double?
    public var baby: LocalizedList
    public var mom: LocalizedList
    public var tips: LocalizedList
    /// "When to get care right away" — every item points to a doctor or maternity unit.
    public var warnings: LocalizedList

    public var id: Int { week }
}

/// A suggested check-up, e.g. the nuchal translucency scan in weeks 11–14.
public struct Milestone: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var fromWeek: Int
    public var toWeek: Int
    public var title: LocalizedText
    public var detail: LocalizedText
    public var reviewed: Bool
}

/// Root of `pregnancy-content.json`.
public struct PregnancyContent: Codable, Equatable, Sendable {
    public var version: Int
    public var sources: [String]
    public var weeks: [WeekContent]
    public var milestones: [Milestone]
}
```

`Packages/KickCore/Sources/KickCore/WeeklyContentLibrary.swift`:
```swift
import Foundation

/// Whether unreviewed content may be shown: everything in Debug/TestFlight
/// (`CONTENT_PREVIEW`), only doctor-reviewed content in App Store builds.
public enum ContentVisibility: Sendable, Equatable {
    case reviewedOnly
    case all
}

public enum WeekDisplay: Equatable, Sendable {
    /// `pendingReview` asks the UI to show the "pending doctor review" label.
    case content(WeekContent, pendingReview: Bool)
    /// Release build, week not reviewed yet: show "being updated" instead.
    case underReview(week: Int)
}

public struct WeeklyContentLibrary: Sendable {
    public static let weekRange = 4...42

    public let document: PregnancyContent
    private let weeksByNumber: [Int: WeekContent]

    public init(document: PregnancyContent) {
        self.document = document
        weeksByNumber = Dictionary(document.weeks.map { ($0.week, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public init(data: Data) throws {
        self.init(document: try JSONDecoder().decode(PregnancyContent.self, from: data))
    }

    public var sources: [String] { document.sources }

    public var milestones: [Milestone] {
        document.milestones.sorted { ($0.fromWeek, $0.toWeek, $0.id) < ($1.fromWeek, $1.toWeek, $1.id) }
    }

    public static func clampedWeek(_ week: Int) -> Int {
        min(max(week, weekRange.lowerBound), weekRange.upperBound)
    }

    /// Content for `week`, clamped to 4…42 (so weeks 43–44 show week 42).
    public func content(forWeek week: Int) -> WeekContent? {
        weeksByNumber[Self.clampedWeek(week)]
    }

    public func display(forWeek week: Int, visibility: ContentVisibility) -> WeekDisplay? {
        guard let entry = content(forWeek: week) else { return nil }
        if entry.reviewed { return .content(entry, pendingReview: false) }
        switch visibility {
        case .all: return .content(entry, pendingReview: true)
        case .reviewedOnly: return .underReview(week: entry.week)
        }
    }

    /// Milestones not yet over at `week` (including ones under way), soonest first.
    public func upcomingMilestones(atWeek week: Int, visibility: ContentVisibility = .all) -> [Milestone] {
        milestones.filter { $0.toWeek >= week && (visibility == .all || $0.reviewed) }
    }
}
```

`Packages/KickCore/Sources/KickCore/ContentValidator.swift`:
```swift
import Foundation

public enum ContentIssue: Equatable, Sendable {
    case unsupportedVersion(Int)
    case noSources
    case missingWeek(Int)
    case unexpectedWeek(Int)
    case duplicateWeek(Int)
    case weeksOutOfOrder
    /// `context` names the field, e.g. "week 7 baby.en" or "milestone nt-scan title.vi".
    case blankText(String)
    case tooFewItems(week: Int, section: String, language: ContentLanguage, minimum: Int)
    case translationCountMismatch(week: Int, section: String)
    case missingMeasurement(week: Int, field: String)
    case nonPositiveMeasurement(week: Int, field: String)
    case decreasingMeasurement(week: Int, field: String)
    case invalidMilestoneRange(id: String)
    case duplicateMilestoneID(String)
}

/// Structural rules for `pregnancy-content.json`, enforced by unit tests so a
/// broken file never ships (the app itself only logs and hides content).
public enum ContentValidator {
    public static let supportedVersion = 1
    public static let measurementsRequiredFromWeek = 8
    static let minimumItems: [(section: String, minimum: Int)] = [
        ("baby", 2), ("mom", 2), ("tips", 2), ("warnings", 1),
    ]

    public static func validate(
        _ content: PregnancyContent,
        requiredWeeks: ClosedRange<Int> = WeeklyContentLibrary.weekRange
    ) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        if content.version != supportedVersion { issues.append(.unsupportedVersion(content.version)) }
        if content.sources.isEmpty { issues.append(.noSources) }
        for source in content.sources where isBlank(source) { issues.append(.blankText("sources")) }
        issues += weekIssues(content.weeks, requiredWeeks: requiredWeeks)
        issues += measurementIssues(content.weeks.sorted { $0.week < $1.week })
        issues += milestoneIssues(content.milestones)
        return issues
    }

    private static func weekIssues(_ weeks: [WeekContent], requiredWeeks: ClosedRange<Int>) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        var seen = Set<Int>()
        for week in weeks {
            if !seen.insert(week.week).inserted { issues.append(.duplicateWeek(week.week)) }
            if !requiredWeeks.contains(week.week) { issues.append(.unexpectedWeek(week.week)) }
        }
        for number in requiredWeeks where !seen.contains(number) { issues.append(.missingWeek(number)) }
        let numbers = weeks.map(\.week)
        if numbers != numbers.sorted() { issues.append(.weeksOutOfOrder) }

        for week in weeks {
            let number = week.week
            let sizeFields = [("size.emoji", week.size.emoji), ("size.en", week.size.en), ("size.vi", week.size.vi)]
            for (field, text) in sizeFields where isBlank(text) {
                issues.append(.blankText("week \(number) \(field)"))
            }
            let sections = ["baby": week.baby, "mom": week.mom, "tips": week.tips, "warnings": week.warnings]
            for (section, minimum) in minimumItems {
                guard let list = sections[section] else { continue }
                for language in ContentLanguage.allCases {
                    let items = list.items(language)
                    if items.count < minimum {
                        issues.append(.tooFewItems(week: number, section: section, language: language, minimum: minimum))
                    }
                    if items.contains(where: isBlank) {
                        issues.append(.blankText("week \(number) \(section).\(language.rawValue)"))
                    }
                }
                if list.en.count != list.vi.count {
                    issues.append(.translationCountMismatch(week: number, section: section))
                }
            }
        }
        return issues
    }

    private static func measurementIssues(_ weeks: [WeekContent]) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let fields: [(name: String, value: (WeekContent) -> Double?)] = [
            ("lengthCm", { $0.lengthCm }), ("weightG", { $0.weightG }),
        ]
        for field in fields {
            var previous: Double?
            for week in weeks {
                guard let value = field.value(week) else {
                    if week.week >= measurementsRequiredFromWeek {
                        issues.append(.missingMeasurement(week: week.week, field: field.name))
                    }
                    continue
                }
                if value <= 0 { issues.append(.nonPositiveMeasurement(week: week.week, field: field.name)) }
                if let previous, value < previous {
                    issues.append(.decreasingMeasurement(week: week.week, field: field.name))
                }
                previous = value
            }
        }
        return issues
    }

    private static func milestoneIssues(_ milestones: [Milestone]) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        var ids = Set<String>()
        let allowed = WeeklyContentLibrary.weekRange
        for milestone in milestones {
            if isBlank(milestone.id) { issues.append(.blankText("milestone id")) }
            if !ids.insert(milestone.id).inserted { issues.append(.duplicateMilestoneID(milestone.id)) }
            if milestone.fromWeek > milestone.toWeek
                || !allowed.contains(milestone.fromWeek)
                || !allowed.contains(milestone.toWeek) {
                issues.append(.invalidMilestoneRange(id: milestone.id))
            }
            for language in ContentLanguage.allCases {
                if isBlank(milestone.title.text(language)) {
                    issues.append(.blankText("milestone \(milestone.id) title.\(language.rawValue)"))
                }
                if isBlank(milestone.detail.text(language)) {
                    issues.append(.blankText("milestone \(milestone.id) detail.\(language.rawValue)"))
                }
            }
        }
        return issues
    }

    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

- [ ] **Step 4: Chạy test, xác nhận pass (resource của test target chạy được với Command Line Tools)**

Run: `scripts/test-core.sh`
Expected: PASS toàn bộ. Nếu `fixtureIsValid` fail với `MissingFixture`, nghĩa là `Bundle.module` của test target không thấy thư mục `Fixtures` — kiểm tra `resources: [.copy("Fixtures")]` và đường dẫn `Tests/KickCoreTests/Fixtures/content-fixture.json`, không được bỏ qua.

- [ ] **Step 5: Commit, push, CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): add pregnancy content model, library and validator

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---
### Task 5: Soạn `pregnancy-content.json` (tuần 4–42 + mốc khám) và nạp qua `Bundle.module`

> **Ngoại lệ "không placeholder" duy nhất của plan này.** Nội dung y tế (39 tuần × 2 ngôn ngữ + 10 mốc khám) là **dữ liệu được soạn**, không phải code, nên plan **không** chép toàn văn. Thay vào đó, task này cho schema chính xác, các luật mà test trên file thật bắt buộc, khung tham chiếu (số đo, mốc khám) và hướng dẫn biên tập. Mọi luật cấu trúc được kiểm bằng `BundledContentTests` + `ContentValidator` chạy local; chất lượng y khoa do bác sĩ sản khoa duyệt trước khi phát hành (Task 14).

**Files:**
- Modify: `Packages/KickCore/Package.swift` (target `KickCore` thêm `resources: [.process("Resources")]`)
- Create: `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`, `Packages/KickCore/Sources/KickCore/WeeklyContentLibrary+Bundle.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/BundledContentTests.swift`

**Interfaces:**
- Consumes: `WeeklyContentLibrary(data:)`, `.document`, `.content(forWeek:)`, `.milestones`, `.sources`, `ContentValidator.validate(_:requiredWeeks:)`, các kiểu nội dung ở Task 4.
- Produces: resource `pregnancy-content.json` trong bundle của `KickCore`; `public enum ContentLoadError: Error, Equatable { case resourceMissing }`; `extension WeeklyContentLibrary { public static let resourceName: String /* "pregnancy-content" */; public static func bundled() throws -> WeeklyContentLibrary; public static func loadBundled() -> WeeklyContentLibrary? }` (`loadBundled` log bằng `os.Logger` và trả `nil` khi lỗi, không crash). Id mốc khám cố định (dùng ở Task 13): `confirm-pregnancy`, `nt-scan`, `triple-test`, `anomaly-scan`, `gdm-screening`, `tetanus-pertussis`, `growth-scan`, `gbs-test`, `weekly-checks`, `post-dates`.

#### Schema (giống spec §3.3, khớp các kiểu ở Task 4)

```json
{
  "version": 1,
  "sources": ["<tên tài liệu nguồn>", "..."],
  "weeks": [
    {
      "week": 24,
      "reviewed": false,
      "size": { "emoji": "🌽", "en": "an ear of corn", "vi": "một bắp ngô" },
      "lengthCm": 30.0,
      "weightG": 600,
      "baby":     { "en": ["…", "…"], "vi": ["…", "…"] },
      "mom":      { "en": ["…", "…"], "vi": ["…", "…"] },
      "tips":     { "en": ["…", "…"], "vi": ["…", "…"] },
      "warnings": { "en": ["…"],      "vi": ["…"] }
    }
  ],
  "milestones": [
    {
      "id": "nt-scan", "fromWeek": 11, "toWeek": 14,
      "title":  { "en": "…", "vi": "Siêu âm đo độ mờ da gáy" },
      "detail": { "en": "…", "vi": "…" },
      "reviewed": false
    }
  ]
}
```
(`…` ở khối schema trên chỉ minh họa hình dạng; file thật phải có câu hoàn chỉnh.)

#### Luật hoàn chỉnh (test bắt buộc — fail là chưa xong)

1. `version == 1`; `sources` không rỗng và có tên của cả **WHO**, **ACOG**, **NHS**, **Bộ Y tế** (chuỗi chứa đúng các cụm này).
2. `weeks` có đúng các tuần `4…42`, mỗi tuần một lần, theo thứ tự tăng dần.
3. Mỗi tuần: `baby`, `mom`, `tips` có **≥ 2** ý, `warnings` có **≥ 1** ý, ở cả `en` và `vi`; số ý `en` bằng số ý `vi` trong từng mục (ý thứ i của `vi` là bản dịch của ý thứ i của `en`); không chuỗi rỗng/chỉ khoảng trắng.
4. `size.emoji`, `size.en`, `size.vi` không rỗng; `size.en` khác nhau giữa mọi tuần.
5. `lengthCm`/`weightG`: **bỏ hẳn khóa** ở tuần 4–7 (hiển thị "—"); **bắt buộc** từ tuần 8; > 0; không giảm theo tuần.
6. Số đo nằm trong khoảng điển hình: tuần 12 dài 4,5–7 cm, nặng 10–25 g; tuần 20 dài 15–27 cm, nặng 250–350 g; tuần 24 dài 28–33 cm, nặng 500–700 g; tuần 28 dài 35–39 cm, nặng 900–1200 g; tuần 40 dài 48–54 cm, nặng 3100–3700 g.
7. **Mọi** ý trong `warnings.en` chứa ít nhất một từ: `doctor`, `midwife`, `maternity`, `hospital`, `emergency` (không phân biệt hoa thường). **Mọi** ý trong `warnings.vi` chứa ít nhất một cụm: `bác sĩ`, `cơ sở y tế`, `bệnh viện`, `cấp cứu`, `115`.
8. Mọi chuỗi tiếng Việt (`size.vi`, mọi ý `vi`, `title.vi`, `detail.vi` của mốc) có ít nhất một ký tự có dấu (bắt lỗi gõ không dấu).
9. `milestones` có đúng 10 mốc với id và khoảng tuần sau (theo spec §3.3):

| id | fromWeek–toWeek | Nội dung |
|---|---|---|
| `confirm-pregnancy` | 6–8 | Khám xác nhận thai (siêu âm xác định thai trong tử cung, tim thai, tuổi thai) |
| `nt-scan` | 11–14 | Siêu âm đo độ mờ da gáy + double test |
| `triple-test` | 15–18 | Triple test |
| `anomaly-scan` | 18–22 | Siêu âm hình thái |
| `gdm-screening` | 24–28 | Tầm soát tiểu đường thai kỳ (nghiệm pháp dung nạp glucose) |
| `tetanus-pertussis` | 27–36 | Tiêm phòng uốn ván/ho gà theo hướng dẫn của cơ sở y tế |
| `growth-scan` | 30–32 | Siêu âm tăng trưởng |
| `gbs-test` | 35–37 | Cấy liên cầu khuẩn nhóm B (GBS) |
| `weekly-checks` | 37–40 | Khám hằng tuần từ tuần 37 |
| `post-dates` | 40–42 | Theo dõi khi quá ngày dự sinh |

10. Không phải test mà là yêu cầu phát hành (kiểm ở Step 7): **mọi** `reviewed` là `false`.

#### Số đo tham chiếu (dùng các giá trị này; nguồn: bảng chiều dài/cân nặng thai nhi phổ biến — đầu-mông tới tuần 19, đầu-gót từ tuần 20 — nên có bước nhảy chiều dài ở tuần 20)

| Tuần | cm | g | Tuần | cm | g | Tuần | cm | g |
|---|---|---|---|---|---|---|---|---|
| 8 | 1.6 | 1 | 20 | 25.6 | 300 | 32 | 42.4 | 1702 |
| 9 | 2.3 | 2 | 21 | 26.7 | 360 | 33 | 43.7 | 1918 |
| 10 | 3.1 | 4 | 22 | 27.8 | 430 | 34 | 45.0 | 2146 |
| 11 | 4.1 | 7 | 23 | 28.9 | 501 | 35 | 46.2 | 2383 |
| 12 | 5.4 | 14 | 24 | 30.0 | 600 | 36 | 47.4 | 2622 |
| 13 | 7.4 | 23 | 25 | 34.6 | 660 | 37 | 48.6 | 2859 |
| 14 | 8.7 | 43 | 26 | 35.6 | 760 | 38 | 49.8 | 3083 |
| 15 | 10.1 | 70 | 27 | 36.6 | 875 | 39 | 50.7 | 3288 |
| 16 | 11.6 | 100 | 28 | 37.6 | 1005 | 40 | 51.2 | 3462 |
| 17 | 13.0 | 140 | 29 | 38.6 | 1153 | 41 | 51.7 | 3597 |
| 18 | 14.2 | 190 | 30 | 39.9 | 1319 | 42 | 51.7 | 3685 |
| 19 | 15.3 | 240 | 31 | 41.1 | 1502 | | | |

#### Hướng dẫn biên tập

- **Nguồn:** chỉ dựa trên khuyến nghị công khai của WHO (antenatal care recommendations), ACOG, NHS (Your pregnancy and baby guide) và Bộ Y tế Việt Nam (Hướng dẫn quốc gia về các dịch vụ chăm sóc sức khỏe sinh sản). `sources` liệt kê tên tài liệu cụ thể. Khi các nguồn khác nhau (ví dụ lịch tiêm), viết theo hướng "theo hướng dẫn của bác sĩ/cơ sở y tế nơi mẹ khám", không chọn một lịch cứng.
- **Giọng văn:** bình tĩnh, ấm áp, không gây hoảng sợ, không phán xét; câu ngắn (≤ 25 từ), ngôi "mẹ"/"bé" trong tiếng Việt, "you"/"your baby" trong tiếng Anh. Không đưa liều thuốc, không chẩn đoán, không hứa hẹn kết quả.
- **`baby`:** sự phát triển điển hình của bé tuần đó (cơ quan, giác quan, cử động). **`mom`:** thay đổi/triệu chứng thường gặp của mẹ. **`tips`:** việc nên làm cụ thể (ăn uống, vận động, giấc ngủ, khám, chuẩn bị); hai ý đầu là quan trọng nhất vì trang chủ chỉ hiện 2 ý đầu. Từ tuần 28 có ít nhất một ý nhắc làm quen nhịp cử động của bé và đếm cử động mỗi ngày.
- **`warnings`** ("Khi nào cần đi khám ngay"): dấu hiệu cần được chăm sóc y tế ngay phù hợp giai đoạn (ra máu, đau bụng dữ dội, đau đầu dữ dội/nhìn mờ, sốt, ra nước âm đạo, bé cử động ít hơn bình thường từ khoảng tuần 24–28, co thắt đều trước tuần 37…). **Mọi ý** phải kết thúc bằng hướng dẫn liên hệ bác sĩ/cơ sở y tế/bệnh viện (luật 7). Không dùng từ ngữ gây sợ hãi như "nguy hiểm tính mạng".
- **Tiếng Việt:** tự nhiên, đúng chính tả và dấu, dùng thuật ngữ quen thuộc ở Việt Nam ("siêu âm hình thái", "đái tháo đường thai kỳ"/"tiểu đường thai kỳ", "sổ khám thai", "ốm nghén"); số thập phân trong câu dùng dấu phẩy. Không dịch máy từng chữ; giữ nghĩa tương đương với `en`.
- **So sánh kích thước:** emoji phải mô tả đúng vật được nêu tên (được dùng lại emoji nếu tên khác nhau, ví dụ 🌱 cho "hạt anh túc" và "hạt vừng"); kích thước vật so sánh tăng dần, tương ứng số đo của tuần. Neo bắt buộc: tuần 7 🫐 việt quất, tuần 16 🥑 quả bơ, tuần 20 🍌 quả chuối, tuần 24 🌽 bắp ngô (như spec), tuần 28 🍆 cà tím, tuần 33 🍍 quả dứa, tuần 40 🍉 dưa hấu nhỏ. Chỉ dùng emoji có từ iOS 17 trở xuống (không dùng 🍋‍🟩).
- **Mốc khám:** `title` ngắn (≤ 6 từ), `detail` 1–2 câu giải thích mục đích; không nêu chi phí, không nêu tên bệnh viện.

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/BundledContentTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

/// Rules every shipped `pregnancy-content.json` must meet (see plan Task 5).
struct BundledContentTests {
    static let requiredMilestones: [String: ClosedRange<Int>] = [
        "confirm-pregnancy": 6...8,
        "nt-scan": 11...14,
        "triple-test": 15...18,
        "anomaly-scan": 18...22,
        "gdm-screening": 24...28,
        "tetanus-pertussis": 27...36,
        "growth-scan": 30...32,
        "gbs-test": 35...37,
        "weekly-checks": 37...40,
        "post-dates": 40...42,
    ]
    static let careWordsEN = ["doctor", "midwife", "maternity", "hospital", "emergency"]
    static let careWordsVI = ["bác sĩ", "cơ sở y tế", "bệnh viện", "cấp cứu", "115"]
    static let typicalMeasurements: [Int: (length: ClosedRange<Double>, weight: ClosedRange<Double>)] = [
        12: (4.5...7, 10...25),
        20: (15...27, 250...350),
        24: (28...33, 500...700),
        28: (35...39, 900...1200),
        40: (48...54, 3100...3700),
    ]

    let library: WeeklyContentLibrary

    init() throws {
        library = try WeeklyContentLibrary.bundled()
    }

    @Test func bundledContentPassesValidation() {
        let issues = ContentValidator.validate(library.document)
        #expect(issues.isEmpty, "\(issues)")
    }

    @Test func coversEveryWeekFrom4To42() {
        #expect(library.document.weeks.map(\.week) == Array(4...42))
    }

    @Test func lookupClampsToTheContentRange() {
        #expect(library.content(forWeek: 1)?.week == 4)
        #expect(library.content(forWeek: 24)?.week == 24)
        #expect(library.content(forWeek: 44)?.week == 42)
    }

    @Test func milestonesMatchTheSpecSchedule() {
        let actual = Dictionary(library.milestones.map { ($0.id, $0.fromWeek...$0.toWeek) }, uniquingKeysWith: { first, _ in first })
        #expect(actual == Self.requiredMilestones)
        #expect(library.milestones.count == Self.requiredMilestones.count)
    }

    @Test func everyWarningPointsToCare() {
        for week in library.document.weeks {
            for item in week.warnings.en {
                #expect(Self.careWordsEN.contains { item.localizedCaseInsensitiveContains($0) }, "week \(week.week): \(item)")
            }
            for item in week.warnings.vi {
                #expect(Self.careWordsVI.contains { item.localizedCaseInsensitiveContains($0) }, "week \(week.week): \(item)")
            }
        }
    }

    @Test func vietnameseTextHasDiacritics() {
        var texts: [String] = []
        for week in library.document.weeks {
            texts.append(week.size.vi)
            texts += week.baby.vi + week.mom.vi + week.tips.vi + week.warnings.vi
        }
        for milestone in library.milestones {
            texts += [milestone.title.vi, milestone.detail.vi]
        }
        let unaccented = texts.filter { !$0.unicodeScalars.contains { $0.value > 127 } }
        #expect(unaccented.isEmpty, "\(unaccented)")
    }

    @Test func sizeComparisonsAreDistinct() {
        let names = library.document.weeks.map(\.size.en)
        #expect(Set(names).count == names.count)
    }

    @Test func measurementsAreInTypicalRanges() {
        for (week, expected) in Self.typicalMeasurements {
            let content = library.content(forWeek: week)
            #expect(content?.lengthCm.map(expected.length.contains) == true, "week \(week) length")
            #expect(content?.weightG.map(expected.weight.contains) == true, "week \(week) weight")
        }
    }

    @Test func sourcesNameTheFourGuidelineBodies() {
        let joined = library.sources.joined(separator: " | ")
        for body in ["WHO", "ACOG", "NHS", "Bộ Y tế"] {
            #expect(joined.contains(body), "missing source: \(body)")
        }
    }
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `scripts/test-core.sh --filter BundledContentTests`
Expected: FAIL khi biên dịch — `type 'WeeklyContentLibrary' has no member 'bundled'`.

- [ ] **Step 3: Viết loader và khai báo resource**

Trong `Packages/KickCore/Package.swift`, đổi dòng target thành:
```swift
        .target(name: "KickCore", resources: [.process("Resources")]),
```

`Packages/KickCore/Sources/KickCore/WeeklyContentLibrary+Bundle.swift`:
```swift
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "content")

public enum ContentLoadError: Error, Equatable {
    case resourceMissing
}

extension WeeklyContentLibrary {
    public static let resourceName = "pregnancy-content"

    /// The content bundled in KickCore's resources. Throws if it is missing or malformed.
    public static func bundled() throws -> WeeklyContentLibrary {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            throw ContentLoadError.resourceMissing
        }
        return try WeeklyContentLibrary(data: Data(contentsOf: url))
    }

    /// Like `bundled()`, but logs and returns nil instead of throwing, so the app
    /// hides the content cards while the week calculation keeps working.
    public static func loadBundled() -> WeeklyContentLibrary? {
        do {
            return try bundled()
        } catch {
            logger.error("Loading pregnancy content failed: \(error.localizedDescription)")
            return nil
        }
    }
}
```

- [ ] **Step 4: Soạn `pregnancy-content.json` theo từng đợt, kiểm cú pháp sau mỗi đợt**

Tạo `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json` (UTF-8, thụt lề 2 dấu cách) theo schema, luật và hướng dẫn ở trên, theo thứ tự: (a) `version`, `sources`, tuần 4–13; (b) tuần 14–27; (c) tuần 28–42; (d) 10 mốc khám. Sau mỗi đợt chạy:
```bash
python3 -m json.tool Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json > /dev/null && echo OK
```
Expected: `OK`.

- [ ] **Step 5: Chạy test trên file thật, xác nhận pass — đồng thời chứng minh resource đọc được bằng Command Line Tools**

Run: `scripts/test-core.sh --filter BundledContentTests`
Expected: PASS cả 9 test. Nếu `init()` ném `ContentLoadError.resourceMissing`, `Bundle.module` không chứa file → kiểm tra `resources: [.process("Resources")]` và đường dẫn file (không được chuyển sang đọc bằng đường dẫn tuyệt đối). Nếu `bundledContentPassesValidation` fail, thông điệp liệt kê từng `ContentIssue` → sửa JSON đến khi rỗng.

- [ ] **Step 6: Đọc lại nội dung với vai trò biên tập viên**

Mở file và kiểm tra bằng mắt cho từng tuần: (1) `en`/`vi` cùng nghĩa, cùng thứ tự; (2) tiếng Việt tự nhiên, đúng dấu, không lẫn tiếng Anh; (3) không có câu gây hoảng sợ hay khẳng định chẩn đoán; (4) emoji khớp tên vật so sánh; (5) tips tuần 28–42 có ý về đếm cử động. Sửa trực tiếp, chạy lại Step 5.

- [ ] **Step 7: Xác nhận mọi `reviewed` là `false` và toàn bộ test local xanh**

```bash
python3 - <<'PY'
import json
d = json.load(open("Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json", encoding="utf-8"))
flagged = [w["week"] for w in d["weeks"] if w["reviewed"] is not False] + [m["id"] for m in d["milestones"] if m["reviewed"] is not False]
print("weeks:", len(d["weeks"]), "milestones:", len(d["milestones"]), "reviewed != false:", flagged)
assert not flagged
PY
scripts/test-core.sh
```
Expected: `weeks: 39 milestones: 10 reviewed != false: []`, rồi toàn bộ test PASS.

- [ ] **Step 8: Commit, push, CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(content): add bilingual week 4-42 pregnancy content and milestones

All entries are reviewed: false until an obstetrician signs them off.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED` (CI chạy lại `BundledContentTests` bằng Xcode, xác nhận resource cũng được xử lý đúng ở đó).

---

### Task 6: Nhắc lịch hẹn (mở rộng NotificationScheduler)

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/NotificationScheduler.swift` (`private let center` → `let center`; thêm `isDenied()`)
- Create: `Packages/KickCore/Sources/KickCore/AppointmentReminders.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/AppointmentRemindersTests.swift`

**Interfaces:**
- Consumes: `NotificationScheduler`, `NotificationCenterClient`, `NotificationText.makeContent()` (internal), `FakeNotificationCenter`.
- Produces (trên `NotificationScheduler`):
  - `public static let appointmentReminderPrefix = "appointment-"`, `public static let appointmentReminderHour = 9`, `public static func appointmentReminderID(for id: UUID) -> String`.
  - `public static func appointmentReminderFireDate(for date: Date, calendar: Calendar = .current) -> Date?` (9:00 ngày hôm trước).
  - `@discardableResult public func scheduleAppointmentReminder(id: UUID, date: Date, title: String, now: Date, text: NotificationText, calendar: Calendar = .current) async throws -> Bool` — thay nhắc cũ cùng id; nội dung: `title = text.title`, `subtitle = title` (tên lịch hẹn), `body = text.body`; trả `false` (và xóa nhắc cũ) khi giờ nhắc ≤ `now`.
  - `public func cancelAppointmentReminder(id: UUID)`, `public func pendingAppointmentReminderIDs() async -> Set<UUID>`, `public func isDenied() async -> Bool` (chỉ `true` khi người dùng đã tắt, không phải khi chưa hỏi).

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/AppointmentRemindersTests.swift`:
```swift
import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct AppointmentRemindersTests {
    let center = FakeNotificationCenter()
    let text = NotificationText(title: "Check-up tomorrow", body: "Bring your records")
    let now = date("2026-10-02T12:00:00Z")
    var scheduler: NotificationScheduler { NotificationScheduler(center: center) }

    @Test func remindsAt9OnTheDayBefore() async throws {
        let id = UUID()
        let scheduled = try await scheduler.scheduleAppointmentReminder(
            id: id, date: date("2026-10-20T14:30:00Z"), title: "Anomaly scan", now: now, text: text, calendar: utcCalendar
        )
        #expect(scheduled)
        let request = try #require(center.added.first)
        #expect(request.identifier == "appointment-\(id.uuidString)")
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)
        let components = trigger.dateComponents
        #expect([components.year, components.month, components.day, components.hour, components.minute] == [2026, 10, 19, 9, 0])
        #expect(request.content.title == "Check-up tomorrow")
        #expect(request.content.subtitle == "Anomaly scan")
        #expect(request.content.body == "Bring your records")
    }

    @Test func dayBeforeCrossesMonthBoundary() async throws {
        try await scheduler.scheduleAppointmentReminder(
            id: UUID(), date: date("2026-11-01T08:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar
        )
        let trigger = try #require(center.added.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.month == 10)
        #expect(trigger.dateComponents.day == 31)
    }

    @Test func skippedWhenReminderTimeHasPassed() async throws {
        let id = UUID()
        // Tomorrow 08:00 → reminder today 09:00, already past at 12:00.
        let scheduled = try await scheduler.scheduleAppointmentReminder(
            id: id, date: date("2026-10-03T08:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar
        )
        #expect(scheduled == false)
        #expect(center.added.isEmpty)
        #expect(center.removed == [NotificationScheduler.appointmentReminderID(for: id)])
    }

    @Test func reminderExactlyAtNowIsSkipped() async throws {
        let scheduled = try await scheduler.scheduleAppointmentReminder(
            id: UUID(), date: date("2026-10-03T15:00:00Z"), title: "Scan",
            now: date("2026-10-02T09:00:00Z"), text: text, calendar: utcCalendar
        )
        #expect(scheduled == false)
    }

    @Test func reschedulingReplacesTheReminder() async throws {
        let id = UUID()
        try await scheduler.scheduleAppointmentReminder(id: id, date: date("2026-10-20T10:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar)
        try await scheduler.scheduleAppointmentReminder(id: id, date: date("2026-10-25T10:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar)
        #expect(center.added.count == 1)
        #expect((center.added[0].trigger as? UNCalendarNotificationTrigger)?.dateComponents.day == 24)
    }

    @Test func cancelUsesTheAppointmentID() {
        let id = UUID()
        scheduler.cancelAppointmentReminder(id: id)
        #expect(center.removed == ["appointment-\(id.uuidString)"])
    }

    @Test func pendingIDsListOnlyAppointmentReminders() async throws {
        let a = UUID()
        let b = UUID()
        for id in [a, b] {
            try await scheduler.scheduleAppointmentReminder(id: id, date: date("2026-10-20T10:00:00Z"), title: "Scan", now: now, text: text, calendar: utcCalendar)
        }
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 0, text: text)
        try await scheduler.scheduleOverdueAlert(sessionID: UUID(), startedAt: now, now: now, text: text)
        #expect(await scheduler.pendingAppointmentReminderIDs() == [a, b])
    }

    @Test func deniedOnlyWhenTheUserTurnedNotificationsOff() async {
        center.status = .notDetermined
        #expect(await scheduler.isDenied() == false)
        center.status = .denied
        #expect(await scheduler.isDenied())
        center.status = .authorized
        #expect(await scheduler.isDenied() == false)
    }
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `scripts/test-core.sh --filter AppointmentRemindersTests`
Expected: FAIL khi biên dịch — `value of type 'NotificationScheduler' has no member 'scheduleAppointmentReminder'`.

- [ ] **Step 3: Viết code**

Trong `Packages/KickCore/Sources/KickCore/NotificationScheduler.swift`:
- đổi `    private let center: NotificationCenterClient` thành `    let center: NotificationCenterClient` (để extension ở file khác dùng được);
- thêm ngay sau `isAuthorized()`:
```swift
    /// True only when the user has explicitly turned notifications off
    /// (not when they have never been asked).
    public func isDenied() async -> Bool {
        await center.authorizationStatus() == .denied
    }
```

`Packages/KickCore/Sources/KickCore/AppointmentReminders.swift`:
```swift
import Foundation
@preconcurrency import UserNotifications

/// Day-before reminders for appointments. Only `AppointmentCoordinator` calls these.
extension NotificationScheduler {
    public static let appointmentReminderPrefix = "appointment-"
    public static let appointmentReminderHour = 9

    public static func appointmentReminderID(for id: UUID) -> String {
        "\(appointmentReminderPrefix)\(id.uuidString)"
    }

    /// 9:00 on the day before `date`.
    public static func appointmentReminderFireDate(for date: Date, calendar: Calendar = .current) -> Date? {
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) else { return nil }
        return calendar.date(bySettingHour: appointmentReminderHour, minute: 0, second: 0, of: dayBefore)
    }

    /// Schedules (or replaces) the reminder for an appointment at 9:00 the day
    /// before. Returns false — after removing any stale reminder — when that
    /// time is not in the future.
    @discardableResult
    public func scheduleAppointmentReminder(
        id: UUID,
        date: Date,
        title: String,
        now: Date,
        text: NotificationText,
        calendar: Calendar = .current
    ) async throws -> Bool {
        let identifier = Self.appointmentReminderID(for: id)
        center.removePending(ids: [identifier])
        guard let fireDate = Self.appointmentReminderFireDate(for: date, calendar: calendar), fireDate > now else {
            return false
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let content = text.makeContent()
        content.subtitle = title
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        return true
    }

    public func cancelAppointmentReminder(id: UUID) {
        center.removePending(ids: [Self.appointmentReminderID(for: id)])
    }

    /// Appointment ids that currently have a pending reminder.
    public func pendingAppointmentReminderIDs() async -> Set<UUID> {
        let prefix = Self.appointmentReminderPrefix
        return Set(await center.pendingRequestIDs().compactMap { identifier -> UUID? in
            guard identifier.hasPrefix(prefix) else { return nil }
            return UUID(uuidString: String(identifier.dropFirst(prefix.count)))
        })
    }
}
```

- [ ] **Step 4: Chạy test, xác nhận pass**

Run: `scripts/test-core.sh`
Expected: PASS toàn bộ (kể cả `NotificationSchedulerTests` và `KickCoordinatorTests` cũ).

- [ ] **Step 5: Commit, push, CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): schedule appointment reminders at 9:00 the day before

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 7: AppointmentRecord, AppointmentRepository, luật Sắp tới/Đã qua, ngày điền sẵn

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/Appointments.swift`, `Packages/KickCore/Sources/KickCore/AppointmentPrefill.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/AppointmentRulesTests.swift`, `Packages/KickCore/Tests/KickCoreTests/AppointmentPrefillTests.swift`

**Interfaces:**
- Consumes: `Milestone` (Task 4), `PregnancyDates.startOfWeek(_:dueDate:calendar:)` (Task 2).
- Produces:
  - `public struct AppointmentRecord: Equatable, Sendable, Identifiable { public let id: UUID; public var date: Date; public var title: String; public var note: String; public var isDone: Bool; public var milestoneID: String?; public init(id: UUID = UUID(), date: Date, title: String, note: String = "", isDone: Bool = false, milestoneID: String? = nil) }`.
  - `public enum AppointmentRepositoryError: Error, Equatable { case notFound }`.
  - `@MainActor public protocol AppointmentRepository: AnyObject { func appointment(id: UUID) throws -> AppointmentRecord?; func upcoming(now: Date) throws -> [AppointmentRecord]; func past(now: Date) throws -> [AppointmentRecord]; func add(_ appointment: AppointmentRecord) throws; func update(_ appointment: AppointmentRecord) throws; func delete(id: UUID) throws; func markDone(id: UUID) throws -> AppointmentRecord? }` — `update` ném `.notFound` khi không có id; `delete` không làm gì khi không có id; `markDone` trả `nil` khi không có id.
  - `public enum AppointmentRules { static func isUpcoming(_:now:calendar:) -> Bool; static func upcoming(_:now:calendar:) -> [AppointmentRecord]; static func past(_:now:calendar:) -> [AppointmentRecord]; static func wantsReminder(_:now:) -> Bool }` (tất cả `public`, `calendar: Calendar = .current`). Sắp tới = chưa khám **và** từ đầu ngày hôm nay trở đi (sớm nhất trước); Đã qua = phần còn lại (gần nhất trước).
  - `public enum AppointmentPrefill { public static let defaultHour = 9; public static func nextDefaultDate(now: Date, calendar: Calendar = .current) -> Date; public static func suggestedDate(for milestone: Milestone, dueDate: Date?, now: Date, calendar: Calendar = .current) -> Date }`.

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/AppointmentRulesTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct AppointmentRulesTests {
    let now = date("2026-10-02T12:00:00Z")

    private func appointment(_ iso: String, isDone: Bool = false) -> AppointmentRecord {
        AppointmentRecord(date: date(iso), title: iso, isDone: isDone)
    }

    @Test func todayAndLaterAreUpcomingUntilDone() {
        #expect(AppointmentRules.isUpcoming(appointment("2026-10-02T08:00:00Z"), now: now, calendar: utcCalendar))
        #expect(AppointmentRules.isUpcoming(appointment("2026-10-20T08:00:00Z"), now: now, calendar: utcCalendar))
        #expect(AppointmentRules.isUpcoming(appointment("2026-10-01T23:00:00Z"), now: now, calendar: utcCalendar) == false)
        #expect(AppointmentRules.isUpcoming(appointment("2026-10-20T08:00:00Z", isDone: true), now: now, calendar: utcCalendar) == false)
    }

    @Test func upcomingIsSoonestFirstAndPastMostRecentFirst() {
        let later = appointment("2026-11-01T08:00:00Z")
        let soon = appointment("2026-10-05T08:00:00Z")
        let lastWeek = appointment("2026-09-25T08:00:00Z")
        let longAgo = appointment("2026-08-01T08:00:00Z")
        let done = appointment("2026-10-10T08:00:00Z", isDone: true)
        let all = [longAgo, later, done, soon, lastWeek]
        #expect(AppointmentRules.upcoming(all, now: now, calendar: utcCalendar) == [soon, later])
        #expect(AppointmentRules.past(all, now: now, calendar: utcCalendar) == [done, lastWeek, longAgo])
    }

    @Test func remindersOnlyForFutureAppointmentsNotDone() {
        #expect(AppointmentRules.wantsReminder(appointment("2026-10-20T08:00:00Z"), now: now))
        #expect(AppointmentRules.wantsReminder(appointment("2026-10-02T08:00:00Z"), now: now) == false)
        #expect(AppointmentRules.wantsReminder(appointment("2026-10-20T08:00:00Z", isDone: true), now: now) == false)
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/AppointmentPrefillTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct AppointmentPrefillTests {
    let now = date("2026-10-02T12:00:00Z")   // 24w3d for `due`
    let due = date("2027-01-19T12:00:00Z")

    private func milestone(_ from: Int, _ to: Int) -> Milestone {
        Milestone(
            id: "m-\(from)", fromWeek: from, toWeek: to,
            title: LocalizedText(en: "M", vi: "M"), detail: LocalizedText(en: "D", vi: "D"), reviewed: false
        )
    }

    @Test func newAppointmentsDefaultToTomorrowAt9() {
        #expect(AppointmentPrefill.nextDefaultDate(now: now, calendar: utcCalendar) == date("2026-10-03T09:00:00Z"))
    }

    @Test func futureMilestoneStartsOnItsFirstWeekAt9() {
        // Week 30 starts 70 days before the due date.
        #expect(AppointmentPrefill.suggestedDate(for: milestone(30, 32), dueDate: due, now: now, calendar: utcCalendar)
            == date("2026-11-10T09:00:00Z"))
    }

    @Test func milestoneAlreadyUnderwayFallsBackToTomorrow() {
        #expect(AppointmentPrefill.suggestedDate(for: milestone(24, 28), dueDate: due, now: now, calendar: utcCalendar)
            == date("2026-10-03T09:00:00Z"))
    }

    @Test func withoutDueDateFallsBackToTomorrow() {
        #expect(AppointmentPrefill.suggestedDate(for: milestone(30, 32), dueDate: nil, now: now, calendar: utcCalendar)
            == date("2026-10-03T09:00:00Z"))
    }
}
```

- [ ] **Step 2: Chạy test, xác nhận fail**

Run: `scripts/test-core.sh --filter "AppointmentRulesTests|AppointmentPrefillTests"`
Expected: FAIL khi biên dịch — `cannot find 'AppointmentRecord' in scope`.

- [ ] **Step 3: Viết code**

`Packages/KickCore/Sources/KickCore/Appointments.swift`:
```swift
import Foundation

/// A check-up the mother added (value snapshot of the SwiftData `Appointment`).
public struct AppointmentRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var date: Date
    public var title: String
    public var note: String
    public var isDone: Bool
    /// The suggested milestone this was created from, if any.
    public var milestoneID: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        note: String = "",
        isDone: Bool = false,
        milestoneID: String? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.note = note
        self.isDone = isDone
        self.milestoneID = milestoneID
    }
}

public enum AppointmentRepositoryError: Error, Equatable {
    case notFound
}

/// Storage for appointments. Implementations only store: reminders are kept
/// in step by `AppointmentCoordinator`.
@MainActor
public protocol AppointmentRepository: AnyObject {
    func appointment(id: UUID) throws -> AppointmentRecord?
    /// Not done and on or after the start of today, soonest first.
    func upcoming(now: Date) throws -> [AppointmentRecord]
    /// Done, or before today, most recent first.
    func past(now: Date) throws -> [AppointmentRecord]
    func add(_ appointment: AppointmentRecord) throws
    /// Throws `AppointmentRepositoryError.notFound` when no appointment has that id.
    func update(_ appointment: AppointmentRecord) throws
    /// No-op when no appointment has that id (it may already be gone via iCloud).
    func delete(id: UUID) throws
    /// Returns nil when no appointment has that id.
    func markDone(id: UUID) throws -> AppointmentRecord?
}

public enum AppointmentRules {
    /// An appointment stays "upcoming" for the whole day it falls on, so the
    /// mother can still mark it done after the visit.
    public static func isUpcoming(_ appointment: AppointmentRecord, now: Date, calendar: Calendar = .current) -> Bool {
        !appointment.isDone && appointment.date >= calendar.startOfDay(for: now)
    }

    public static func upcoming(_ all: [AppointmentRecord], now: Date, calendar: Calendar = .current) -> [AppointmentRecord] {
        all.filter { isUpcoming($0, now: now, calendar: calendar) }.sorted { $0.date < $1.date }
    }

    public static func past(_ all: [AppointmentRecord], now: Date, calendar: Calendar = .current) -> [AppointmentRecord] {
        all.filter { !isUpcoming($0, now: now, calendar: calendar) }.sorted { $0.date > $1.date }
    }

    /// Whether a day-before reminder should exist (the scheduler still skips
    /// one whose 9:00 has already passed).
    public static func wantsReminder(_ appointment: AppointmentRecord, now: Date) -> Bool {
        !appointment.isDone && appointment.date > now
    }
}
```

`Packages/KickCore/Sources/KickCore/AppointmentPrefill.swift`:
```swift
import Foundation

/// Dates pre-filled in the "add check-up" sheet.
public enum AppointmentPrefill {
    public static let defaultHour = 9

    /// Tomorrow at 9:00.
    public static func nextDefaultDate(now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    /// 9:00 on the first day of the milestone's week range, or tomorrow at
    /// 9:00 when that day has passed (or the due date is unknown).
    public static func suggestedDate(for milestone: Milestone, dueDate: Date?, now: Date, calendar: Calendar = .current) -> Date {
        let earliest = nextDefaultDate(now: now, calendar: calendar)
        guard let dueDate else { return earliest }
        let weekStart = PregnancyDates.startOfWeek(milestone.fromWeek, dueDate: dueDate, calendar: calendar)
        let candidate = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: weekStart) ?? weekStart
        return max(candidate, earliest)
    }
}
```

- [ ] **Step 4: Chạy test, xác nhận pass**

Run: `scripts/test-core.sh`
Expected: PASS toàn bộ.

- [ ] **Step 5: Commit, push, CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): add appointment record, repository protocol and rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 8: AppointmentCoordinator

Cùng mẫu với `KickCoordinator`: `@MainActor @Observable`, `failure: KickFailure?`, `now` tiêm vào, `load()` dùng chung một tác vụ khi gọi đồng thời, **không bao giờ xin quyền trong `load()`**, và kiểm tra lại sau mỗi `await`. Vì lịch hẹn độc lập với phiên đếm, thay cho `activeSessionID` là một "thế hệ" (generation) cho từng lịch hẹn: mỗi thay đổi tăng thế hệ; chuỗi đặt nhắc dừng nếu thế hệ đã đổi trong lúc chờ, và nếu đổi trong lúc yêu cầu đặt nhắc đang bay thì đồng bộ lại theo dữ liệu hiện tại trong store.

**Files:**
- Modify: `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift` (cổng giữ `add` cho `FakeNotificationCenter`; thêm `FakeAppointmentRepository`)
- Create: `Packages/KickCore/Sources/KickCore/AppointmentCoordinator.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/AppointmentCoordinatorTests.swift`

**Interfaces:**
- Consumes: `AppointmentRepository`, `AppointmentRecord`, `AppointmentRules` (Task 7); `NotificationScheduler.scheduleAppointmentReminder(id:date:title:now:text:calendar:)`, `.cancelAppointmentReminder(id:)`, `.pendingAppointmentReminderIDs()`, `.isDenied()`, `.isAuthorized()`, `.requestAuthorizationIfNeeded()` (Task 6 + v1); `KickFailure` (v1); `NotificationText`.
- Produces: `@MainActor @Observable public final class AppointmentCoordinator` với
  - `public init(store: AppointmentRepository, notifications: NotificationScheduler, reminderText: NotificationText, calendar: Calendar = .current, now: @escaping @MainActor () -> Date = { Date() })`
  - `public private(set) var upcoming: [AppointmentRecord]`, `public private(set) var past: [AppointmentRecord]`, `public private(set) var failure: KickFailure?`, `public private(set) var notificationsDenied: Bool`, `public var nextAppointment: AppointmentRecord?`
  - `public func load() async`, `@discardableResult public func add(date: Date, title: String, note: String = "", milestoneID: String? = nil) async -> AppointmentRecord?` (nil khi lưu lỗi), `@discardableResult public func update(_ appointment: AppointmentRecord) async -> Bool`, `public func delete(id: UUID) async`, `public func markDone(id: UUID) async`, `public func clearFailure()`.
  - Test support: `FakeAppointmentRepository` (`seed(_:)`, `failNextRead`, `failNextWrite`), `FakeNotificationCenter.holdAdd` / `addPending` / `releaseAdd()`.

- [ ] **Step 1: Mở rộng test support**

Trong `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`, thay phương thức `add(_:)` của `FakeNotificationCenter`:
```swift
    func add(_ request: UNNotificationRequest) async throws {
        added.removeAll { $0.identifier == request.identifier }
        added.append(request)
    }
```
bằng:
```swift
    func add(_ request: UNNotificationRequest) async throws {
        if holdAdd {
            holdAdd = false
            addPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                addContinuations.append(continuation)
            }
            addPending = false
        }
        added.removeAll { $0.identifier == request.identifier }
        added.append(request)
    }

    /// One-shot gate: the next `add(_:)` call suspends until `releaseAdd()` is
    /// called, simulating a scheduling request still in flight.
    var holdAdd = false
    private(set) var addPending = false
    private var addContinuations: [CheckedContinuation<Void, Never>] = []

    func releaseAdd() {
        let continuations = addContinuations
        addContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }
```

Thêm vào cuối file:
```swift
/// In-memory AppointmentRepository with the same rules as AppointmentStore.
@MainActor
final class FakeAppointmentRepository: AppointmentRepository {
    struct Failed: Error {}

    private(set) var appointments: [UUID: AppointmentRecord] = [:]
    var calendar = utcCalendar
    var failNextRead = false
    var failNextWrite = false

    func seed(_ records: AppointmentRecord...) {
        for record in records { appointments[record.id] = record }
    }

    private func checkRead() throws {
        if failNextRead {
            failNextRead = false
            throw Failed()
        }
    }

    private func checkWrite() throws {
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
    }

    func appointment(id: UUID) throws -> AppointmentRecord? {
        try checkRead()
        return appointments[id]
    }

    func upcoming(now: Date) throws -> [AppointmentRecord] {
        try checkRead()
        return AppointmentRules.upcoming(Array(appointments.values), now: now, calendar: calendar)
    }

    func past(now: Date) throws -> [AppointmentRecord] {
        try checkRead()
        return AppointmentRules.past(Array(appointments.values), now: now, calendar: calendar)
    }

    func add(_ appointment: AppointmentRecord) throws {
        try checkWrite()
        appointments[appointment.id] = appointment
    }

    func update(_ appointment: AppointmentRecord) throws {
        try checkWrite()
        guard appointments[appointment.id] != nil else { throw AppointmentRepositoryError.notFound }
        appointments[appointment.id] = appointment
    }

    func delete(id: UUID) throws {
        try checkWrite()
        appointments[id] = nil
    }

    func markDone(id: UUID) throws -> AppointmentRecord? {
        try checkWrite()
        guard var appointment = appointments[id] else { return nil }
        appointment.isDone = true
        appointments[id] = appointment
        return appointment
    }
}
```

- [ ] **Step 2: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/AppointmentCoordinatorTests.swift`:
```swift
import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct AppointmentCoordinatorTests {
    let repository: FakeAppointmentRepository
    let center: FakeNotificationCenter
    let clock: TestClock
    let coordinator: AppointmentCoordinator

    init() {
        let repository = FakeAppointmentRepository()
        let center = FakeNotificationCenter()
        let clock = TestClock(date("2026-10-02T12:00:00Z"))
        self.repository = repository
        self.center = center
        self.clock = clock
        coordinator = AppointmentCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderText: NotificationText(title: "Check-up tomorrow", body: "Bring your records"),
            calendar: utcCalendar,
            now: { clock.now }
        )
    }

    private func days(_ count: Int) -> Date {
        clock.now.addingTimeInterval(Double(count) * 86_400)
    }

    private func reminderDay(_ request: UNNotificationRequest?) -> Int? {
        (request?.trigger as? UNCalendarNotificationTrigger)?.dateComponents.day
    }

    @Test func addSavesTrimmedAndSchedulesTheDayBeforeReminder() async throws {
        let record = try #require(await coordinator.add(date: date("2026-10-20T14:30:00Z"), title: "  Anomaly scan ", note: " Bring results "))
        #expect(record.title == "Anomaly scan")
        #expect(record.note == "Bring results")
        #expect(coordinator.upcoming == [record])
        #expect(coordinator.nextAppointment == record)
        let request = try #require(center.added.first)
        #expect(request.identifier == NotificationScheduler.appointmentReminderID(for: record.id))
        #expect(reminderDay(request) == 19)
        #expect(request.content.subtitle == "Anomaly scan")
    }

    @Test func addKeepsTheMilestoneID() async throws {
        let record = try #require(await coordinator.add(date: days(10), title: "Glucose test", milestoneID: "gdm-screening"))
        #expect(repository.appointments[record.id]?.milestoneID == "gdm-screening")
    }

    @Test func pastAppointmentIsSavedWithoutReminder() async throws {
        let record = try #require(await coordinator.add(date: days(-3), title: "First visit"))
        #expect(coordinator.past == [record])
        #expect(coordinator.upcoming.isEmpty)
        #expect(center.added.isEmpty)
    }

    @Test func deniedNotificationsStillSaveAndRaiseTheHint() async throws {
        center.status = .denied
        let record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        #expect(coordinator.upcoming == [record])
        #expect(center.added.isEmpty)
        #expect(coordinator.notificationsDenied)
    }

    @Test func failedAddReportsSaveFailureAndSchedulesNothing() async {
        repository.failNextWrite = true
        let record = await coordinator.add(date: days(10), title: "Scan")
        #expect(record == nil)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.upcoming.isEmpty)
        #expect(center.added.isEmpty)
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func updateReschedulesForTheNewDate() async throws {
        var record = try #require(await coordinator.add(date: date("2026-10-20T10:00:00Z"), title: "Scan"))
        record.date = date("2026-10-25T10:00:00Z")
        #expect(await coordinator.update(record))
        #expect(center.added.count == 1)
        #expect(reminderDay(center.added.first) == 24)
    }

    @Test func movingIntoThePastCancelsTheReminder() async throws {
        var record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        record.date = days(-1)
        #expect(await coordinator.update(record))
        #expect(center.added.isEmpty)
        #expect(coordinator.past.map(\.id) == [record.id])
    }

    @Test func failedUpdateReportsSaveFailure() async throws {
        var record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        repository.failNextWrite = true
        record.title = "Changed"
        #expect(await coordinator.update(record) == false)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.upcoming.first?.title == "Scan")
    }

    @Test func deleteCancelsTheReminder() async throws {
        let record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        await coordinator.delete(id: record.id)
        #expect(coordinator.upcoming.isEmpty)
        #expect(center.added.isEmpty)
        #expect(center.removed.contains(NotificationScheduler.appointmentReminderID(for: record.id)))
    }

    @Test func failedDeleteKeepsAppointmentAndReminder() async throws {
        let record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        repository.failNextWrite = true
        await coordinator.delete(id: record.id)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.upcoming == [record])
        #expect(center.added.count == 1)
    }

    @Test func markDoneCancelsTheReminderAndMovesToPast() async throws {
        let record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        await coordinator.markDone(id: record.id)
        #expect(coordinator.upcoming.isEmpty)
        #expect(coordinator.past.first?.isDone == true)
        #expect(center.added.isEmpty)
    }

    @Test func failedLoadReportsLoadFailure() async {
        repository.failNextRead = true
        await coordinator.load()
        #expect(coordinator.failure == .loadFailed)
    }

    @Test func loadPublishesListsAndReconcilesReminders() async throws {
        let upcoming = AppointmentRecord(date: days(10), title: "Scan")
        let done = AppointmentRecord(date: days(5), title: "Blood test", isDone: true)
        let old = AppointmentRecord(date: days(-7), title: "First visit")
        repository.seed(upcoming, done, old)
        // A reminder for an appointment deleted on another device.
        let orphan = UUID()
        try await NotificationScheduler(center: center).scheduleAppointmentReminder(
            id: orphan, date: days(10), title: "Gone", now: clock.now,
            text: NotificationText(title: "T", body: "B"), calendar: utcCalendar
        )

        await coordinator.load()

        #expect(coordinator.upcoming == [upcoming])
        #expect(coordinator.past == [done, old])
        #expect(center.added.map(\.identifier) == [NotificationScheduler.appointmentReminderID(for: upcoming.id)])
        #expect(center.removed.contains(NotificationScheduler.appointmentReminderID(for: orphan)))
    }

    @Test func loadNeverPromptsForPermission() async {
        center.status = .notDetermined
        repository.seed(AppointmentRecord(date: days(10), title: "Scan"))
        await coordinator.load()
        #expect(center.requestCount == 0)
        #expect(center.added.isEmpty)
        #expect(coordinator.notificationsDenied == false)
        #expect(coordinator.upcoming.count == 1)
    }

    @Test func deletingWhileThePermissionPromptIsOpenLeavesNoReminder() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let adding: AppointmentRecord? = coordinator.add(date: days(10), title: "Scan") // suspends on the prompt
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)
        let id = try #require(coordinator.upcoming.first?.id)

        await coordinator.delete(id: id)
        center.releaseRequestAuthorization()
        _ = await adding

        #expect(center.added.isEmpty)
    }

    @Test func editingWhileThePermissionPromptIsOpenKeepsTheNewestDate() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let adding: AppointmentRecord? = coordinator.add(date: date("2026-10-20T10:00:00Z"), title: "Scan")
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)
        var record = try #require(coordinator.upcoming.first)

        record.date = date("2026-10-25T10:00:00Z")
        #expect(await coordinator.update(record))
        center.releaseRequestAuthorization()
        _ = await adding

        #expect(center.added.count == 1)
        #expect(reminderDay(center.added.first) == 24)
    }

    @Test func deletingWhileTheReminderRequestIsInFlightLeavesNoReminder() async throws {
        center.holdAdd = true

        async let adding: AppointmentRecord? = coordinator.add(date: days(10), title: "Scan") // suspends in center.add
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)
        let id = try #require(coordinator.upcoming.first?.id)

        await coordinator.delete(id: id)
        center.releaseAdd()
        _ = await adding

        #expect(center.added.isEmpty)
    }

    @Test func markingDoneWhileTheReminderRequestIsInFlightLeavesNoReminder() async throws {
        center.holdAdd = true

        async let adding: AppointmentRecord? = coordinator.add(date: days(10), title: "Scan")
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)
        let id = try #require(coordinator.upcoming.first?.id)

        await coordinator.markDone(id: id)
        center.releaseAdd()
        _ = await adding

        #expect(center.added.isEmpty)
        #expect(coordinator.past.first?.isDone == true)
    }
}
```

- [ ] **Step 3: Chạy test, xác nhận fail**

Run: `scripts/test-core.sh --filter AppointmentCoordinatorTests`
Expected: FAIL khi biên dịch — `cannot find 'AppointmentCoordinator' in scope`.

- [ ] **Step 4: Viết code**

`Packages/KickCore/Sources/KickCore/AppointmentCoordinator.swift`:
```swift
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "appointments")

/// Single entry point for appointment changes, used by the UI. Keeps the
/// repository and the day-before reminders in step: the store never touches
/// notifications, and nothing else schedules appointment reminders.
///
/// Every change bumps a per-appointment generation. Reminder side effects
/// capture it and re-check it after each `await`, so an appointment deleted,
/// marked done or edited while a permission prompt or a scheduling request is
/// in flight never ends up with a stale reminder (the same guard
/// `KickCoordinator` applies with `activeSessionID`).
@MainActor
@Observable
public final class AppointmentCoordinator {
    public private(set) var upcoming: [AppointmentRecord] = []
    public private(set) var past: [AppointmentRecord] = []
    public private(set) var failure: KickFailure?
    /// True when the user has turned notifications off; the UI shows a hint.
    public private(set) var notificationsDenied = false

    private let store: AppointmentRepository
    private let notifications: NotificationScheduler
    private let reminderText: NotificationText
    private let calendar: Calendar
    private let now: @MainActor () -> Date

    private var generations: [UUID: Int] = [:]
    /// The in-flight `load()`, so concurrent callers share one reconciliation.
    private var loadTask: Task<Void, Never>?

    public init(
        store: AppointmentRepository,
        notifications: NotificationScheduler,
        reminderText: NotificationText,
        calendar: Calendar = .current,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.notifications = notifications
        self.reminderText = reminderText
        self.calendar = calendar
        self.now = now
    }

    public var nextAppointment: AppointmentRecord? { upcoming.first }

    /// Refreshes the lists and reconciles reminders with the store (e.g. after
    /// iCloud sync). Call on launch and whenever the app becomes active.
    /// Never prompts for permission.
    public func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
        guard refresh() else { return }
        let authorized = await notifications.isAuthorized()
        await updateDeniedHint(authorized: authorized)
        guard authorized else { return }

        let pending = await notifications.pendingAppointmentReminderIDs()
        // Read the store after the await, and cancel without awaiting, so an
        // appointment added meanwhile is never treated as an orphan.
        let wanted: [UUID]
        do {
            let time = now()
            wanted = try store.upcoming(now: time).filter { AppointmentRules.wantsReminder($0, now: time) }.map(\.id)
        } catch {
            logger.error("Reading appointments for reminders failed: \(error.localizedDescription)")
            return
        }
        for id in pending.subtracting(wanted) {
            notifications.cancelAppointmentReminder(id: id)
        }
        for id in wanted {
            await syncReminder(id: id, generation: generation(of: id), mayPrompt: false)
        }
    }

    @discardableResult
    public func add(date: Date, title: String, note: String = "", milestoneID: String? = nil) async -> AppointmentRecord? {
        let record = AppointmentRecord(
            date: date, title: Self.trimmed(title), note: Self.trimmed(note), milestoneID: milestoneID
        )
        do {
            try store.add(record)
        } catch {
            logger.error("Saving appointment failed: \(error.localizedDescription)")
            failure = .saveFailed
            return nil
        }
        refresh()
        await syncReminder(id: record.id, generation: bump(record.id), mayPrompt: true)
        return record
    }

    @discardableResult
    public func update(_ appointment: AppointmentRecord) async -> Bool {
        var record = appointment
        record.title = Self.trimmed(record.title)
        record.note = Self.trimmed(record.note)
        do {
            try store.update(record)
        } catch {
            logger.error("Updating appointment failed: \(error.localizedDescription)")
            failure = .saveFailed
            return false
        }
        refresh()
        await syncReminder(id: record.id, generation: bump(record.id), mayPrompt: true)
        return true
    }

    public func delete(id: UUID) async {
        do {
            try store.delete(id: id)
        } catch {
            logger.error("Deleting appointment failed: \(error.localizedDescription)")
            failure = .saveFailed
            return
        }
        bump(id)
        notifications.cancelAppointmentReminder(id: id)
        refresh()
    }

    public func markDone(id: UUID) async {
        do {
            _ = try store.markDone(id: id)
        } catch {
            logger.error("Marking appointment done failed: \(error.localizedDescription)")
            failure = .saveFailed
            return
        }
        bump(id)
        notifications.cancelAppointmentReminder(id: id)
        refresh()
    }

    public func clearFailure() {
        failure = nil
    }

    /// Brings one appointment's reminder in line with the store. `generation`
    /// is the value captured when the triggering change happened: if another
    /// change bumps it during an `await`, this run stops (before scheduling)
    /// or re-syncs from the store (after scheduling) so the newest state wins.
    private func syncReminder(id: UUID, generation: Int, mayPrompt: Bool) async {
        let record: AppointmentRecord?
        do {
            record = try store.appointment(id: id)
        } catch {
            logger.error("Reading appointment failed: \(error.localizedDescription)")
            return
        }
        guard let record, AppointmentRules.wantsReminder(record, now: now()) else {
            notifications.cancelAppointmentReminder(id: id)
            return
        }

        let authorized: Bool
        if mayPrompt {
            authorized = await notifications.requestAuthorizationIfNeeded()
        } else {
            authorized = await notifications.isAuthorized()
        }
        await updateDeniedHint(authorized: authorized)
        guard authorized, self.generation(of: id) == generation else { return }

        do {
            try await notifications.scheduleAppointmentReminder(
                id: id, date: record.date, title: record.title, now: now(), text: reminderText, calendar: calendar
            )
        } catch {
            logger.error("Scheduling appointment reminder failed: \(error.localizedDescription)")
            return
        }
        // Changed while the request was in flight: this older request may
        // have landed last, so re-apply whatever the store holds now.
        if self.generation(of: id) != generation {
            await syncReminder(id: id, generation: self.generation(of: id), mayPrompt: false)
        }
    }

    private func updateDeniedHint(authorized: Bool) async {
        if authorized {
            notificationsDenied = false
        } else {
            notificationsDenied = await notifications.isDenied()
        }
    }

    @discardableResult
    private func refresh() -> Bool {
        do {
            let time = now()
            upcoming = try store.upcoming(now: time)
            past = try store.past(now: time)
            return true
        } catch {
            logger.error("Loading appointments failed: \(error.localizedDescription)")
            failure = .loadFailed
            return false
        }
    }

    private func generation(of id: UUID) -> Int {
        generations[id, default: 0]
    }

    @discardableResult
    private func bump(_ id: UUID) -> Int {
        let next = generation(of: id) + 1
        generations[id] = next
        return next
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 5: Chạy test, xác nhận pass**

Run: `scripts/test-core.sh`
Expected: PASS toàn bộ (gồm `KickCoordinatorTests` — thay đổi `FakeNotificationCenter.add` mặc định không giữ nên không ảnh hưởng). Chạy thêm 3 lần `scripts/test-core.sh --filter AppointmentCoordinatorTests` để chắc các test có cổng không chập chờn.

- [ ] **Step 6: Commit, push, CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): add AppointmentCoordinator keeping reminders in step

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 9: KickData — model `Appointment` + `AppointmentStore`

Chỉ build/test được trên CI (SwiftData macro cần Xcode). Bài học từ v1 (commit `59dd6a1`): không thể làm `context.save()` thất bại một cách tin cậy bằng quyền file, nên `AppointmentStore` có một seam nội bộ `saveContext` để test rollback.

**Files:**
- Modify: `Packages/KickData/Sources/KickData/Models.swift` (thêm `Appointment`), `Packages/KickData/Sources/KickData/KickPersistence.swift` (schema), `Packages/KickData/Tests/KickDataTests/TestSupport.swift` (thêm `utcCalendar`)
- Create: `Packages/KickData/Sources/KickData/AppointmentStore.swift`
- Test: `Packages/KickData/Tests/KickDataTests/AppointmentStoreTests.swift`

**Interfaces:**
- Consumes: `AppointmentRecord`, `AppointmentRepository`, `AppointmentRepositoryError`, `AppointmentRules` (Task 7).
- Produces: `@Model public final class Appointment { public var id: UUID = UUID(); public var date: Date = Date(); public var title: String = ""; public var note: String = ""; public var isDone: Bool = false; public var milestoneID: String?; public init(record: AppointmentRecord); public var record: AppointmentRecord }`; `KickPersistence.schema` = `Schema([KickSession.self, Kick.self, Appointment.self])`; `@MainActor public final class AppointmentStore: AppointmentRepository` với `public convenience init(context: ModelContext, calendar: Calendar = .current)` và `init(context: ModelContext, calendar: Calendar, saveContext: @escaping @MainActor (ModelContext) throws -> Void)` (internal, seam cho test).

- [ ] **Step 1: Viết test trước**

Thêm vào cuối `Packages/KickData/Tests/KickDataTests/TestSupport.swift`:
```swift
var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}
```

`Packages/KickData/Tests/KickDataTests/AppointmentStoreTests.swift`:
```swift
import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct AppointmentStoreTests {
    struct SaveFailed: Error {}

    let now = date("2026-10-02T12:00:00Z")
    let container: ModelContainer
    let store: AppointmentStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = AppointmentStore(context: container.mainContext, calendar: utcCalendar)
    }

    /// A store on the same context whose saves always fail.
    private func failingStore() -> AppointmentStore {
        AppointmentStore(context: container.mainContext, calendar: utcCalendar, saveContext: { _ in throw SaveFailed() })
    }

    private func record(_ iso: String, title: String = "Check-up", isDone: Bool = false, milestoneID: String? = nil) -> AppointmentRecord {
        AppointmentRecord(date: date(iso), title: title, note: "Note", isDone: isDone, milestoneID: milestoneID)
    }

    @Test func schemaIncludesAppointment() {
        #expect(KickPersistence.schema.entities.map(\.name).contains("Appointment"))
    }

    @Test func addedAppointmentRoundTrips() throws {
        let added = record("2026-10-20T09:00:00Z", title: "Glucose test", milestoneID: "gdm-screening")
        try store.add(added)
        #expect(try store.appointment(id: added.id) == added)
        #expect(try store.upcoming(now: now) == [added])
        #expect(try store.past(now: now).isEmpty)
    }

    @Test func upcomingAndPastAreSplitAndSorted() throws {
        let later = record("2026-11-01T09:00:00Z")
        let soon = record("2026-10-05T09:00:00Z")
        let earlierToday = record("2026-10-02T08:00:00Z")
        let lastWeek = record("2026-09-25T09:00:00Z")
        let done = record("2026-10-10T09:00:00Z", isDone: true)
        for appointment in [later, lastWeek, done, soon, earlierToday] { try store.add(appointment) }
        #expect(try store.upcoming(now: now) == [earlierToday, soon, later])
        #expect(try store.past(now: now) == [done, lastWeek])
    }

    @Test func updateChangesEveryField() throws {
        var appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        appointment.date = date("2026-10-21T10:30:00Z")
        appointment.title = "Anomaly scan"
        appointment.note = "Full bladder"
        appointment.milestoneID = "anomaly-scan"
        try store.update(appointment)
        #expect(try store.appointment(id: appointment.id) == appointment)
    }

    @Test func updatingAnUnknownAppointmentThrowsNotFound() {
        #expect(throws: AppointmentRepositoryError.notFound) {
            try store.update(record("2026-10-20T09:00:00Z"))
        }
    }

    @Test func deleteRemovesAndUnknownIDIsANoOp() throws {
        let appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        try store.delete(id: appointment.id)
        #expect(try store.appointment(id: appointment.id) == nil)
        try store.delete(id: UUID())
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Appointment>()) == 0)
    }

    @Test func markDoneMovesToPast() throws {
        let appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        let done = try store.markDone(id: appointment.id)
        #expect(done?.isDone == true)
        #expect(try store.upcoming(now: now).isEmpty)
        #expect(try store.past(now: now).map(\.id) == [appointment.id])
        #expect(try store.markDone(id: UUID()) == nil)
    }

    @Test func failedAddRollsBack() throws {
        #expect(throws: SaveFailed.self) {
            try failingStore().add(record("2026-10-20T09:00:00Z"))
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Appointment>()) == 0)
    }

    @Test func failedUpdateRollsBack() throws {
        var appointment = record("2026-10-20T09:00:00Z", title: "Original")
        try store.add(appointment)
        appointment.title = "Changed"
        #expect(throws: SaveFailed.self) {
            try failingStore().update(appointment)
        }
        #expect(try store.appointment(id: appointment.id)?.title == "Original")
    }

    @Test func failedDeleteRollsBack() throws {
        let appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        #expect(throws: SaveFailed.self) {
            try failingStore().delete(id: appointment.id)
        }
        #expect(try store.appointment(id: appointment.id) == appointment)
    }

    @Test func failedMarkDoneRollsBack() throws {
        let appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        #expect(throws: SaveFailed.self) {
            _ = try failingStore().markDone(id: appointment.id)
        }
        #expect(try store.appointment(id: appointment.id)?.isDone == false)
    }
}
```

- [ ] **Step 2: Xác nhận test chưa thể biên dịch (thay cho bước "chạy và thấy fail")**

`KickData` không chạy được `swift test` trên máy dev, và không push test đỏ lên CI. Thay vào đó xác nhận các kiểu mà test dùng chưa tồn tại:
```bash
grep -rnE "class (AppointmentStore|Appointment) " Packages/KickData/Sources || echo "not defined yet"
```
Expected: `not defined yet`.

- [ ] **Step 3: Viết code**

Thêm vào cuối `Packages/KickData/Sources/KickData/Models.swift`:
```swift
/// A check-up the mother added. Synced through iCloud like sessions.
@Model
public final class Appointment {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var title: String = ""
    public var note: String = ""
    public var isDone: Bool = false
    /// Id of the suggested milestone this was created from, if any.
    public var milestoneID: String?

    public init(record: AppointmentRecord) {
        id = record.id
        date = record.date
        title = record.title
        note = record.note
        isDone = record.isDone
        milestoneID = record.milestoneID
    }

    public var record: AppointmentRecord {
        AppointmentRecord(id: id, date: date, title: title, note: note, isDone: isDone, milestoneID: milestoneID)
    }

    func apply(_ record: AppointmentRecord) {
        date = record.date
        title = record.title
        note = record.note
        isDone = record.isDone
        milestoneID = record.milestoneID
    }
}
```

Trong `Packages/KickData/Sources/KickData/KickPersistence.swift` đổi:
```swift
    public static let schema = Schema([KickSession.self, Kick.self])
```
thành:
```swift
    public static let schema = Schema([KickSession.self, Kick.self, Appointment.self])
```

`Packages/KickData/Sources/KickData/AppointmentStore.swift`:
```swift
import Foundation
import KickCore
import SwiftData

/// SwiftData-backed AppointmentRepository. Storage only: reminders are kept in
/// step by `AppointmentCoordinator`.
@MainActor
public final class AppointmentStore: AppointmentRepository {
    private let context: ModelContext
    private let calendar: Calendar
    private let saveContext: @MainActor (ModelContext) throws -> Void

    public convenience init(context: ModelContext, calendar: Calendar = .current) {
        self.init(context: context, calendar: calendar, saveContext: { try $0.save() })
    }

    /// `saveContext` is a seam for tests: SwiftData offers no reliable way to
    /// make a real save fail (see commit 59dd6a1).
    init(context: ModelContext, calendar: Calendar, saveContext: @escaping @MainActor (ModelContext) throws -> Void) {
        self.context = context
        self.calendar = calendar
        self.saveContext = saveContext
    }

    public func appointment(id: UUID) throws -> AppointmentRecord? {
        try model(id: id)?.record
    }

    public func upcoming(now: Date) throws -> [AppointmentRecord] {
        AppointmentRules.upcoming(try allRecords(), now: now, calendar: calendar)
    }

    public func past(now: Date) throws -> [AppointmentRecord] {
        AppointmentRules.past(try allRecords(), now: now, calendar: calendar)
    }

    public func add(_ appointment: AppointmentRecord) throws {
        context.insert(Appointment(record: appointment))
        try save()
    }

    public func update(_ appointment: AppointmentRecord) throws {
        guard let model = try model(id: appointment.id) else { throw AppointmentRepositoryError.notFound }
        model.apply(appointment)
        try save()
    }

    public func delete(id: UUID) throws {
        guard let model = try model(id: id) else { return }
        context.delete(model)
        try save()
    }

    public func markDone(id: UUID) throws -> AppointmentRecord? {
        guard let model = try model(id: id) else { return nil }
        model.isDone = true
        try save()
        return model.record
    }

    private func allRecords() throws -> [AppointmentRecord] {
        try context.fetch(FetchDescriptor<Appointment>(sortBy: [SortDescriptor(\.date)])).map(\.record)
    }

    private func model(id: UUID) throws -> Appointment? {
        var descriptor = FetchDescriptor<Appointment>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Saves, rolling back on failure so a failed write leaves no half-applied change.
    private func save() throws {
        do {
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
```

- [ ] **Step 4: Commit, push, xác minh trên CI**

```bash
scripts/test-core.sh
git add Packages/KickData
git commit -F - <<'MSG'
feat(data): add CloudKit-compatible Appointment model and AppointmentStore

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; log CI (bước "KickData unit tests") có `AppointmentStoreTests` với 11 test pass. Kiểm tra:
```bash
RUN_ID="$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId -q '.[0].databaseId')"
gh run view "$RUN_ID" --log | grep -E "AppointmentStoreTests|Test run with"
```
Expected: dòng `Suite AppointmentStoreTests passed` (hoặc từng `Test … passed`) và không có `failed`.

---
### Task 10: Nền tảng app — đồng hồ cho UI test, môi trường, CONTENT_PREVIEW, dòng tuần ở tab Đếm

**Files:**
- Create: `scripts/add-strings.py`, `App/AppClock.swift`, `App/ContentEnvironment.swift`, `UITests/UITestSupport.swift`, `UITests/PregnancyUITests.swift`
- Modify: `App/AppEnvironment.swift`, `App/KickCounterApp.swift`, `App/RootView.swift`, `App/Counter/CounterView.swift:11-16`, `Shared/L10n.swift`, `Shared/Localizable.xcstrings`, `scripts/release.sh`, `.github/workflows/testflight.yml`, `README.md`

**Interfaces:**
- Consumes: `UITestLaunchOptions(arguments:)`, `PregnancyProfile.saveDueDate(_:to:)` (Task 3); `PregnancyTimeline(dueDate:now:calendar:)` (Task 2); `WeeklyContentLibrary.loadBundled()`, `ContentVisibility` (Task 4–5); `AppointmentCoordinator(store:notifications:reminderText:calendar:now:)`, `.load()` (Task 8); `AppointmentStore(context:calendar:)` (Task 9).
- Produces:
  - `scripts/add-strings.py [--catalog PATH] [--remove KEY…]` — đọc `{"key": ["English", "Tiếng Việt"]}` từ stdin, từ chối khóa trùng, bản dịch rỗng, hoặc định dạng `%…` lệch giữa en/vi; giữ file sắp xếp và định dạng như đang commit.
  - `enum AppClock { static let launchOptions: UITestLaunchOptions; static func now() -> Date }`.
  - `EnvironmentValues.contentLibrary: WeeklyContentLibrary?`; `enum BuildFlags { static var contentVisibility: ContentVisibility }` (`.all` khi `DEBUG || CONTENT_PREVIEW`, ngược lại `.reviewedOnly`).
  - `AppEnvironment` có thêm `let appointments: AppointmentCoordinator`, `let content: WeeklyContentLibrary?`; app tiêm `.environment(env.appointments)` và `.environment(\.contentLibrary, env.content)`.
  - `L10n.appointmentsReminderTitle`, `L10n.appointmentsReminderBody`.
  - `scripts/release.sh`: biến môi trường `CONTENT_PREVIEW=1` thêm `SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) CONTENT_PREVIEW`.
  - UI test: `UITestDates` (`fixedNow`, `dueAtWeek12`, `dueAtWeek24`, `dueAtWeek38`, `dueSevenDaysAgo`), `XCUIApplication.launchPinned(language:dark:dueDate:) -> XCUIApplication`, `XCTestCase.attachScreenshot(_:_:)`.

- [ ] **Step 1: Viết "test" cho `scripts/add-strings.py` (chạy local)**

```bash
TMP="$(mktemp -d)"; cp Shared/Localizable.xcstrings "$TMP/c.xcstrings"
echo '{"zz.test": ["Hello %ld", "Xin chào %ld"]}' | scripts/add-strings.py --catalog "$TMP/c.xcstrings"; echo "exit=$?"
```
Expected (chưa có script): `No such file or directory`, `exit=127`.

- [ ] **Step 2: Viết script**

`scripts/add-strings.py`:
```python
#!/usr/bin/env python3
"""Adds or removes keys in Shared/Localizable.xcstrings (en + vi), keeping the
file sorted and formatted exactly as it is committed.

Add:    scripts/add-strings.py <<'JSON'
        {"some.key": ["English", "Tiếng Việt"]}
        JSON
Remove: scripts/add-strings.py --remove some.key other.key
"""
import argparse
import json
import os
import re
import sys

DEFAULT_CATALOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Shared", "Localizable.xcstrings")
FORMAT = re.compile(r"%(?:\d+\$)?(?:ld|lld|d|@|f|\.\d+f)")


def entry(en, vi):
    return {"extractionState": "manual", "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": en}},
        "vi": {"stringUnit": {"state": "translated", "value": vi}}}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default=DEFAULT_CATALOG)
    parser.add_argument("--remove", nargs="+", metavar="KEY")
    args = parser.parse_args()

    with open(args.catalog, encoding="utf-8") as f:
        catalog = json.load(f)
    strings = catalog["strings"]

    if args.remove:
        for key in args.remove:
            if key not in strings:
                sys.exit(f"unknown key: {key}")
            del strings[key]
    else:
        for key, pair in json.load(sys.stdin).items():
            if key in strings:
                sys.exit(f"key already exists: {key}")
            if not (isinstance(pair, list) and len(pair) == 2 and all(isinstance(s, str) and s.strip() for s in pair)):
                sys.exit(f"expected [English, Vietnamese] for {key}")
            en, vi = pair
            if sorted(FORMAT.findall(en)) != sorted(FORMAT.findall(vi)):
                sys.exit(f"format specifiers differ between en and vi for {key}")
            strings[key] = entry(en, vi)

    catalog["strings"] = dict(sorted(strings.items()))
    missing = [k for k, v in catalog["strings"].items() if set(v.get("localizations", {})) != {"en", "vi"}]
    if missing:
        sys.exit(f"missing translations: {missing}")
    with open(args.catalog, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    print(f"{len(catalog['strings'])} strings")


if __name__ == "__main__":
    main()
```
Run: `chmod +x scripts/add-strings.py`

- [ ] **Step 3: Chạy test của script, xác nhận pass**

```bash
TMP="$(mktemp -d)"; cp Shared/Localizable.xcstrings "$TMP/c.xcstrings"
echo '{"zz.test": ["Hello %ld", "Xin chào %ld"]}' | scripts/add-strings.py --catalog "$TMP/c.xcstrings"
echo '{"zz.test": ["Again", "Lần nữa"]}' | scripts/add-strings.py --catalog "$TMP/c.xcstrings"; echo "exit=$?"
echo '{"zz.bad": ["Hello %ld", "Xin chào"]}' | scripts/add-strings.py --catalog "$TMP/c.xcstrings"; echo "exit=$?"
scripts/add-strings.py --catalog "$TMP/c.xcstrings" --remove zz.test
cmp "$TMP/c.xcstrings" Shared/Localizable.xcstrings && echo identical
rm -rf "$TMP"
```
Expected, theo thứ tự: `71 strings`; `key already exists: zz.test` + `exit=1`; `format specifiers differ between en and vi for zz.bad` + `exit=1`; `70 strings`; `identical` (thêm rồi xóa trả về đúng byte ban đầu).

- [ ] **Step 4: Thêm chuỗi của task này**

```bash
scripts/add-strings.py <<'JSON'
{
  "appointments.reminder.title": ["Check-up tomorrow", "Ngày mai mẹ có lịch khám"],
  "appointments.reminder.body": ["Remember to bring your pregnancy records.", "Mẹ nhớ mang theo sổ khám thai nhé."]
}
JSON
```
Expected: `72 strings`.

Trong `Shared/L10n.swift`, thêm sau dòng `static var reminderBody …`:
```swift

    static var appointmentsReminderTitle: String { t("appointments.reminder.title") }
    static var appointmentsReminderBody: String { t("appointments.reminder.body") }
```

- [ ] **Step 5: Viết UI test trước (chạy trên CI cùng code)**

`UITests/UITestSupport.swift`:
```swift
import XCTest

/// Fixed dates for deterministic pregnancy UI tests. `fixedNow` is noon UTC so
/// it falls on the same calendar day in any simulator time zone from UTC−11 to UTC+11.
enum UITestDates {
    static let fixedNow = "2026-10-02T12:00:00Z"
    /// 12w0d at `fixedNow`.
    static let dueAtWeek12 = "2027-04-16T12:00:00Z"
    /// 24w3d at `fixedNow`, 109 days to go (the spec's example).
    static let dueAtWeek24 = "2027-01-19T12:00:00Z"
    /// 38w0d at `fixedNow`.
    static let dueAtWeek38 = "2026-10-16T12:00:00Z"
    /// 41w0d at `fixedNow`: 7 days past the due date.
    static let dueSevenDaysAgo = "2026-09-25T12:00:00Z"
}

extension XCUIApplication {
    /// Launches with onboarding skipped and the clock pinned to `UITestDates.fixedNow`,
    /// optionally with a stored due date. Only the pregnancy and appointment screens
    /// (and the Count tab's week line) use the pinned clock; counting kicks uses real time.
    @MainActor
    static func launchPinned(language: String = "en", dark: Bool = false, dueDate: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "vi" ? "vi_VN" : "en_US",
            "-fixedNow", UITestDates.fixedNow,
        ]
        if let dueDate { app.launchArguments += ["-seedDueDate", dueDate] }
        if dark { app.launchArguments.append("-forceDarkMode") }
        app.launch()
        return app
    }
}

extension XCTestCase {
    /// Attaches a screenshot; CI exports it to build/screenshots/<name>_….png.
    @MainActor
    func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

`UITests/PregnancyUITests.swift`:
```swift
import XCTest

/// Functional checks of the pregnancy features with a pinned clock.
final class PregnancyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCounterWeekLineUsesPinnedClockAndSeededDueDate() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        XCTAssertTrue(app.staticTexts["Week 24 + 3 days"].waitForExistence(timeout: 10))
        attachScreenshot(app, "counter-week-24-en")
    }
}
```

- [ ] **Step 6: Viết code app**

`App/AppClock.swift`:
```swift
import Foundation
import KickCore

/// The app's "now" for the pregnancy and appointment screens. UI tests pin it with
/// `-uiTesting -fixedNow <ISO8601>` so screenshots are deterministic.
/// `KickCoordinator` never uses it: a frozen clock would debounce every kick after the first.
enum AppClock {
    static let launchOptions = UITestLaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    static func now() -> Date {
        launchOptions.fixedNow ?? Date()
    }
}
```

`App/ContentEnvironment.swift`:
```swift
import KickCore
import SwiftUI

private struct ContentLibraryKey: EnvironmentKey {
    static let defaultValue: WeeklyContentLibrary? = nil
}

extension EnvironmentValues {
    /// The bundled week-by-week content; nil if it failed to load (cards are hidden).
    var contentLibrary: WeeklyContentLibrary? {
        get { self[ContentLibraryKey.self] }
        set { self[ContentLibraryKey.self] = newValue }
    }
}

enum BuildFlags {
    /// Debug and TestFlight builds (`CONTENT_PREVIEW`, set by testflight.yml through
    /// release.sh) show all content with a "pending review" label; App Store builds
    /// show only content an obstetrician has marked `reviewed`.
    static var contentVisibility: ContentVisibility {
        #if DEBUG || CONTENT_PREVIEW
        return .all
        #else
        return .reviewedOnly
        #endif
    }
}
```

Thay toàn bộ `App/AppEnvironment.swift`:
```swift
import Foundation
import KickCore
import KickData
import SwiftData

@MainActor
struct AppEnvironment {
    let container: ModelContainer
    let coordinator: KickCoordinator
    let appointments: AppointmentCoordinator
    let content: WeeklyContentLibrary?

    private static let arguments = ProcessInfo.processInfo.arguments
    static let isUITesting = AppClock.launchOptions.isUITesting
    static let forceDarkMode = arguments.contains("-forceDarkMode")

    static func make() throws -> AppEnvironment {
        if isUITesting {
            AppGroup.defaults.removePersistentDomain(forName: AppGroup.identifier)
            if arguments.contains("-skipOnboarding") {
                AppGroup.defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
            }
            if let seededDueDate = AppClock.launchOptions.seedDueDate {
                PregnancyProfile.saveDueDate(seededDueDate, to: AppGroup.defaults)
            }
        }
        let container = try KickPersistence.makeContainer(inMemory: isUITesting)
        let notificationCenter: NotificationCenterClient = isUITesting ? DisabledNotificationCenter() : SystemNotificationCenter()
        let liveActivities: LiveActivityManaging = isUITesting ? NoopLiveActivityManager() : SystemLiveActivityManager()
        let notifications = NotificationScheduler(center: notificationCenter)
        let coordinator = KickCoordinator(
            store: KickStore(context: container.mainContext),
            notifications: notifications,
            liveActivities: liveActivities,
            overdueText: NotificationText(title: L10n.overdueTitle, body: L10n.overdueBody)
        )
        let appointments = AppointmentCoordinator(
            store: AppointmentStore(context: container.mainContext),
            notifications: notifications,
            reminderText: NotificationText(title: L10n.appointmentsReminderTitle, body: L10n.appointmentsReminderBody),
            now: { AppClock.now() }
        )
        return AppEnvironment(
            container: container,
            coordinator: coordinator,
            appointments: appointments,
            content: WeeklyContentLibrary.loadBundled()
        )
    }
}
```

Trong `App/KickCounterApp.swift`, thay:
```swift
                RootView()
                    .environment(env.coordinator)
                    .modelContainer(env.container)
```
bằng:
```swift
                RootView()
                    .environment(env.coordinator)
                    .environment(env.appointments)
                    .environment(\.contentLibrary, env.content)
                    .modelContainer(env.container)
```

Trong `App/RootView.swift`:
- thêm sau dòng `@Environment(KickCoordinator.self) private var coordinator`:
```swift
    @Environment(AppointmentCoordinator.self) private var appointments
```
- thay:
```swift
        .task { await coordinator.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await coordinator.load() } }
        }
```
bằng:
```swift
        .task { await reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
```
- thêm phương thức trong `struct RootView` (sau `body`):
```swift
    private func reload() async {
        await coordinator.load()
        await appointments.load()
    }
```

Trong `App/Counter/CounterView.swift`, thay:
```swift
    private var gestationalWeekText: String? {
        guard dueDate > 0,
              let week = GestationalAge.week(dueDate: Date(timeIntervalSince1970: dueDate), now: .now)
        else { return nil }
        return L10n.counterWeek(week)
    }
```
bằng:
```swift
    private var gestationalWeekText: String? {
        guard dueDate > 0,
              let timeline = PregnancyTimeline(dueDate: Date(timeIntervalSince1970: dueDate), now: AppClock.now())
        else { return nil }
        return L10n.counterWeek(timeline.week)
    }
```

- [ ] **Step 7: Nối cờ `CONTENT_PREVIEW` cho TestFlight**

Trong `scripts/release.sh`, thay:
```bash
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -configuration Release -destination "generic/platform=iOS" \
  -archivePath build/KickCounter.xcarchive \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  "${AUTH[@]}" archive
```
bằng:
```bash
# TestFlight builds show pregnancy content still awaiting the obstetrician's
# review (CONTENT_PREVIEW=1, set by testflight.yml). App Store builds must not set it.
EXTRA_SETTINGS=()
if [[ "${CONTENT_PREVIEW:-0}" == "1" ]]; then
  EXTRA_SETTINGS+=('SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) CONTENT_PREVIEW')
  echo "==> CONTENT_PREVIEW enabled"
fi

xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -configuration Release -destination "generic/platform=iOS" \
  -archivePath build/KickCounter.xcarchive \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  ${EXTRA_SETTINGS[@]+"${EXTRA_SETTINGS[@]}"} \
  "${AUTH[@]}" archive
```
(Dạng `${EXTRA_SETTINGS[@]+"…"}` bắt buộc vì runner dùng bash 3.2 với `set -u`: mảng rỗng mở rộng trực tiếp sẽ báo lỗi.)

Trong `.github/workflows/testflight.yml`, bước `Archive and upload`, thêm vào `env:` (dưới `BUILD_NUMBER: ${{ github.run_number }}`):
```yaml
          CONTENT_PREVIEW: "1"
```

Kiểm tra local:
```bash
bash -n scripts/release.sh && bash -c 'set -u; A=(); B=("x y"); printf "[%s]" ${A[@]+"${A[@]}"} ${B[@]+"${B[@]}"}; echo'
grep -n 'CONTENT_PREVIEW' scripts/release.sh .github/workflows/testflight.yml
```
Expected: `[x y]` (mảng rỗng không sinh đối số, mảng một phần tử giữ nguyên dấu cách), và 3 dòng grep (2 trong `release.sh`, 1 trong `testflight.yml`). Việc cờ thực sự có hiệu lực được kiểm trên bản TestFlight ở Task 14.

- [ ] **Step 8: Cập nhật README**

Thêm vào cuối `README.md`:
```markdown

## Thai kỳ (giai đoạn 2)
- Nội dung theo tuần: `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`
  (song ngữ, kiểm định bằng `scripts/test-core.sh`). Bác sĩ duyệt → đổi `reviewed` thành `true`.
- Bản TestFlight (`CONTENT_PREVIEW=1`) hiện cả nội dung chưa duyệt; bản App Store chỉ hiện nội dung đã duyệt.
- Chuỗi giao diện mới: `scripts/add-strings.py` (xem đầu file).
- UI test: `-uiTesting -fixedNow <ISO8601>` cố định đồng hồ màn thai kỳ/lịch khám,
  `-seedDueDate <ISO8601>` ghi sẵn ngày dự sinh.
```

- [ ] **Step 9: Chạy test local, commit, push, xác minh trên CI**

```bash
scripts/test-core.sh
git add scripts App Shared UITests .github README.md
git commit -F - <<'MSG'
feat(app): wire appointments, content and a pinned clock for UI tests

Counter week line now uses PregnancyTimeline. TestFlight builds get
the CONTENT_PREVIEW compilation condition.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; `PregnancyUITests.testCounterWeekLineUsesPinnedClockAndSeededDueDate` pass; mọi UI test/ảnh chụp v1 vẫn pass.

Mở bằng Read tool và xác nhận:
- `counter-week-24-en`: màn Đếm, dòng "Week 24 + 3 days" phía trên vòng tròn, nút giữa hiện "0" và "Tap to start".
- `counter-empty-light`, `history-light`: giống lần chạy trước (không có thay đổi ngoài ý muốn).

---

### Task 11: Nhập ngày thai kỳ — sheet dùng chung, Cài đặt, Onboarding bước 4, Nguồn tham khảo

**Files:**
- Create: `App/Pregnancy/PregnancyDateForm.swift`, `App/Pregnancy/PregnancyDateSheet.swift`
- Modify: `App/Settings/SettingsView.swift` (thay toàn bộ), `App/Settings/MedicalInfoView.swift` (thay toàn bộ), `App/Onboarding/OnboardingView.swift` (thay toàn bộ), `Shared/L10n.swift`, `Shared/Localizable.xcstrings`, `UITests/KickCounterUITests.swift:15-21`, `UITests/ScreenshotTests.swift:91-121`

**Interfaces:**
- Consumes: `PregnancyDateSource`, `PregnancyProfile.load(from:)/.save(source:date:to:)/.clear(_:)`, `PregnancyDateInput.range(for:now:)/.convert(_:to:now:)/.initialSelection(for:now:)`, `PregnancyDates.dueDate(fromLMP:)` (Task 2–3); `AppClock.now()`, `\.contentLibrary` (Task 10); `SettingsKey.lmpDate`, `SettingsKey.pregnancyDateSource`.
- Produces:
  - `struct PregnancyDateForm: View { init(source: Binding<PregnancyDateSource>, date: Binding<Date>, now: Date) }` — một `Section` (dùng bên trong `Form`).
  - `struct PregnancyDateSheet: View { init(now: Date = AppClock.now()) }` — tự đọc hồ sơ, lưu qua `PregnancyProfile.save`, tự đóng.
  - `OnboardingView(onFinish:)`: sau "Tôi đã hiểu" hiện bước "Thai kỳ của bạn" (`onboardingSaveDate`, `onboardingSkipDate`).
  - L10n mới: `commonSave`, `pregnancyDateTitle`, `pregnancyDateSourceLabel`, `pregnancyDateSourceDueDate`, `pregnancyDateSourceLMP`, `pregnancyDateLMPLabel`, `pregnancyDateHintDueDate`, `pregnancyDateHintLMP`, `pregnancyDateEstimatedDue(_:)`, `settingsPregnancySet`, `settingsPregnancyNotSet`, `settingsPregnancyFromLMP(_:)`, `settingsPregnancyClear`, `settingsPregnancyClearConfirm`, `onboarding4Title`, `onboarding4Body`, `onboardingLater`, `medicalSourcesTitle`, `medicalSourcesNote`. Bỏ `settingsDueDateToggle` (khóa `settings.dueDate.toggle`).

- [ ] **Step 1: Thêm/bỏ chuỗi**

```bash
scripts/add-strings.py --remove settings.dueDate.toggle
scripts/add-strings.py <<'JSON'
{
  "common.save": ["Save", "Lưu"],
  "pregnancyDate.title": ["Pregnancy dates", "Ngày thai kỳ"],
  "pregnancyDate.source": ["Date type", "Loại ngày"],
  "pregnancyDate.source.dueDate": ["Due date", "Ngày dự sinh"],
  "pregnancyDate.source.lmp": ["Last period", "Kỳ kinh cuối"],
  "pregnancyDate.lmp": ["First day of last period", "Ngày đầu kỳ kinh cuối"],
  "pregnancyDate.hint.dueDate": ["Use the due date from your doctor or your dating scan.", "Dùng ngày dự sinh bác sĩ đã báo hoặc theo kết quả siêu âm."],
  "pregnancyDate.hint.lmp": ["Your due date is estimated as 280 days after the first day of your last period.", "Ngày dự sinh được ước tính bằng 280 ngày sau ngày đầu kỳ kinh cuối."],
  "pregnancyDate.estimatedDue": ["Estimated due date: %@", "Ngày dự sinh ước tính: %@"],
  "settings.pregnancy.set": ["Set pregnancy dates", "Nhập ngày thai kỳ"],
  "settings.pregnancy.notSet": ["Not set", "Chưa nhập"],
  "settings.pregnancy.fromLMP": ["Calculated from your last period (%@)", "Tính từ kỳ kinh cuối (%@)"],
  "settings.pregnancy.clear": ["Clear pregnancy dates", "Xóa thông tin thai kỳ"],
  "settings.pregnancy.clear.confirm": ["Clear your due date and pregnancy dates?", "Xóa ngày dự sinh và thông tin thai kỳ?"],
  "onboarding.4.title": ["Your pregnancy", "Thai kỳ của bạn"],
  "onboarding.4.body": ["Add your dates to follow your baby's growth week by week. You can also do this later in Settings.", "Nhập ngày để theo dõi bé lớn lên từng tuần. Mẹ cũng có thể làm sau trong Cài đặt."],
  "onboarding.later": ["Later", "Để sau"],
  "medical.sources.title": ["Sources", "Nguồn tham khảo"],
  "medical.sources.note": ["The week-by-week pregnancy content is general information based on public guidance from these organisations, checked by an obstetrician before release. It does not replace advice from your own doctor or midwife.", "Nội dung thai kỳ theo tuần là thông tin chung, dựa trên khuyến nghị công khai của các tổ chức dưới đây và được bác sĩ sản khoa kiểm tra trước khi phát hành. Nội dung không thay thế lời khuyên của bác sĩ hay nữ hộ sinh theo dõi mẹ."]
}
JSON
```
Expected: `71 strings` rồi `90 strings`.

Trong `Shared/L10n.swift`:
- xóa dòng `    static var settingsDueDateToggle: String { t("settings.dueDate.toggle") }`;
- thêm sau `static var commonOK …`:
```swift
    static var commonSave: String { t("common.save") }
```
- thêm sau `static var settingsVersion …`:
```swift
    static var settingsPregnancySet: String { t("settings.pregnancy.set") }
    static var settingsPregnancyNotSet: String { t("settings.pregnancy.notSet") }
    static func settingsPregnancyFromLMP(_ date: String) -> String { String(format: t("settings.pregnancy.fromLMP"), date) }
    static var settingsPregnancyClear: String { t("settings.pregnancy.clear") }
    static var settingsPregnancyClearConfirm: String { t("settings.pregnancy.clear.confirm") }

    static var pregnancyDateTitle: String { t("pregnancyDate.title") }
    static var pregnancyDateSourceLabel: String { t("pregnancyDate.source") }
    static var pregnancyDateSourceDueDate: String { t("pregnancyDate.source.dueDate") }
    static var pregnancyDateSourceLMP: String { t("pregnancyDate.source.lmp") }
    static var pregnancyDateLMPLabel: String { t("pregnancyDate.lmp") }
    static var pregnancyDateHintDueDate: String { t("pregnancyDate.hint.dueDate") }
    static var pregnancyDateHintLMP: String { t("pregnancyDate.hint.lmp") }
    static func pregnancyDateEstimatedDue(_ date: String) -> String { String(format: t("pregnancyDate.estimatedDue"), date) }
```
- thêm sau `static var medicalBody …`:
```swift
    static var medicalSourcesTitle: String { t("medical.sources.title") }
    static var medicalSourcesNote: String { t("medical.sources.note") }
```
- thêm sau `static var onboardingAgree …`:
```swift
    static var onboarding4Title: String { t("onboarding.4.title") }
    static var onboarding4Body: String { t("onboarding.4.body") }
    static var onboardingLater: String { t("onboarding.later") }
```

- [ ] **Step 2: Cập nhật UI test trước (chạy trên CI cùng code)**

Trong `UITests/KickCounterUITests.swift`, thay `completeOnboarding()`:
```swift
    private func completeOnboarding() {
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        next.tap()
        app.buttons["onboardingAgree"].tap()
        let later = app.buttons["onboardingSkipDate"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
    }
```

Trong `UITests/ScreenshotTests.swift`, thay toàn bộ `testOnboardingAndSettingsScreens()`:
```swift
    @MainActor
    func testOnboardingAndSettingsScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()

        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        snap(app, "onboarding-1")
        next.tap()
        snap(app, "onboarding-2")
        next.tap()
        snap(app, "onboarding-3")
        app.buttons["onboardingAgree"].tap()
        let later = app.buttons["onboardingSkipDate"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        snap(app, "onboarding-4")
        later.tap()

        app.tabBars.buttons.element(boundBy: 2).tap()
        let datesRow = app.buttons["settingsPregnancyDates"]
        XCTAssertTrue(datesRow.waitForExistence(timeout: 5))
        snap(app, "settings")

        datesRow.tap()
        let save = app.buttons["pregnancyDateSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        snap(app, "pregnancy-date-sheet")
        app.segmentedControls.buttons.element(boundBy: 1).tap() // "Kỳ kinh cuối"
        XCTAssertTrue(app.staticTexts["pregnancyEstimatedDue"].waitForExistence(timeout: 5))
        snap(app, "pregnancy-date-sheet-lmp")
        save.tap()
        XCTAssertTrue(app.buttons["settingsPregnancyClear"].waitForExistence(timeout: 5))
        snap(app, "settings-pregnancy-set")

        app.buttons["settingsMedicalInfo"].tap()
        let sources = app.descendants(matching: .any)["medicalSources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 5))
        app.swipeUp()
        snap(app, "medical-sources")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons.element(boundBy: 0).tap()
        snap(app, "counter-with-week")
    }
```

- [ ] **Step 3: Viết form và sheet nhập ngày**

`App/Pregnancy/PregnancyDateForm.swift`:
```swift
import KickCore
import SwiftUI

/// Due date / last period picker shared by the date sheet and onboarding.
/// A `Section`: place it inside a `Form`.
struct PregnancyDateForm: View {
    @Binding var source: PregnancyDateSource
    @Binding var date: Date
    let now: Date

    private var dateLabel: String {
        source == .dueDate ? L10n.pregnancyDateSourceDueDate : L10n.pregnancyDateLMPLabel
    }

    var body: some View {
        Section {
            Picker(L10n.pregnancyDateSourceLabel, selection: $source) {
                Text(L10n.pregnancyDateSourceDueDate).tag(PregnancyDateSource.dueDate)
                Text(L10n.pregnancyDateSourceLMP).tag(PregnancyDateSource.lmp)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("pregnancyDateSourcePicker")

            DatePicker(
                dateLabel,
                selection: $date,
                in: PregnancyDateInput.range(for: source, now: now),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .accessibilityLabel(dateLabel)
            .accessibilityIdentifier("pregnancyDatePicker")
        } header: {
            Text(dateLabel)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(source == .dueDate ? L10n.pregnancyDateHintDueDate : L10n.pregnancyDateHintLMP)
                if source == .lmp {
                    Text(L10n.pregnancyDateEstimatedDue(
                        PregnancyDates.dueDate(fromLMP: date).formatted(date: .long, time: .omitted)
                    ))
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("pregnancyEstimatedDue")
                }
            }
        }
        .onChange(of: source) { _, newSource in
            date = PregnancyDateInput.convert(date, to: newSource, now: now)
        }
    }
}
```

`App/Pregnancy/PregnancyDateSheet.swift`:
```swift
import KickCore
import SwiftUI

/// Enter or edit the pregnancy dates. Used from the Pregnancy tab and Settings.
struct PregnancyDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var source: PregnancyDateSource
    @State private var date: Date
    private let now: Date

    init(now: Date = AppClock.now()) {
        self.now = now
        let selection = PregnancyDateInput.initialSelection(for: PregnancyProfile.load(from: AppGroup.defaults), now: now)
        _source = State(initialValue: selection.source)
        _date = State(initialValue: selection.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                PregnancyDateForm(source: $source, date: $date, now: now)
            }
            .navigationTitle(L10n.pregnancyDateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) {
                        PregnancyProfile.save(source: source, date: date, to: AppGroup.defaults)
                        dismiss()
                    }
                    .accessibilityIdentifier("pregnancyDateSave")
                }
            }
        }
    }
}
```

- [ ] **Step 4: Cài đặt — thay toggle ngày dự sinh bằng dòng ngày + nguồn**

Thay toàn bộ `App/Settings/SettingsView.swift`:
```swift
import KickCore
import SwiftUI

struct SettingsView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(SettingsKey.reminderEnabled, store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderHour, store: AppGroup.defaults) private var reminderHour = SettingsDefault.reminderHour
    @AppStorage(SettingsKey.reminderMinute, store: AppGroup.defaults) private var reminderMinute = SettingsDefault.reminderMinute
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @AppStorage(SettingsKey.lmpDate, store: AppGroup.defaults) private var lmpDate: Double = 0
    @AppStorage(SettingsKey.pregnancyDateSource, store: AppGroup.defaults)
    private var pregnancyDateSource = PregnancyDateSource.dueDate.rawValue

    @State private var notificationsAuthorized = true
    @State private var showingPregnancyDates = false
    @State private var confirmingClearPregnancy = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.settingsReminderSection) {
                    Toggle(L10n.settingsReminderToggle, isOn: $reminderEnabled)
                        .accessibilityIdentifier("settingsReminderToggle")
                    if reminderEnabled {
                        DatePicker(L10n.settingsReminderTime, selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section(L10n.settingsPregnancySection) {
                    Button {
                        showingPregnancyDates = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(dueDate > 0 ? L10n.settingsDueDate : L10n.settingsPregnancySet, value: dueDateText)
                            if let lmpText {
                                Text(L10n.settingsPregnancyFromLMP(lmpText))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("settingsPregnancyDates")

                    if dueDate > 0 {
                        Button(L10n.settingsPregnancyClear, role: .destructive) {
                            confirmingClearPregnancy = true
                        }
                        .accessibilityIdentifier("settingsPregnancyClear")
                    }
                }

                if !notificationsAuthorized || !coordinator.liveActivitiesAvailable {
                    Section(L10n.settingsPermissionsSection) {
                        if !notificationsAuthorized {
                            Text(L10n.settingsNotificationsDenied).font(.footnote)
                        }
                        if !coordinator.liveActivitiesAvailable {
                            Text(L10n.settingsLiveActivitiesOff).font(.footnote)
                        }
                        Button(L10n.settingsOpenSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }

                Section(L10n.settingsAboutSection) {
                    NavigationLink(L10n.settingsMedicalInfo) { MedicalInfoView() }
                        .accessibilityIdentifier("settingsMedicalInfo")
                    LabeledContent(L10n.settingsVersion, value: appVersion)
                }
            }
            .navigationTitle(L10n.settingsTitle)
            .sheet(isPresented: $showingPregnancyDates) { PregnancyDateSheet() }
            .confirmationDialog(
                L10n.settingsPregnancyClearConfirm,
                isPresented: $confirmingClearPregnancy,
                titleVisibility: .visible
            ) {
                Button(L10n.settingsPregnancyClear, role: .destructive) { PregnancyProfile.clear(AppGroup.defaults) }
                Button(L10n.commonCancel, role: .cancel) {}
            }
            .task { await refreshPermissions() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshPermissions() } }
            }
            .onChange(of: reminderEnabled) { Task { await applyReminder() } }
            .onChange(of: reminderHour) { Task { await applyReminder() } }
            .onChange(of: reminderMinute) { Task { await applyReminder() } }
        }
    }

    private var dueDateText: String {
        guard dueDate > 0 else { return L10n.settingsPregnancyNotSet }
        return Date(timeIntervalSince1970: dueDate).formatted(date: .long, time: .omitted)
    }

    private var lmpText: String? {
        guard pregnancyDateSource == PregnancyDateSource.lmp.rawValue, lmpDate > 0 else { return nil }
        return Date(timeIntervalSince1970: lmpDate).formatted(date: .long, time: .omitted)
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderHour = components.hour ?? SettingsDefault.reminderHour
                reminderMinute = components.minute ?? SettingsDefault.reminderMinute
            }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func applyReminder() async {
        let scheduled = await coordinator.setDailyReminder(
            enabled: reminderEnabled,
            hour: reminderHour,
            minute: reminderMinute,
            text: NotificationText(title: L10n.reminderTitle, body: L10n.reminderBody)
        )
        if !scheduled {
            reminderEnabled = false
        }
        await refreshPermissions()
    }

    private func refreshPermissions() async {
        notificationsAuthorized = await coordinator.notificationsAuthorized()
    }
}
```

- [ ] **Step 5: Thông tin y tế — mục Nguồn tham khảo**

Thay toàn bộ `App/Settings/MedicalInfoView.swift`:
```swift
import SwiftUI

struct MedicalInfoView: View {
    @Environment(\.contentLibrary) private var library

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.medicalBody)
                    .font(.body)

                if let sources = library?.sources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.medicalSourcesTitle)
                            .font(.headline)
                        Text(L10n.medicalSourcesNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(sources, id: \.self) { source in
                            Label {
                                Text(verbatim: source)
                            } icon: {
                                Image(systemName: "book.closed")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .font(.subheadline)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("medicalSources")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(L10n.medicalTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 6: Onboarding — bước 4 "Thai kỳ của bạn"**

Bước 4 chỉ hiện **sau** khi mẹ bấm "Tôi đã hiểu" (không nằm trong `TabView` vuốt được), để không ai bỏ qua được trang miễn trừ.

Thay toàn bộ `App/Onboarding/OnboardingView.swift`:
```swift
import KickCore
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    @State private var showingPregnancyStep = false
    @State private var dateSource: PregnancyDateSource
    @State private var date: Date
    private let now: Date

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let now = AppClock.now()
        self.now = now
        let selection = PregnancyDateInput.initialSelection(for: PregnancyProfile.load(from: AppGroup.defaults), now: now)
        _dateSource = State(initialValue: selection.source)
        _date = State(initialValue: selection.date)
    }

    private struct Page {
        let symbol: String
        let title: String
        let body: String
    }

    private var pages: [Page] {
        [
            Page(symbol: "hand.tap.fill", title: L10n.onboarding1Title, body: L10n.onboarding1Body),
            Page(symbol: "moon.stars.fill", title: L10n.onboarding2Title, body: L10n.onboarding2Body),
            Page(symbol: "stethoscope", title: L10n.onboarding3Title, body: L10n.onboarding3Body),
        ]
    }

    var body: some View {
        Group {
            if showingPregnancyStep {
                pregnancyStep
            } else {
                introPages
            }
        }
        .interactiveDismissDisabled()
    }

    private var introPages: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Image(systemName: pages[index].symbol)
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(pages[index].title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].body)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if page < pages.count - 1 {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text(L10n.onboardingNext).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingNext")
                .padding(24)
            } else {
                Button {
                    withAnimation { showingPregnancyStep = true }
                } label: {
                    Text(L10n.onboardingAgree).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingAgree")
                .padding(24)
            }
        }
    }

    private var pregnancyStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(L10n.onboarding4Title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(L10n.onboarding4Body)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)

            Form {
                PregnancyDateForm(source: $dateSource, date: $date, now: now)
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: 12) {
                Button {
                    PregnancyProfile.save(source: dateSource, date: date, to: AppGroup.defaults)
                    onFinish()
                } label: {
                    Text(L10n.commonSave).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingSaveDate")

                Button(action: onFinish) {
                    Text(L10n.onboardingLater).frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .accessibilityIdentifier("onboardingSkipDate")
            }
            .padding(24)
        }
    }
}
```

- [ ] **Step 7: Kiểm tra catalog, commit, push, xác minh trên CI**

```bash
grep -c 'settingsDueDateToggle' Shared/L10n.swift App/Settings/SettingsView.swift UITests/*.swift || true
scripts/test-core.sh
git add App Shared UITests
git commit -F - <<'MSG'
feat(app): enter pregnancy dates by due date or last period

Shared date sheet for Settings and a new onboarding step; medical
info lists the content sources.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: lệnh `grep -c` in `0` cho mọi file; `CI PASSED`; các UI test v1 (đã sửa `completeOnboarding`) pass.

Mở bằng Read tool và xác nhận:
- `onboarding-3`: nút "Tôi đã hiểu" vẫn ở trang 3.
- `onboarding-4`: biểu tượng lịch, tiêu đề "Thai kỳ của bạn", đoạn mô tả; segmented "Ngày dự sinh | Kỳ kinh cuối"; bánh xe chọn ngày (ngày/tháng/năm tiếng Việt); nút "Lưu" (nổi bật) và "Để sau"; không có chữ bị cắt.
- `settings`: mục "Thai kỳ" có dòng "Nhập ngày thai kỳ" với giá trị "Chưa nhập"; **không** còn công tắc "Đặt ngày dự sinh"; không có nút xóa.
- `pregnancy-date-sheet`: tiêu đề "Ngày thai kỳ", nút "Hủy"/"Lưu", segmented, bánh xe, chú thích "Dùng ngày dự sinh bác sĩ đã báo…".
- `pregnancy-date-sheet-lmp`: segment "Kỳ kinh cuối" được chọn, tiêu đề mục "Ngày đầu kỳ kinh cuối", dòng đậm "Ngày dự sinh ước tính: …".
- `settings-pregnancy-set`: dòng "Ngày dự sinh" với ngày cụ thể, dòng phụ "Tính từ kỳ kinh cuối (…)", nút đỏ "Xóa thông tin thai kỳ".
- `medical-sources`: tiêu đề "Nguồn tham khảo", ghi chú, danh sách nguồn (có WHO, ACOG, NHS, Bộ Y tế) mỗi dòng có biểu tượng sách.
- `counter-with-week`: dòng "Tuần 20 + 0 ngày".

---
### Task 12: Tab Thai kỳ (trang chủ) + chi tiết tuần + 4 tab

**Files:**
- Create: `App/Pregnancy/PregnancyHomeView.swift`, `App/Pregnancy/PregnancyCards.swift`, `App/Pregnancy/WeekDetailView.swift`, `UITests/PregnancyScreenshotTests.swift`
- Modify: `App/RootView.swift` (thay toàn bộ), `App/Formatting.swift`, `Shared/L10n.swift`, `Shared/Localizable.xcstrings`, `UITests/UITestSupport.swift` (thêm `AppTab`/`openTab`), `UITests/PregnancyUITests.swift`, `UITests/KickCounterUITests.swift`, `UITests/ScreenshotTests.swift`

**Interfaces:**
- Consumes: `PregnancyTimeline` (Task 2); `WeeklyContentLibrary.clampedWeek(_:)`, `.display(forWeek:visibility:)`, `.upcomingMilestones(atWeek:visibility:)`, `.weekRange`, `WeekContent`, `Milestone`, `WeekDisplay`, `ContentLanguage.current` (Task 4); `AppointmentCoordinator.nextAppointment` (Task 8); `AppClock.now()`, `\.contentLibrary`, `BuildFlags.contentVisibility` (Task 10); `PregnancyDateSheet()` (Task 11); `L10n.counterWeek(_:)` (v1).
- Produces:
  - `enum AppTab: Hashable { case pregnancy, counter, history, settings }` (app); `struct PregnancyHomeView: View { init(onOpenCounter: @escaping () -> Void) }`; `struct WeekDetailView: View { init(currentWeek: Int) }`.
  - Thẻ dùng lại ở Task 13: `NextAppointmentCard(appointment: AppointmentRecord?, milestone: Milestone?, language: ContentLanguage)`, `PendingReviewBadge()`; modifier `View.card(tint:)`.
  - `Formatting.length(cm: Double?) -> String`, `Formatting.weight(grams: Double?) -> String` ("—" khi nil).
  - UI test: `enum AppTab: Int { case pregnancy = 0, counter, history, settings }`, `XCUIApplication.openTab(_:)`.

- [ ] **Step 1: Thêm chuỗi**

```bash
scripts/add-strings.py <<'JSON'
{
  "tab.pregnancy": ["Pregnancy", "Thai kỳ"],
  "pregnancy.title": ["My pregnancy", "Thai kỳ của mẹ"],
  "pregnancy.empty.title": ["When is your baby due?", "Bé dự sinh khi nào?"],
  "pregnancy.empty.body": ["Add your due date or the first day of your last period to follow your pregnancy week by week.", "Nhập ngày dự sinh hoặc ngày đầu kỳ kinh cuối để theo dõi thai kỳ từng tuần."],
  "pregnancy.empty.action": ["Add dates", "Nhập ngày"],
  "pregnancy.invalid.title": ["Please check your dates", "Mẹ kiểm tra lại ngày nhé"],
  "pregnancy.invalid.body": ["These dates don't match a current pregnancy (up to 44 weeks). Please check and correct them.", "Ngày đã nhập không khớp với một thai kỳ hiện tại (tối đa 44 tuần). Mẹ hãy kiểm tra và sửa lại."],
  "pregnancy.editDate": ["Edit dates", "Sửa ngày"],
  "pregnancy.trimester": ["Trimester %ld", "Tam cá nguyệt %ld"],
  "pregnancy.daysLeft": ["Days to go: %ld", "Còn %ld ngày"],
  "pregnancy.dueToday": ["Your due date is today", "Hôm nay là ngày dự sinh"],
  "pregnancy.pastDue.title": ["Days past your due date: %ld", "Đã qua ngày dự sinh %ld ngày"],
  "pregnancy.pastDue.body": ["Please contact your doctor or maternity unit to plan your check-ups and next steps.", "Mẹ hãy liên hệ bác sĩ hoặc cơ sở y tế để được theo dõi và tư vấn bước tiếp theo."],
  "pregnancy.baby.size": ["Your baby is about the size of %@", "Bé to bằng %@"],
  "pregnancy.baby.length": ["Length", "Chiều dài"],
  "pregnancy.baby.weight": ["Weight", "Cân nặng"],
  "pregnancy.tips.title": ["This week", "Tuần này mẹ nên"],
  "pregnancy.seeWeek": ["See this week", "Xem chi tiết tuần"],
  "pregnancy.appointment.title": ["Next check-up", "Lịch khám sắp tới"],
  "pregnancy.appointment.none": ["No check-ups planned", "Chưa có lịch khám"],
  "pregnancy.appointment.suggested": ["Suggested in weeks %1$ld–%2$ld", "Gợi ý vào tuần %1$ld–%2$ld"],
  "pregnancy.kickCard.title": ["Count kicks today", "Đếm cử động thai hôm nay"],
  "pregnancy.kickCard.body": ["From week 28, count your baby's movements once a day.", "Từ tuần 28, mẹ đếm cử động thai mỗi ngày một lần."],
  "week.title": ["Week %ld", "Tuần %ld"],
  "week.current": ["This week", "Tuần hiện tại"],
  "week.baby": ["Your baby", "Bé"],
  "week.mom": ["You", "Mẹ"],
  "week.tips": ["Tips", "Lời khuyên"],
  "week.warnings": ["When to get care right away", "Khi nào cần đi khám ngay"],
  "week.underReview": ["This week's content is being updated.", "Nội dung tuần này đang được cập nhật."],
  "week.pendingReview": ["Content pending doctor review", "Nội dung đang chờ bác sĩ duyệt"]
}
JSON
```
Expected: `121 strings`.

Trong `Shared/L10n.swift`:
- thêm sau `static var tabSettings …`:
```swift
    static var tabPregnancy: String { t("tab.pregnancy") }
```
- thêm trước `static var counterTitle …`:
```swift
    static var pregnancyTitle: String { t("pregnancy.title") }
    static var pregnancyEmptyTitle: String { t("pregnancy.empty.title") }
    static var pregnancyEmptyBody: String { t("pregnancy.empty.body") }
    static var pregnancyEmptyAction: String { t("pregnancy.empty.action") }
    static var pregnancyInvalidTitle: String { t("pregnancy.invalid.title") }
    static var pregnancyInvalidBody: String { t("pregnancy.invalid.body") }
    static var pregnancyEditDate: String { t("pregnancy.editDate") }
    static func pregnancyTrimester(_ number: Int) -> String { String(format: t("pregnancy.trimester"), number) }
    static func pregnancyDaysLeft(_ days: Int) -> String { String(format: t("pregnancy.daysLeft"), days) }
    static var pregnancyDueToday: String { t("pregnancy.dueToday") }
    static func pregnancyPastDueTitle(_ days: Int) -> String { String(format: t("pregnancy.pastDue.title"), days) }
    static var pregnancyPastDueBody: String { t("pregnancy.pastDue.body") }
    static func pregnancyBabySize(_ name: String) -> String { String(format: t("pregnancy.baby.size"), name) }
    static var pregnancyBabyLength: String { t("pregnancy.baby.length") }
    static var pregnancyBabyWeight: String { t("pregnancy.baby.weight") }
    static var pregnancyTipsTitle: String { t("pregnancy.tips.title") }
    static var pregnancySeeWeek: String { t("pregnancy.seeWeek") }
    static var pregnancyAppointmentTitle: String { t("pregnancy.appointment.title") }
    static var pregnancyAppointmentNone: String { t("pregnancy.appointment.none") }
    static func pregnancyAppointmentSuggested(_ from: Int, _ to: Int) -> String {
        String(format: t("pregnancy.appointment.suggested"), from, to)
    }
    static var pregnancyKickCardTitle: String { t("pregnancy.kickCard.title") }
    static var pregnancyKickCardBody: String { t("pregnancy.kickCard.body") }

    static func weekTitle(_ week: Int) -> String { String(format: t("week.title"), week) }
    static var weekCurrent: String { t("week.current") }
    static var weekBaby: String { t("week.baby") }
    static var weekMom: String { t("week.mom") }
    static var weekTips: String { t("week.tips") }
    static var weekWarnings: String { t("week.warnings") }
    static var weekUnderReview: String { t("week.underReview") }
    static var weekPendingReview: String { t("week.pendingReview") }

```

- [ ] **Step 2: Viết UI test trước (chạy trên CI cùng code)**

Thêm vào cuối `UITests/UITestSupport.swift`:
```swift
/// Tab order in RootView.
enum AppTab: Int {
    case pregnancy = 0
    case counter
    case history
    case settings
}

extension XCUIApplication {
    func openTab(_ tab: AppTab) {
        let button = tabBars.buttons.element(boundBy: tab.rawValue)
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }
}
```

Tab Thai kỳ trở thành tab mặc định, nên các test v1 phải mở tab Đếm/Lịch sử/Cài đặt theo tên:
- `UITests/KickCounterUITests.swift`: trong `setUp()`, ngay sau `completeOnboarding()` thêm `app.openTab(.counter)`; trong `testCountingTenMovementsShowsCompletionAndHistory`, thay `app.tabBars.buttons.element(boundBy: 1).tap()` bằng `app.openTab(.history)`.
- `UITests/ScreenshotTests.swift`: trong `launch(language:dark:)`, ngay trước `return app` thêm `app.openTab(.counter)`; trong `testHistoryScreens`, thay `app.tabBars.buttons.element(boundBy: 1).tap()` bằng `app.openTab(.history)`; trong `testOnboardingAndSettingsScreens`, thay `app.tabBars.buttons.element(boundBy: 2).tap()` bằng `app.openTab(.settings)` và `app.tabBars.buttons.element(boundBy: 0).tap()` bằng `app.openTab(.counter)`.
- `UITests/PregnancyUITests.swift`: trong `testCounterWeekLineUsesPinnedClockAndSeededDueDate`, ngay sau dòng `let app = …` thêm `app.openTab(.counter)`.

Kiểm tra không còn chỉ số tab cứng:
```bash
grep -n "tabBars.buttons.element(boundBy" UITests/*.swift
```
Expected: chỉ một dòng, trong `UITestSupport.swift` (`openTab`).

Thêm vào `final class PregnancyUITests` (`UITests/PregnancyUITests.swift`):
```swift
    @MainActor
    func testEnteringLastPeriodShowsMatchingWeek() {
        let app = XCUIApplication.launchPinned(language: "en")
        let addDates = app.buttons["pregnancyAddDateButton"]
        XCTAssertTrue(addDates.waitForExistence(timeout: 10))
        addDates.tap()

        let lastPeriod = app.segmentedControls.buttons["Last period"]
        XCTAssertTrue(lastPeriod.waitForExistence(timeout: 5))
        lastPeriod.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.element(boundBy: 2).waitForExistence(timeout: 5))
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "July") // en_US order: month, day, year
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "1")
        wheels.element(boundBy: 2).adjust(toPickerWheelValue: "2026")

        let estimate = app.staticTexts["pregnancyEstimatedDue"]
        XCTAssertTrue(estimate.waitForExistence(timeout: 5))
        XCTAssertTrue(estimate.label.contains("April 7, 2027"), estimate.label)
        app.buttons["pregnancyDateSave"].tap()

        // LMP 2026-07-01 → due 2027-04-07. On 2026-10-02 that is day 93 = 13w2d, 187 days to go.
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("Week 13 + 2 days"), progress.label)
        XCTAssertTrue(progress.label.contains("Trimester 1"), progress.label)
        XCTAssertTrue(progress.label.contains("Days to go: 187"), progress.label)
    }
```

`UITests/PregnancyScreenshotTests.swift`:
```swift
import XCTest

/// Screenshots of the Pregnancy tab at fixed gestational ages (see `UITestDates`).
final class PregnancyScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let homeWeeks = [
        ("12", UITestDates.dueAtWeek12),
        ("24", UITestDates.dueAtWeek24),
        ("38", UITestDates.dueAtWeek38),
    ]

    @MainActor
    func testPregnancyHomeScreens() {
        for (week, dueDate) in Self.homeWeeks {
            for language in ["vi", "en"] {
                for dark in [false, true] {
                    let name = "pregnancy-home-\(week)-\(language)-\(dark ? "dark" : "light")"
                    let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: dueDate)
                    XCTAssertTrue(app.descendants(matching: .any)["weekProgressCard"].waitForExistence(timeout: 10), name)
                    attachScreenshot(app, name)
                    if week == "38", language == "vi", !dark {
                        app.swipeUp()
                        XCTAssertTrue(app.buttons["kickCountCard"].waitForExistence(timeout: 5))
                        attachScreenshot(app, "pregnancy-home-38-vi-light-bottom")
                    }
                    app.terminate()
                }
            }
        }
    }

    @MainActor
    func testPastDueScreen() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueSevenDaysAgo)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("Days past your due date: 7"), progress.label)
        attachScreenshot(app, "pregnancy-home-pastdue-en")
    }

    @MainActor
    func testWeekDetailScreens() {
        for (language, dark) in [("vi", false), ("vi", true), ("en", false)] {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            let babyCard = app.buttons["babySizeCard"]
            XCTAssertTrue(babyCard.waitForExistence(timeout: 10))
            babyCard.tap()
            XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "week-24-\(suffix)")
            app.swipeUp()
            attachScreenshot(app, "week-24-warnings-\(suffix)")
            if language == "vi", !dark {
                app.swipeLeft()
                XCTAssertTrue(app.navigationBars.staticTexts["Tuần 25"].waitForExistence(timeout: 5))
                attachScreenshot(app, "week-25-vi-light")
            }
            app.terminate()
        }
    }

    @MainActor
    func testEmptyStateScreens() {
        for (language, dark) in [("vi", false), ("vi", true), ("en", false)] {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark)
            let addDates = app.buttons["pregnancyAddDateButton"]
            XCTAssertTrue(addDates.waitForExistence(timeout: 10))
            attachScreenshot(app, "pregnancy-empty-\(suffix)")
            if language == "vi", !dark {
                addDates.tap()
                XCTAssertTrue(app.buttons["pregnancyDateSave"].waitForExistence(timeout: 5))
                attachScreenshot(app, "pregnancy-date-sheet-from-home-vi")
            }
            app.terminate()
        }
    }
}
```

- [ ] **Step 3: Định dạng chiều dài/cân nặng**

Thay toàn bộ `App/Formatting.swift`:
```swift
import Foundation

enum Formatting {
    /// Shown when a value is not available (e.g. baby measurements before week 8).
    static let missingValue = "—"

    /// e.g. "23 min", "1 hr, 5 min", "45 sec" — localized by the system.
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }

    /// e.g. "30 cm", "1,6 cm" — localized by the system.
    static func length(cm: Double?) -> String {
        guard let cm else { return missingValue }
        return Measurement(value: cm, unit: UnitLength.centimeters).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1)))
        )
    }

    /// Grams below 1 kg ("600 g"), kilograms above ("3,08 kg").
    static func weight(grams: Double?) -> String {
        guard let grams else { return missingValue }
        if grams >= 1000 {
            return Measurement(value: grams / 1000, unit: UnitMass.kilograms).formatted(
                .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...2)))
            )
        }
        return Measurement(value: grams, unit: UnitMass.grams).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))
        )
    }
}
```

- [ ] **Step 4: Các thẻ**

`App/Pregnancy/PregnancyCards.swift`:
```swift
import KickCore
import SwiftUI

extension View {
    /// Rounded card used across the Pregnancy and Appointments screens.
    func card(tint: Color = Color(.secondarySystemBackground)) -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct WeekProgressCard: View {
    let timeline: PregnancyTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.counterWeek(timeline.week))
                .font(.title2.bold())
            Text(L10n.pregnancyTrimester(timeline.trimester.rawValue))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: timeline.progress)
                .tint(timeline.isPastDue ? Color.orange : Color.accentColor)
            if timeline.isPastDue {
                Text(L10n.pregnancyPastDueTitle(timeline.daysPastDue))
                    .font(.headline)
                Text(L10n.pregnancyPastDueBody)
                    .font(.subheadline)
            } else if timeline.daysRemaining == 0 {
                Text(L10n.pregnancyDueToday)
                    .font(.headline)
            } else {
                Text(L10n.pregnancyDaysLeft(timeline.daysRemaining))
                    .font(.headline)
            }
        }
        .card(tint: timeline.isPastDue ? Color.orange.opacity(0.12) : Color(.secondarySystemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekProgressCard")
    }
}

struct BabySizeCard: View {
    let week: WeekContent
    let language: ContentLanguage
    let pendingReview: Bool
    var showsDisclosure = true
    @ScaledMetric(relativeTo: .largeTitle) private var emojiSize: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Text(week.size.emoji)
                    .font(.system(size: emojiSize))
                    .accessibilityLabel(week.size.name(language))
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.pregnancyBabySize(week.size.name(language)))
                        .font(.headline)
                    HStack(spacing: 24) {
                        LabeledValue(title: L10n.pregnancyBabyLength, value: Formatting.length(cm: week.lengthCm))
                        LabeledValue(title: L10n.pregnancyBabyWeight, value: Formatting.weight(grams: week.weightG))
                    }
                }
                Spacer(minLength: 0)
                if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            if pendingReview {
                PendingReviewBadge()
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct LabeledValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }
}

struct PendingReviewBadge: View {
    var body: some View {
        Label(L10n.weekPendingReview, systemImage: "stethoscope")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .accessibilityIdentifier("pendingReviewBadge")
    }
}

struct WeekTipsCard: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.pregnancyTipsTitle)
                .font(.headline)
            ForEach(tips, id: \.self) { tip in
                Label {
                    Text(tip)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .font(.subheadline)
            }
            Text(L10n.pregnancySeeWeek)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct UnderReviewCard: View {
    var body: some View {
        Label(L10n.weekUnderReview, systemImage: "hourglass")
            .font(.subheadline)
            .card()
            .accessibilityElement(children: .combine)
    }
}

struct NextAppointmentCard: View {
    let appointment: AppointmentRecord?
    let milestone: Milestone?
    let language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.pregnancyAppointmentTitle, systemImage: "calendar")
                .font(.headline)
            if let appointment {
                Text(appointment.title)
                    .font(.subheadline.weight(.semibold))
                Text(appointment.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let milestone {
                Text(milestone.title.text(language))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.pregnancyAppointmentSuggested(milestone.fromWeek, milestone.toWeek))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.pregnancyAppointmentNone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct KickCountCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.pregnancyKickCardTitle)
                    .font(.headline)
                Text(L10n.pregnancyKickCardBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 5: Trang chủ Thai kỳ**

`App/Pregnancy/PregnancyHomeView.swift`:
```swift
import KickCore
import SwiftUI

/// Tab 1 (default): where the pregnancy stands today, the baby this week,
/// tips, the next check-up and — from week 28 — a nudge to count kicks.
struct PregnancyHomeView: View {
    let onOpenCounter: () -> Void

    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.contentLibrary) private var library
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var showingDateSheet = false
    @State private var detailWeek: Int?

    private let language = ContentLanguage.current
    private let visibility = BuildFlags.contentVisibility

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.pregnancyTitle)
                .toolbar {
                    if dueDate > 0 {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showingDateSheet = true
                            } label: {
                                Label(L10n.pregnancyEditDate, systemImage: "calendar")
                            }
                            .accessibilityIdentifier("pregnancyEditDateButton")
                        }
                    }
                }
                .navigationDestination(item: $detailWeek) { week in
                    WeekDetailView(currentWeek: week)
                }
                .sheet(isPresented: $showingDateSheet) {
                    PregnancyDateSheet()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if dueDate <= 0 {
            ContentUnavailableView {
                Label(L10n.pregnancyEmptyTitle, systemImage: "calendar.badge.plus")
            } description: {
                Text(L10n.pregnancyEmptyBody)
            } actions: {
                Button(L10n.pregnancyEmptyAction) { showingDateSheet = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pregnancyAddDateButton")
            }
        } else if let timeline = PregnancyTimeline(dueDate: Date(timeIntervalSince1970: dueDate), now: AppClock.now()) {
            ScrollView {
                cards(for: timeline)
                    .padding()
            }
        } else {
            ContentUnavailableView {
                Label(L10n.pregnancyInvalidTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(L10n.pregnancyInvalidBody)
            } actions: {
                Button(L10n.pregnancyEditDate) { showingDateSheet = true }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("pregnancyFixDateButton")
            }
        }
    }

    private func cards(for timeline: PregnancyTimeline) -> some View {
        let contentWeek = WeeklyContentLibrary.clampedWeek(timeline.week.weeks)
        let display = library?.display(forWeek: contentWeek, visibility: visibility)
        return VStack(spacing: 16) {
            WeekProgressCard(timeline: timeline)

            switch display {
            case .content(let week, let pendingReview)?:
                Button { detailWeek = contentWeek } label: {
                    BabySizeCard(week: week, language: language, pendingReview: pendingReview)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("babySizeCard")

                Button { detailWeek = contentWeek } label: {
                    WeekTipsCard(tips: Array(week.tips.items(language).prefix(2)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("weekTipsCard")
            case .underReview?:
                Button { detailWeek = contentWeek } label: { UnderReviewCard() }
                    .buttonStyle(.plain)
            case nil:
                EmptyView()
            }

            NextAppointmentCard(
                appointment: appointments.nextAppointment,
                milestone: library?.upcomingMilestones(atWeek: timeline.week.weeks, visibility: visibility).first,
                language: language
            )
            .accessibilityIdentifier("nextAppointmentCard")

            if timeline.isKickCountingWeek {
                Button(action: onOpenCounter) { KickCountCard() }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("kickCountCard")
            }
        }
    }
}
```

- [ ] **Step 6: Chi tiết tuần (vuốt qua lại tuần 4–42)**

`App/Pregnancy/WeekDetailView.swift`:
```swift
import KickCore
import SwiftUI

/// Week-by-week pages 4…42, opening on the current week.
struct WeekDetailView: View {
    let currentWeek: Int
    @State private var selection: Int

    init(currentWeek: Int) {
        self.currentWeek = currentWeek
        _selection = State(initialValue: currentWeek)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(WeeklyContentLibrary.weekRange), id: \.self) { week in
                WeekPage(week: week, isCurrentWeek: week == currentWeek)
                    .tag(week)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemBackground))
        .navigationTitle(L10n.weekTitle(selection))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeekPage: View {
    let week: Int
    let isCurrentWeek: Bool
    @Environment(\.contentLibrary) private var library
    private let language = ContentLanguage.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isCurrentWeek {
                    Text(L10n.weekCurrent)
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                switch library?.display(forWeek: week, visibility: BuildFlags.contentVisibility) {
                case .content(let content, let pendingReview)?:
                    BabySizeCard(week: content, language: language, pendingReview: pendingReview, showsDisclosure: false)
                    WeekSection(title: L10n.weekBaby, systemImage: "figure.and.child.holdinghands", items: content.baby.items(language))
                    WeekSection(title: L10n.weekMom, systemImage: "heart.fill", items: content.mom.items(language))
                    WeekSection(title: L10n.weekTips, systemImage: "lightbulb.fill", items: content.tips.items(language))
                    WarningSection(items: content.warnings.items(language))
                case .underReview?:
                    UnderReviewCard()
                case nil:
                    EmptyView()
                }
            }
            .padding()
        }
    }
}

private struct WeekSection: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").accessibilityHidden(true)
                    Text(item)
                }
                .font(.body)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// "When to get care right away" — orange like the 2-hour overdue banner.
private struct WarningSection: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.weekWarnings, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").accessibilityHidden(true)
                    Text(item)
                }
                .font(.body)
            }
        }
        .card(tint: Color.orange.opacity(0.12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekWarnings")
    }
}
```

- [ ] **Step 7: 4 tab, Thai kỳ mặc định**

Thay toàn bộ `App/RootView.swift`:
```swift
import KickCore
import SwiftUI

enum AppTab: Hashable {
    case pregnancy
    case counter
    case history
    case settings
}

struct RootView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasCompletedOnboarding, store: AppGroup.defaults)
    private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab = .pregnancy

    var body: some View {
        TabView(selection: $selectedTab) {
            PregnancyHomeView { selectedTab = .counter }
                .tabItem { Label(L10n.tabPregnancy, systemImage: "heart.text.square.fill") }
                .tag(AppTab.pregnancy)
            CounterView()
                .tabItem { Label(L10n.tabCounter, systemImage: "hand.tap.fill") }
                .tag(AppTab.counter)
            HistoryView()
                .tabItem { Label(L10n.tabHistory, systemImage: "chart.bar.fill") }
                .tag(AppTab.history)
            SettingsView()
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        .task { await reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
    }

    private func reload() async {
        await coordinator.load()
        await appointments.load()
    }
}
```

- [ ] **Step 8: Commit, push, xác minh trên CI**

```bash
scripts/test-core.sh
git add App Shared UITests
git commit -F - <<'MSG'
feat(app): add the Pregnancy tab with week cards and week-by-week detail

Pregnancy becomes the default of four tabs; UI tests open tabs by name.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, gồm `PregnancyUITests.testEnteringLastPeriodShowsMatchingWeek`, `PregnancyScreenshotTests` và mọi test v1.

Mở bằng Read tool và xác nhận:
- `pregnancy-home-24-vi-light`: tiêu đề "Thai kỳ của mẹ"; thẻ tuần "Tuần 24 + 3 ngày", "Tam cá nguyệt 2", thanh tiến độ khoảng 60%, "Còn 109 ngày"; thẻ bé 🌽 "Bé to bằng một bắp ngô", "Chiều dài 30 cm", "Cân nặng 600 g", nhãn "Nội dung đang chờ bác sĩ duyệt" (bản Debug, nội dung `reviewed: false`); thẻ "Tuần này mẹ nên" đúng 2 ý + "Xem chi tiết tuần"; thẻ "Lịch khám sắp tới" hiện mốc tiểu đường thai kỳ với "Gợi ý vào tuần 24–28"; **không** có thẻ đếm cử động; thanh tab 4 mục, "Thai kỳ" được chọn.
- `pregnancy-home-24-vi-dark`: cùng nội dung, nền tối, chữ và thẻ đủ tương phản.
- `pregnancy-home-24-en-light`/`-dark`: "Week 24 + 3 days", "Trimester 2", "Days to go: 109", "Your baby is about the size of an ear of corn".
- `pregnancy-home-12-*`: "Tuần 12 + 0 ngày"/"Week 12 + 0 days", "Tam cá nguyệt 1", "Còn 196 ngày"; thẻ lịch khám gợi ý mốc đo độ mờ da gáy "tuần 11–14".
- `pregnancy-home-38-*`: "Tuần 38 + 0 ngày", "Tam cá nguyệt 3", "Còn 14 ngày", cân nặng dạng kg (ví dụ "3,08 kg"). `pregnancy-home-38-vi-light-bottom`: thẻ "Đếm cử động thai hôm nay" có chevron, thẻ lịch khám gợi ý "khám hằng tuần" tuần 37–40.
- `pregnancy-home-pastdue-en`: thẻ tuần nền cam nhạt, "Week 41 + 0 days", "Days past your due date: 7", lời khuyên liên hệ bác sĩ; nội dung bé của tuần 41.
- `week-24-*`: tiêu đề điều hướng "Tuần 24"/"Week 24", nhãn "Tuần hiện tại", thẻ bé không có chevron, các mục "Bé", "Mẹ", "Lời khuyên" có gạch đầu dòng. `week-24-warnings-*`: mục cam "Khi nào cần đi khám ngay" với biểu tượng tam giác, mọi ý nhắc liên hệ bác sĩ/cơ sở y tế. `week-25-vi-light`: tiêu đề "Tuần 25", không có nhãn "Tuần hiện tại".
- `pregnancy-empty-*`: biểu tượng lịch, "Bé dự sinh khi nào?"/"When is your baby due?", mô tả, nút "Nhập ngày"/"Add dates". `pregnancy-date-sheet-from-home-vi`: sheet giống Task 11.
- Ảnh v1 (`counter-*`, `history-*`, `settings*`, `counter-with-week`) vẫn đúng như trước, với tab "Đếm"/"Lịch sử"/"Cài đặt" được chọn tương ứng.

---

### Task 13: Màn Lịch khám (sắp tới / đã qua / mốc gợi ý) + thêm, sửa, xóa, đánh dấu đã khám

**Files:**
- Create: `App/Appointments/AppointmentsView.swift`, `App/Appointments/AppointmentEditorSheet.swift`, `App/Appointments/AppointmentRows.swift`
- Modify: `App/Pregnancy/PregnancyHomeView.swift` (thẻ lịch khám mở `AppointmentsView`), `Shared/L10n.swift`, `Shared/Localizable.xcstrings`, `UITests/PregnancyUITests.swift`, `UITests/PregnancyScreenshotTests.swift`

**Interfaces:**
- Consumes: `AppointmentCoordinator.upcoming/.past/.failure/.notificationsDenied/.load()/.add(date:title:note:milestoneID:)/.update(_:)/.delete(id:)/.markDone(id:)/.clearFailure()` (Task 8); `AppointmentPrefill.nextDefaultDate(now:)`, `.suggestedDate(for:dueDate:now:)` (Task 7); `WeeklyContentLibrary.upcomingMilestones(atWeek:visibility:)`, `Milestone` (Task 4); `PregnancyTimeline` (Task 2); `AppClock.now()`, `\.contentLibrary`, `BuildFlags.contentVisibility` (Task 10); `NextAppointmentCard`, `PendingReviewBadge` (Task 12).
- Produces: `struct AppointmentsView: View { init() }`; `enum AppointmentEditorMode: Identifiable { case new(date: Date, title: String, milestoneID: String?); case edit(AppointmentRecord) }`; `struct AppointmentEditorSheet: View { init(mode: AppointmentEditorMode) }`; `AppointmentRow(record:)`, `MilestoneRow(milestone:language:onAdd:)`; `L10n.milestoneWeeks(_:_:)` và các `L10n.appointments…` ở Step 1.

- [ ] **Step 1: Thêm chuỗi**

```bash
scripts/add-strings.py <<'JSON'
{
  "appointments.title": ["Check-ups", "Lịch khám"],
  "appointments.upcoming": ["Upcoming", "Sắp tới"],
  "appointments.past": ["Past", "Đã qua"],
  "appointments.empty": ["No upcoming check-ups. Add one, or pick a suggested milestone below.", "Chưa có lịch khám sắp tới. Mẹ thêm lịch mới hoặc chọn mốc gợi ý bên dưới."],
  "appointments.add": ["Add check-up", "Thêm lịch khám"],
  "appointments.edit": ["Edit check-up", "Sửa lịch khám"],
  "appointments.field.title": ["Title", "Tiêu đề"],
  "appointments.field.date": ["Date & time", "Ngày giờ"],
  "appointments.field.note": ["Note", "Ghi chú"],
  "appointments.markDone": ["Mark as done", "Đánh dấu đã khám"],
  "appointments.status.done": ["Done", "Đã khám"],
  "appointments.milestones": ["Suggested milestones", "Mốc gợi ý"],
  "appointments.milestone.add": ["Add to my check-ups", "Thêm vào lịch"],
  "appointments.notificationsOff": ["Notifications are off, so you won't get a reminder the day before. Turn them on in Settings.", "Thông báo đang tắt nên app không nhắc được trước 1 ngày. Mẹ bật thông báo trong Cài đặt nhé."],
  "appointments.delete.confirm.title": ["Delete this check-up?", "Xóa lịch khám này?"],
  "milestone.weeks": ["Weeks %1$ld–%2$ld", "Tuần %1$ld–%2$ld"]
}
JSON
```
Expected: `137 strings`.

Trong `Shared/L10n.swift`, thêm sau `static var appointmentsReminderBody …`:
```swift
    static var appointmentsTitle: String { t("appointments.title") }
    static var appointmentsUpcoming: String { t("appointments.upcoming") }
    static var appointmentsPast: String { t("appointments.past") }
    static var appointmentsEmpty: String { t("appointments.empty") }
    static var appointmentsAdd: String { t("appointments.add") }
    static var appointmentsEdit: String { t("appointments.edit") }
    static var appointmentsFieldTitle: String { t("appointments.field.title") }
    static var appointmentsFieldDate: String { t("appointments.field.date") }
    static var appointmentsFieldNote: String { t("appointments.field.note") }
    static var appointmentsMarkDone: String { t("appointments.markDone") }
    static var appointmentsStatusDone: String { t("appointments.status.done") }
    static var appointmentsMilestones: String { t("appointments.milestones") }
    static var appointmentsMilestoneAdd: String { t("appointments.milestone.add") }
    static var appointmentsNotificationsOff: String { t("appointments.notificationsOff") }
    static var appointmentsDeleteConfirmTitle: String { t("appointments.delete.confirm.title") }
    static func milestoneWeeks(_ from: Int, _ to: Int) -> String { String(format: t("milestone.weeks"), from, to) }
```

- [ ] **Step 2: Viết UI test trước (chạy trên CI cùng code)**

Thêm vào `final class PregnancyUITests`:
```swift
    @MainActor
    func testAddedAppointmentAppearsInUpcoming() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let card = app.buttons["nextAppointmentCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()

        let add = app.buttons["addAppointmentButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let title = app.textFields["appointmentTitleField"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Glucose test")
        app.buttons["appointmentSaveButton"].tap()

        // Default date is tomorrow 9:00, so it belongs under "Upcoming", above the milestones.
        let row = app.buttons.matching(NSPredicate(format: "identifier == 'appointmentRow' AND label CONTAINS 'Glucose test'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let upcomingHeader = app.staticTexts["upcomingHeader"]
        let milestonesHeader = app.staticTexts["milestonesHeader"]
        XCTAssertTrue(upcomingHeader.exists)
        XCTAssertTrue(milestonesHeader.exists)
        XCTAssertLessThan(upcomingHeader.frame.minY, row.frame.minY)
        XCTAssertLessThan(row.frame.maxY, milestonesHeader.frame.minY)
        XCTAssertFalse(app.staticTexts["pastHeader"].exists)

        // The home card now shows it as the next check-up.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("Glucose test"), card.label)
    }
```

Thêm vào `final class PregnancyScreenshotTests`:
```swift
    @MainActor
    func testAppointmentsScreens() {
        for (language, dark) in [("vi", false), ("vi", true), ("en", false)] {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            let card = app.buttons["nextAppointmentCard"]
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            card.tap()
            let add = app.buttons["addAppointmentButton"]
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            attachScreenshot(app, "appointments-empty-\(suffix)")

            if language == "vi", !dark {
                // Add the first two suggested milestones (week 24–28, then 27–36).
                for index in 0..<2 {
                    app.buttons.matching(identifier: "addMilestoneButton").firstMatch.tap()
                    let save = app.buttons["appointmentSaveButton"]
                    XCTAssertTrue(save.waitForExistence(timeout: 5))
                    if index == 0 { attachScreenshot(app, "appointment-editor-milestone-vi") }
                    save.tap()
                    XCTAssertTrue(add.waitForExistence(timeout: 5))
                }
                let firstRow = app.buttons.matching(identifier: "appointmentRow").firstMatch
                XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
                attachScreenshot(app, "appointments-upcoming-vi-light")

                firstRow.tap()
                let markDone = app.buttons["appointmentMarkDoneButton"]
                XCTAssertTrue(markDone.waitForExistence(timeout: 5))
                attachScreenshot(app, "appointment-editor-edit-vi")
                markDone.tap()
                XCTAssertTrue(app.staticTexts["pastHeader"].waitForExistence(timeout: 5))
                attachScreenshot(app, "appointments-with-past-vi-light")

                app.navigationBars.buttons.element(boundBy: 0).tap()
                XCTAssertTrue(card.waitForExistence(timeout: 5))
                attachScreenshot(app, "pregnancy-home-with-appointment-vi-light")
            }
            app.terminate()
        }
    }
```

- [ ] **Step 3: Các dòng danh sách**

`App/Appointments/AppointmentRows.swift`:
```swift
import KickCore
import SwiftUI

struct AppointmentRow: View {
    let record: AppointmentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(record.title)
                    .font(.body.weight(.semibold))
                if record.isDone {
                    Label(L10n.appointmentsStatusDone, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct MilestoneRow: View {
    let milestone: Milestone
    let language: ContentLanguage
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title.text(language))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.milestoneWeeks(milestone.fromWeek, milestone.toWeek))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(milestone.detail.text(language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !milestone.reviewed {
                    PendingReviewBadge()
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Label(L10n.appointmentsMilestoneAdd, systemImage: "calendar.badge.plus")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("addMilestoneButton")
        }
    }
}
```

- [ ] **Step 4: Sheet thêm/sửa**

`App/Appointments/AppointmentEditorSheet.swift`:
```swift
import KickCore
import SwiftUI

enum AppointmentEditorMode: Identifiable {
    case new(date: Date, title: String, milestoneID: String?)
    case edit(AppointmentRecord)

    var id: String {
        switch self {
        case .new(_, _, let milestoneID): "new-\(milestoneID ?? "custom")"
        case .edit(let record): record.id.uuidString
        }
    }
}

struct AppointmentEditorSheet: View {
    let mode: AppointmentEditorMode

    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var title: String
    @State private var note: String
    @State private var saving = false
    @State private var saveFailed = false

    init(mode: AppointmentEditorMode) {
        self.mode = mode
        switch mode {
        case .new(let date, let title, _):
            _date = State(initialValue: date)
            _title = State(initialValue: title)
            _note = State(initialValue: "")
        case .edit(let record):
            _date = State(initialValue: record.date)
            _title = State(initialValue: record.title)
            _note = State(initialValue: record.note)
        }
    }

    private var editedRecord: AppointmentRecord? {
        if case .edit(let record) = mode { return record }
        return nil
    }

    private var canSave: Bool {
        !saving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.appointmentsFieldTitle, text: $title)
                        .accessibilityIdentifier("appointmentTitleField")
                    DatePicker(L10n.appointmentsFieldDate, selection: $date)
                        .accessibilityIdentifier("appointmentDatePicker")
                }
                Section(L10n.appointmentsFieldNote) {
                    TextField(L10n.appointmentsFieldNote, text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let record = editedRecord, !record.isDone {
                    Section {
                        Button(L10n.appointmentsMarkDone) {
                            Task {
                                await appointments.markDone(id: record.id)
                                dismiss()
                            }
                        }
                        .accessibilityIdentifier("appointmentMarkDoneButton")
                    }
                }
            }
            .navigationTitle(editedRecord == nil ? L10n.appointmentsAdd : L10n.appointmentsEdit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) { Task { await save() } }
                        .disabled(!canSave)
                        .accessibilityIdentifier("appointmentSaveButton")
                }
            }
            .alert(L10n.errorSave, isPresented: $saveFailed) {
                Button(L10n.commonOK) {}
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let succeeded: Bool
        switch mode {
        case .new(_, _, let milestoneID):
            succeeded = await appointments.add(date: date, title: title, note: note, milestoneID: milestoneID) != nil
        case .edit(let record):
            var updated = record
            updated.date = date
            updated.title = title
            updated.note = note
            succeeded = await appointments.update(updated)
        }
        if succeeded {
            dismiss()
        } else {
            // Shown here rather than on the list, which is covered by this sheet.
            appointments.clearFailure()
            saveFailed = true
        }
    }
}
```

- [ ] **Step 5: Màn Lịch khám**

`App/Appointments/AppointmentsView.swift`:
```swift
import KickCore
import SwiftUI

/// Upcoming and past check-ups plus the suggested milestones still ahead.
struct AppointmentsView: View {
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.contentLibrary) private var library
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var editor: AppointmentEditorMode?
    @State private var pendingDelete: AppointmentRecord?

    private let language = ContentLanguage.current

    private var dueDateValue: Date? {
        dueDate > 0 ? Date(timeIntervalSince1970: dueDate) : nil
    }

    private var currentWeek: Int {
        guard let dueDateValue, let timeline = PregnancyTimeline(dueDate: dueDateValue, now: AppClock.now()) else { return 0 }
        return timeline.week.weeks
    }

    /// Milestones still ahead that the mother hasn't added yet.
    private var suggestedMilestones: [Milestone] {
        let added = Set((appointments.upcoming + appointments.past).compactMap(\.milestoneID))
        let ahead = library?.upcomingMilestones(atWeek: currentWeek, visibility: BuildFlags.contentVisibility) ?? []
        return ahead.filter { !added.contains($0.id) }
    }

    var body: some View {
        List {
            if appointments.notificationsDenied {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.appointmentsNotificationsOff)
                            .font(.footnote)
                        Button(L10n.settingsOpenSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
            }

            Section {
                if appointments.upcoming.isEmpty {
                    Text(L10n.appointmentsEmpty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(appointments.upcoming) { record in
                    row(for: record)
                }
            } header: {
                Text(L10n.appointmentsUpcoming)
                    .accessibilityIdentifier("upcomingHeader")
            }

            if !suggestedMilestones.isEmpty {
                Section {
                    ForEach(suggestedMilestones) { milestone in
                        MilestoneRow(milestone: milestone, language: language) {
                            editor = .new(
                                date: AppointmentPrefill.suggestedDate(for: milestone, dueDate: dueDateValue, now: AppClock.now()),
                                title: milestone.title.text(language),
                                milestoneID: milestone.id
                            )
                        }
                    }
                } header: {
                    Text(L10n.appointmentsMilestones)
                        .accessibilityIdentifier("milestonesHeader")
                }
            }

            if !appointments.past.isEmpty {
                Section {
                    ForEach(appointments.past) { record in
                        row(for: record)
                    }
                } header: {
                    Text(L10n.appointmentsPast)
                        .accessibilityIdentifier("pastHeader")
                }
            }
        }
        .navigationTitle(L10n.appointmentsTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = .new(date: AppointmentPrefill.nextDefaultDate(now: AppClock.now()), title: "", milestoneID: nil)
                } label: {
                    Label(L10n.appointmentsAdd, systemImage: "plus")
                }
                .accessibilityIdentifier("addAppointmentButton")
            }
        }
        .sheet(item: $editor) { mode in
            AppointmentEditorSheet(mode: mode)
        }
        .confirmationDialog(
            L10n.appointmentsDeleteConfirmTitle,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                if let record = pendingDelete {
                    Task { await appointments.delete(id: record.id) }
                }
                pendingDelete = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        }
        .alert(failureMessage ?? "", isPresented: failureBinding) {
            Button(L10n.commonOK) { appointments.clearFailure() }
        }
        .task { await appointments.load() }
    }

    private func row(for record: AppointmentRecord) -> some View {
        Button {
            editor = .edit(record)
        } label: {
            AppointmentRow(record: record)
        }
        .tint(.primary)
        .accessibilityIdentifier("appointmentRow")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDelete = record
            } label: {
                Label(L10n.commonDelete, systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            if !record.isDone {
                Button {
                    Task { await appointments.markDone(id: record.id) }
                } label: {
                    Label(L10n.appointmentsMarkDone, systemImage: "checkmark")
                }
                .tint(.green)
            }
        }
    }

    private var failureMessage: String? {
        switch appointments.failure {
        case .saveFailed: L10n.errorSave
        case .loadFailed: L10n.errorLoad
        case nil: nil
        }
    }

    /// Only while no editor sheet is open: the sheet reports its own save errors.
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { appointments.failure != nil && editor == nil },
            set: { if !$0 { appointments.clearFailure() } }
        )
    }
}
```

- [ ] **Step 6: Thẻ "Lịch khám sắp tới" ở trang chủ mở màn Lịch khám**

Trong `App/Pregnancy/PregnancyHomeView.swift`, thay:
```swift
            NextAppointmentCard(
                appointment: appointments.nextAppointment,
                milestone: library?.upcomingMilestones(atWeek: timeline.week.weeks, visibility: visibility).first,
                language: language
            )
            .accessibilityIdentifier("nextAppointmentCard")
```
bằng:
```swift
            NavigationLink {
                AppointmentsView()
            } label: {
                NextAppointmentCard(
                    appointment: appointments.nextAppointment,
                    milestone: library?.upcomingMilestones(atWeek: timeline.week.weeks, visibility: visibility).first,
                    language: language
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nextAppointmentCard")
```

- [ ] **Step 7: Commit, push, xác minh trên CI**

```bash
scripts/test-core.sh
git add App Shared UITests
git commit -F - <<'MSG'
feat(app): add check-ups screen with suggested milestones and reminders

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, gồm `PregnancyUITests.testAddedAppointmentAppearsInUpcoming` và `PregnancyScreenshotTests.testAppointmentsScreens`.

Mở bằng Read tool và xác nhận:
- `appointments-empty-vi-light`: tiêu đề "Lịch khám", nút "+" trên thanh điều hướng; dòng "Thông báo đang tắt nên app không nhắc được trước 1 ngày…" + "Mở Cài đặt" (UI test tắt thông báo); mục "Sắp tới" với dòng "Chưa có lịch khám sắp tới…"; mục "Mốc gợi ý" bắt đầu bằng mốc tiểu đường thai kỳ "Tuần 24–28", có mô tả, nhãn "Nội dung đang chờ bác sĩ duyệt" và nút lịch "+"; không có mục "Đã qua".
- `appointments-empty-vi-dark`, `appointments-empty-en-light`: cùng bố cục; bản en là "Check-ups", "Upcoming", "Suggested milestones", "Weeks 24–28".
- `appointment-editor-milestone-vi`: sheet "Thêm lịch khám", tiêu đề điền sẵn tên mốc, ngày giờ là ngày mai (3 thg 10, 2026) 09:00, nút "Lưu" bật.
- `appointments-upcoming-vi-light`: "Sắp tới" có 2 dòng theo thứ tự ngày (mốc tiểu đường 3/10, mốc uốn ván/ho gà 20/10 lúc 09:00); hai mốc đó không còn trong "Mốc gợi ý".
- `appointment-editor-edit-vi`: sheet "Sửa lịch khám" có nút "Đánh dấu đã khám".
- `appointments-with-past-vi-light`: "Sắp tới" còn 1 dòng; mục "Đã qua" có dòng đã khám với nhãn xanh "Đã khám".
- `pregnancy-home-with-appointment-vi-light`: thẻ "Lịch khám sắp tới" hiện tên lịch hẹn uốn ván/ho gà và ngày 20 thg 10, 2026 09:00 (không còn chữ "Gợi ý vào tuần").

---

### Task 14: Chuẩn bị phát hành — checklist, kiểm thử TestFlight, bác sĩ duyệt nội dung

**Files:**
- Modify: `docs/release-checklist.md`

**Interfaces:**
- Consumes: toàn bộ các task trước; workflow `testflight.yml` (truyền `CONTENT_PREVIEW=1`, Task 10); `scripts/check-bundle-versions.sh` (Task 1).
- Produces: checklist phát hành giai đoạn 2.

- [ ] **Step 1: Bổ sung checklist**

Thêm vào cuối `docs/release-checklist.md`:
```markdown

## Giai đoạn 2 — Hành trình thai kỳ

### Trước khi gửi App Store
- [ ] Bác sĩ sản khoa đã duyệt `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`;
      mỗi tuần/mốc đã duyệt được đổi `reviewed` thành `true` (commit riêng, ghi tên người duyệt và ngày duyệt trong commit message).
      `scripts/test-core.sh` xanh sau khi đổi.
- [ ] Không còn mục chưa duyệt — lệnh sau in ra `[] []`:
      `python3 -c "import json;d=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'));print([w['week'] for w in d['weeks'] if not w['reviewed']],[m['id'] for m in d['milestones'] if not m['reviewed']])"`
- [ ] Workflow phát hành App Store (khi tạo) **không** đặt `CONTENT_PREVIEW`.
- [ ] CloudKit Console: record type `CD_Appointment` có trong Development (sau khi một bản build có iCloud đã lưu một lịch hẹn),
      rồi **Deploy Schema Changes** lên Production — làm cùng lần với bước deploy schema của v1.
- [ ] Ảnh chụp App Store mới cho tab Thai kỳ (vi + en): `ci-artifacts/screenshots/pregnancy-home-24-*`, `week-24-*`, `appointments-*`.
- [ ] Ghi chú phát hành: tab Thai kỳ; nội dung bé + mẹ tuần 4–42; lịch khám có nhắc trước 1 ngày; nhập ngày dự sinh hoặc ngày đầu kỳ kinh cuối.

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en)
- [ ] TestFlight hiện build number bằng số run của workflow TestFlight (không còn "1").
- [ ] Tuần chưa duyệt hiện nhãn "Nội dung đang chờ bác sĩ duyệt" (chứng tỏ `CONTENT_PREVIEW` có hiệu lực trên bản Release).
- [ ] Cài mới: onboarding bước 4 nhập kỳ kinh cuối → tab Thai kỳ hiện đúng tuần + ngày, tam cá nguyệt, số ngày còn lại; "Để sau" → màn mời nhập ngày.
- [ ] Người dùng v1 đã có ngày dự sinh: cập nhật app → tab Thai kỳ hiện đúng tuần, không phải nhập lại.
- [ ] Cài đặt → Thai kỳ: đổi giữa ngày dự sinh/kỳ kinh cuối; "Xóa thông tin thai kỳ" → tab Thai kỳ về màn mời nhập, tab Đếm mất dòng tuần.
- [ ] Chi tiết tuần: vuốt trái/phải từ tuần 4 đến 42; mục "Khi nào cần đi khám ngay" màu cam.
- [ ] Thêm lịch hẹn cho ngày kia → 9:00 sáng mai nhận thông báo "Ngày mai mẹ có lịch khám" kèm tên lịch hẹn.
- [ ] Lịch hẹn trong quá khứ lưu được, nằm trong "Đã qua", không có thông báo.
- [ ] Đánh dấu đã khám hoặc xóa một lịch hẹn có nhắc → không còn nhận thông báo của nó.
- [ ] Từ chối quyền thông báo → vẫn lưu lịch hẹn; màn Lịch khám hiện dòng nhắc bật thông báo.
- [ ] Hai máy cùng Apple ID: lịch hẹn thêm trên máy A hiện trên máy B sau khi mở app, và máy B cũng nhắc.
- [ ] Từ tuần 28: thẻ "Đếm cử động thai hôm nay" chuyển sang tab Đếm.
- [ ] Dynamic Type lớn nhất: thẻ không bị cắt chữ; VoiceOver đọc emoji bằng tên loại quả và đọc mỗi thẻ thành một câu.
- [ ] Thông tin y tế → "Nguồn tham khảo" liệt kê đủ nguồn.
```

- [ ] **Step 2: Commit, push, CI**

```bash
git add docs/release-checklist.md
git commit -F - <<'MSG'
docs: add phase 2 release and device test checklist

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

- [ ] **Step 3: Người dùng chạy bản TestFlight và kiểm thử trên iPhone**

Việc tải bản build lên App Store Connect do **người dùng** quyết định và tự chạy: `gh workflow run testflight.yml` (từ nhánh đã merge hoặc `--ref feat/phase2-pregnancy-journey`). Sau đó kiểm theo mục "Kiểm thử thủ công" ở trên. Mục nào lỗi → task sửa riêng (dùng `superpowers:systematic-debugging`).

- [ ] **Step 4: Hoàn tất nhánh**

Dùng `superpowers:finishing-a-development-branch` để mở PR `feat/phase2-pregnancy-journey` → `main` (chạy `scripts/test-core.sh` trước khi push, như pre-push hook).

---

## Quyết định làm rõ spec

| Điểm chưa rõ trong spec | Quyết định |
|---|---|
| §6 "tuần > 44" trong khi `GestationalAge` v1 chỉ chấp nhận tới 42 tuần | `PregnancyTimeline` hợp lệ cho 0…314 ngày (tuần 0 tới 44 + 6 ngày). `GestationalAge.week` giữ nguyên hành vi; tab Đếm chuyển sang `PregnancyTimeline` nên dòng tuần hiện tới 44 tuần. |
| §4.1 "Tái dùng `GestationalAge`" | Tách `GestationalAge.elapsedDays(dueDate:now:calendar:)` (internal) dùng chung cho cả hai. |
| §8 "Lịch hẹn trong quá khứ"/Sắp tới–Đã qua | Sắp tới = chưa khám **và** từ đầu ngày hôm nay trở đi (lịch hẹn sáng nay vẫn ở "Sắp tới" để đánh dấu đã khám); còn lại là Đã qua. Nhắc chỉ đặt khi chưa khám và giờ hẹn ở tương lai. |
| §4.1 `scheduleAppointmentReminder(id:date:title:now:text:)` có cả `title` và `text` | `text` là tiêu đề/nội dung đã bản địa hóa ("Ngày mai mẹ có lịch khám"/"Mẹ nhớ mang theo sổ khám thai"); `title` (tên lịch hẹn) đặt vào `subtitle` của thông báo. Thêm `calendar:` (mặc định `.current`) để test được. Hàm trả `Bool` (đã đặt hay bỏ qua). |
| §4.1 chọn ngôn ngữ nội dung "theo `Locale`" | Lấy ngôn ngữ **đầu tiên được hỗ trợ** (vi hoặc en) trong `Locale.preferredLanguages` — cùng quy tắc iOS dùng để chọn bản địa hóa giao diện, để nội dung và giao diện luôn cùng ngôn ngữ; không có thì en. |
| §8 ảnh chụp tuần 12/24/38 cần ngày dự sinh cố định | Thêm launch argument `-seedDueDate <ISO8601>` (chỉ với `-uiTesting`) cạnh `-fixedNow`. |
| §4.3 Onboarding "trang 4" | Bước 4 hiện sau khi bấm "Tôi đã hiểu" (không nằm trong trang vuốt), để không vuốt qua được trang miễn trừ y tế; có "Lưu" và "Để sau". |
| §4.3 "ngày ước tính đầu khoảng tuần" khi mốc đang diễn ra | 9:00 ngày đầu tuần `fromWeek`; nếu đã qua (hoặc chưa có ngày dự sinh) thì 9:00 ngày mai. Lịch hẹn mới mặc định 9:00 ngày mai. |
| §4.1 `upcomingMilestones(atWeek:)` | Gồm cả mốc đang diễn ra (`toWeek >= week`); thêm tham số `visibility` (mặc định `.all`) để bản App Store ẩn mốc chưa duyệt. Màn Lịch khám ẩn mốc đã được thêm thành lịch hẹn (theo `milestoneID`). |
| §3.3 luật kiểm định | Bổ sung: số ý `en` = số ý `vi`; số đo bắt buộc từ tuần 8; khoảng số đo điển hình ở tuần 12/20/24/28/40; mọi ý `warnings` có từ chỉ tới bác sĩ/cơ sở y tế; mọi chuỗi vi có dấu; tên so sánh kích thước không trùng; id + khoảng tuần của 10 mốc cố định. |
| §6 "Từ chối quyền thông báo → dòng nhắc" | Chỉ hiện khi trạng thái là `.denied` (không hiện khi chưa từng hỏi) — thêm `NotificationScheduler.isDenied()`. `load()` không bao giờ xin quyền; chỉ thêm/sửa lịch hẹn mới xin. |
| §8 "KickData: rollback" | v1 không ép được `save()` lỗi (commit `59dd6a1`), nên `AppointmentStore` có seam nội bộ `saveContext` để test rollback. |
| §4.2 đồng bộ iCloud | `AppointmentCoordinator.load()` (khi mở app/active) đối chiếu nhắc: đặt cho lịch hẹn mới đồng bộ về, hủy nhắc của lịch hẹn đã bị xóa ở máy khác. |
| §5 cách xác minh không cần Xcode | CI build với `CURRENT_PROJECT_VERSION` = số run và `scripts/check-bundle-versions.sh` đọc Info.plist đã build của app + widget bằng `PlistBuddy`. |
| §4.4 cách truyền `CONTENT_PREVIEW` | `testflight.yml` đặt `CONTENT_PREVIEW=1`; `release.sh` thêm `SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) CONTENT_PREVIEW`. Bản Debug (CI, ảnh chụp) cũng hiện mọi nội dung. |
| §3.1 nhập ngày: khoảng cho phép | Ngày dự sinh: từ 34 ngày trước tới 280 ngày sau hôm nay; LMP: từ 314 ngày trước tới hôm nay (đúng khoảng `PregnancyTimeline` chấp nhận). Mặc định: thai 20 tuần. Đổi loại ngày giữ nguyên thai kỳ (± 280 ngày). |
| §3.1 "xóa `lmpDate`" / xóa thông tin thai kỳ | Ghi `0` thay vì xóa khóa, để các view `@AppStorage` cập nhật ngay. |

## Spec coverage (self-review)

| Spec | Task |
|---|---|
| §1 Nhập ngày dự sinh **hoặc** LMP → tuần + ngày, tam cá nguyệt, ngày còn lại | 2, 3, 11, 12 (UI test LMP → tuần 13 + 2 ngày) |
| §1 Nội dung bé + mẹ tuần 4–42, vuốt qua lại | 4, 5, 12 |
| §1 Lịch hẹn thật, nhắc trước 1 ngày, đánh dấu đã khám, đồng bộ iCloud | 6, 7, 8, 9, 13 |
| §1 Nội dung được bác sĩ duyệt trước App Store | 4 (`reviewed`), 10 (`CONTENT_PREVIEW`), 14 |
| §1 Ngoài phạm vi (YAGNI) | Không task nào thêm chế độ Mong con, chu kỳ, cân nặng/huyết áp, chia sẻ, ảnh thai nhi, tải nội dung, đổi tên app |
| §2 dự sinh = LMP + 280 | 2 (`PregnancyDates`), 3 (`saveLMP`) |
| §2 JSON trong KickCore, validate local | 4, 5 |
| §2 4 tab, Thai kỳ là trang chủ | 12 |
| §2 Lịch khám = mốc gợi ý (JSON) + lịch hẹn (SwiftData, iCloud) | 5, 9, 13 |
| §2 Nhắc 9:00 ngày hôm trước, bỏ qua nếu đã qua | 6, 8 |
| §2 Emoji thay ảnh | 4, 5, 12 |
| §3.1 `dueDate` nguồn sự thật, `pregnancyDateSource`, `lmpDate`, v1 không migrate | 3, 11 |
| §3.2 Model `Appointment` tương thích CloudKit, thêm vào schema | 9 |
| §3.3 File nội dung, đủ tuần/mục/ý, số đo không giảm, mốc khám | 4 (validator), 5 (nội dung + test file thật) |
| §4.1 `PregnancyTimeline`, `PregnancyDates` | 2 |
| §4.1 `WeeklyContentLibrary` (Bundle.module, kẹp tuần, milestones, upcomingMilestones, ngôn ngữ) | 4, 5 |
| §4.1 `AppointmentReminders` (id `appointment-<uuid>`, 9:00 hôm trước, hủy theo id) | 6 |
| §4.1 `resources: [.process("Resources")]` | 5 |
| §4.2 `AppointmentStore` (upcoming/past, add/update/delete/markDone, rollback, không đụng thông báo) | 9 |
| §4.2 `AppointmentRepository` + `AppointmentRecord` trong KickCore | 7 |
| §4.2 `AppointmentCoordinator` là nơi duy nhất đồng bộ nhắc, test bằng fake | 8 |
| §4.3 `PregnancyHomeView` (chưa có ngày, thẻ tuần, quá ngày, thẻ bé, lời khuyên 2 ý, lịch khám sắp tới, thẻ đếm từ tuần 28) | 12, 13 (thẻ lịch khám mở màn Lịch khám) |
| §4.3 `WeekDetailView` (trang 4–42, mở ở tuần hiện tại, mục cam "Khi nào cần đi khám ngay") | 12 |
| §4.3 `AppointmentsView` (Sắp tới/Đã qua, thêm/sửa, vuốt xóa, đã khám, mốc gợi ý "Thêm vào lịch") | 13 |
| §4.3 `PregnancyDateSheet` dùng ở trang chủ, Cài đặt, onboarding | 11, 12 |
| §4.3 Onboarding trang 4 có "Để sau" | 11 |
| §4.3 Cài đặt: dòng ngày + nguồn, nút xóa | 11 |
| §4.3 Thông tin y tế: "Nguồn tham khảo" | 11 |
| §4.3 Tab Đếm dùng `PregnancyTimeline` | 10 |
| §4.4 Release chỉ hiện `reviewed`, TestFlight/Debug hiện tất cả + nhãn, cờ `CONTENT_PREVIEW` qua testflight.yml | 4, 10, 12, 13, 14 |
| §5 Sửa số phiên bản/build (app + widget) | 1, 14 (kiểm trên TestFlight) |
| §6 Chưa nhập ngày | 12 (màn mời nhập), 10 (tab Đếm như v1) |
| §6 Ngày không hợp lý → nil, thông báo + nút sửa | 2, 12 |
| §6 Quá ngày dự sinh → thông điệp + nội dung tuần 41–42 | 2, 4 (kẹp tuần), 12 (ảnh `pregnancy-home-pastdue-en`) |
| §6 Lỗi đọc JSON → không crash, log, ẩn thẻ | 5 (`loadBundled`), 11, 12 (`library == nil`) |
| §6 Từ chối quyền thông báo → vẫn lưu, dòng nhắc | 6 (`isDenied`), 8, 13 |
| §6 Lịch hẹn quá khứ → cho phép, không nhắc | 7, 8, 9 |
| §6 Lưu lỗi → rollback + alert `error.save` | 8, 9, 13 |
| §7 L10n + xcstrings vi/en; nội dung y tế trong JSON | 10 (`add-strings.py`), 11, 12, 13; 5 |
| §7 Dynamic Type, VoiceOver gộp, emoji có nhãn, chế độ tối | 12, 13 (ảnh sáng/tối), 14 |
| §8 Unit KickCore (timeline, dates, nội dung, kẹp tuần, ngôn ngữ, nhắc) | 2, 3, 4, 5, 6, 7, 8 |
| §8 KickData CI (CRUD, upcoming/past, rollback) | 9 |
| §8 UI test (LMP → tuần; thêm lịch hẹn → Sắp tới) | 12, 13 |
| §8 Ảnh chụp (tuần 12/24/38, chi tiết tuần, lịch khám, chưa nhập ngày; sáng/tối; vi/en; `-fixedNow`) | 3, 10, 12, 13 |
| §9 Bác sĩ duyệt, CloudKit schema, ghi chú + ảnh App Store | 14 |
