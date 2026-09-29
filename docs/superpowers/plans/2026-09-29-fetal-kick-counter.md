# Kick Counter (Đếm thai máy) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. For UI tasks (8–10), also apply the `ui-ux-pro-max` skill for visual polish — but do not change behaviour, identifiers, or strings defined here.

**Goal:** Ứng dụng iPhone (SwiftUI, iOS 17+) giúp mẹ bầu đếm 10 cử động thai (phương pháp Cardiff), có Live Activity với nút "+1" trên màn hình khóa, lịch sử + biểu đồ 14 ngày, nhắc giờ hằng ngày, song ngữ Anh/Việt.

**Architecture:** Logic nằm trong hai Swift package cục bộ:
- **`KickCore`**: Swift thuần gồm engine đếm, tóm tắt lịch sử, scheduler thông báo, protocol `SessionRepository` và `KickCoordinator` (facade `@Observable` duy nhất mà UI và `AddKickIntent` gọi vào). Package này build và test được trên máy dev chỉ với Command Line Tools.
- **`KickData`**: model SwiftData và `KickStore: SessionRepository`. Package này cần macro SwiftData có trong Xcode, nên chỉ build/test trên GitHub Actions.

App SwiftUI và Widget Extension chỉ là lớp giao diện mỏng. Thư mục `Shared/` được biên dịch vào cả hai target. Dự án Xcode được sinh từ `project.yml` bằng XcodeGen.

**Máy dev không có Xcode** vì không đủ dung lượng. Mọi bản build iOS, UI test và ảnh chụp simulator chạy trên GitHub Actions (`.github/workflows/ci.yml`, repo public nên macOS runner miễn phí). Bản TestFlight được đẩy lên qua `.github/workflows/testflight.yml`, dùng App Store Connect API key (ký bằng cloud signing).

**Tech Stack:** Swift 6, SwiftUI, SwiftData (+ CloudKit private DB), ActivityKit, AppIntents, WidgetKit, UserNotifications, Swift Charts, Swift Testing, XCTest (UI), XcodeGen, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-29-fetal-kick-counter-design.md`

## Global Constraints

- iOS deployment target: `17.0`. Package platforms: `.iOS(.v17), .macOS(.v14)`; macOS chỉ dùng để chạy `swift test`.
- Swift language mode 6 cho các package và các target.
- Bundle ID: `com.lmtiep.kickcounter` (app), `com.lmtiep.kickcounter.widgets` (extension), `com.lmtiep.kickcounter.uitests` (UI test).
- App Group: `group.com.lmtiep.kickcounter`. iCloud container: `iCloud.com.lmtiep.kickcounter`.
- Luật đếm: mục tiêu `10`, ngưỡng cảnh báo `7200` giây (2 giờ), debounce `0.5` giây.
- **`KickCore` không được import SwiftData.** Mọi thứ dùng `@Model` nằm trong `KickData`.
- Model SwiftData phải tương thích CloudKit: mọi thuộc tính có default hoặc optional, quan hệ optional, **không** dùng `@Attribute(.unique)`.
- Tại mọi thời điểm có tối đa **một** session với `statusRaw == "active"`.
- Chỉ tiến trình app chính ghi vào SwiftData. Intent chạy trong tiến trình app.
- Mọi chuỗi hiển thị phải đi qua `L10n` (`Shared/L10n.swift`) và có trong `Shared/Localizable.xcstrings` với đủ `en` và `vi`.
- Không thu thập dữ liệu, không server, không dùng SDK bên thứ ba.
- Không crash khi lỗi lưu trữ hoặc khi quyền bị từ chối. Xem bảng lỗi trong spec §5.
- Accessibility identifiers cố định, dùng trong UI test: `kickButton`, `undoButton`, `cancelSessionButton`, `completionTitle`, `completionDone`, `onboardingNext`, `onboardingAgree`, `sessionRow`.
- Launch arguments cho UI test: `-uiTesting` (store trong bộ nhớ, tắt thông báo và Live Activity, xóa cài đặt), `-skipOnboarding`, `-forceDarkMode`.
- Repo GitHub **public**: không commit bí mật. Secrets gồm `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`. Repository variable: `DEVELOPMENT_TEAM`.

## Quy trình xác minh

- **Local** (mỗi task có code KickCore): `scripts/test-core.sh`. Đây cũng là nội dung của pre-push hook, vì là kiểm tra duy nhất chạy được trên máy không có Xcode.
- **CI** (điều kiện hoàn thành của **mọi** task từ Task 1): commit, `git push`, rồi `scripts/ci-wait.sh`. Script chờ run CI của commit HEAD, in log lỗi nếu fail, và tải artifact về `ci-artifacts/` (ảnh chụp ở `ci-artifacts/screenshots/`). Khi task yêu cầu xác minh trực quan, dùng Read tool mở từng file PNG và đối chiếu với danh sách kiểm tra của task.
- CI fail thì dùng `superpowers:systematic-debugging`, sửa, commit và push lại. Không được đánh dấu task hoàn thành khi CI còn đỏ.

## File Structure

```
kick-counter/
├── project.yml                       # XcodeGen spec (nguồn sự thật của dự án Xcode)
├── .gitignore
├── README.md
├── .github/workflows/ci.yml          # test + build + UI test + ảnh chụp
├── .github/workflows/testflight.yml  # archive + upload TestFlight (chạy tay)
├── scripts/test-core.sh              # local: swift test KickCore (không cần Xcode)
├── scripts/ci.sh                     # CI: toàn bộ cổng kiểm tra
├── scripts/ci-wait.sh                # local: chờ CI của HEAD, tải artifact
├── scripts/release.sh                # CI: archive + upload
├── .githooks/pre-push
├── Packages/KickCore/                # Swift thuần — test được local
│   ├── Package.swift
│   ├── Sources/KickCore/
│   │   ├── SessionRules.swift
│   │   ├── SessionEngine.swift       # SessionState, KickOutcome, logic thuần
│   │   ├── SessionRepository.swift   # protocol lưu trữ + SessionRecord, KickResult
│   │   ├── HistorySummary.swift
│   │   ├── GestationalAge.swift
│   │   ├── Settings.swift            # AppGroup, khóa UserDefaults, mặc định
│   │   ├── NotificationScheduler.swift
│   │   ├── LiveActivityManaging.swift
│   │   └── KickCoordinator.swift
│   └── Tests/KickCoreTests/          # TestSupport (fakes) + test từng file
├── Packages/KickData/                # SwiftData — chỉ build trên CI
│   ├── Package.swift
│   ├── Sources/KickData/{Models,KickPersistence,KickStore}.swift
│   └── Tests/KickDataTests/{TestSupport,KickStoreTests}.swift
├── Shared/                           # biên dịch vào cả App và Widgets
│   ├── L10n.swift, Localizable.xcstrings, InfoPlist.xcstrings
│   ├── KickActivityAttributes.swift
│   └── AddKickIntent.swift
├── App/                              # SwiftUI app (xem từng task)
├── Widgets/                          # Live Activity
└── UITests/
    ├── ScreenshotTests.swift         # ảnh chụp để xác minh trực quan trên CI
    └── KickCounterUITests.swift      # luồng chức năng
```

---

### Task 0: Chuẩn bị tài khoản Apple và GitHub (người dùng làm thủ công)

Không cài Xcode. Các bước dưới đây làm trên web. Riêng bước đặt secret, **người dùng tự chạy lệnh**, vì agent không được xử lý khóa bí mật.

- [ ] **Step 1: Đăng ký định danh** tại developer.apple.com → Certificates, Identifiers & Profiles → Identifiers:
  - App Group: `group.com.lmtiep.kickcounter`
  - iCloud Container: `iCloud.com.lmtiep.kickcounter`
  - App ID `com.lmtiep.kickcounter`, bật các capability: App Groups (gán group trên), iCloud → CloudKit (gán container trên), Push Notifications.
  - App ID `com.lmtiep.kickcounter.widgets`, bật App Groups (gán group trên).

- [ ] **Step 2: Tạo app trên App Store Connect**: My Apps → "+" → New App. Platform iOS, bundle ID `com.lmtiep.kickcounter`, SKU `kickcounter`. Tên hiển thị trên App Store phải là duy nhất toàn cầu, ví dụ "Đếm Thai Máy – Kick Counter".

- [ ] **Step 3: Tạo API key**: App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → "+". Chọn quyền **Admin** (cloud signing yêu cầu quyền này). Tải file `AuthKey_XXXX.p8` (chỉ tải được một lần), ghi lại **Key ID** và **Issuer ID**. Lấy **Team ID** ở developer.apple.com → Membership.

- [ ] **Step 4 (sau khi Task 1 đã tạo repo): đặt secrets**. Người dùng tự chạy trong thư mục dự án:

```bash
gh secret set ASC_KEY_ID --body "<Key ID>"
```
```bash
gh secret set ASC_ISSUER_ID --body "<Issuer ID>"
```
```bash
base64 -i ~/Downloads/AuthKey_<Key ID>.p8 | gh secret set ASC_KEY_P8_BASE64
```
```bash
gh variable set DEVELOPMENT_TEAM --body "<Team ID>"
```

Xác minh: `gh secret list && gh variable list` phải liệt kê đủ 3 secret và 1 variable. Chỉ cần xong bước này trước Task 13.

---

### Task 1: Khung dự án, cổng kiểm tra local + CI, repo GitHub

**Files:**
- Create: `Packages/KickCore/Package.swift`, `Packages/KickCore/Sources/KickCore/SessionRules.swift`, `Packages/KickCore/Tests/KickCoreTests/SessionRulesTests.swift`
- Create: `project.yml`, `App/KickCounterApp.swift`, `App/Assets.xcassets/Contents.json`, `App/Assets.xcassets/AccentColor.colorset/Contents.json`, `App/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `.gitignore`, `README.md`, `.githooks/pre-push`, `scripts/test-core.sh`, `scripts/ci.sh`, `scripts/ci-wait.sh`, `.github/workflows/ci.yml`

**Interfaces:**
- Produces: module `KickCore`. `public enum SessionRules` gồm `targetCount: Int = 10`, `overdueThreshold: TimeInterval = 7200`, `debounceInterval: TimeInterval = 0.5`. Các script `scripts/test-core.sh [swift test args]`, `scripts/ci.sh`, `scripts/ci-wait.sh`. Biến `XCODE_ACTION` trong `ci.sh` (Task 1 dùng `build`, từ Task 8 chuyển sang `test`).

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/SessionRulesTests.swift`:
```swift
import Testing
@testable import KickCore

@Test func rulesMatchCardiffMethod() {
    #expect(SessionRules.targetCount == 10)
    #expect(SessionRules.overdueThreshold == 2 * 60 * 60)
    #expect(SessionRules.debounceInterval == 0.5)
}
```

`Packages/KickCore/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KickCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "KickCore", targets: ["KickCore"])],
    targets: [
        .target(name: "KickCore"),
        .testTarget(name: "KickCoreTests", dependencies: ["KickCore"]),
    ]
)
```

`scripts/test-core.sh`:
```bash
#!/usr/bin/env bash
# Local gate that works without Xcode: KickCore unit tests.
# Extra arguments are passed to `swift test` (e.g. --filter SessionEngineTests).
set -euo pipefail
cd "$(dirname "$0")/../Packages/KickCore"

DEV_DIR="$(xcode-select -p)"
if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
  # Command Line Tools ship Swift Testing, but SwiftPM doesn't find it by default.
  FRAMEWORKS="$DEV_DIR/Library/Developer/Frameworks"
  LIBS="$DEV_DIR/Library/Developer/usr/lib"
  swift test \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$LIBS" \
    "$@"
else
  swift test "$@"
fi
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `chmod +x scripts/test-core.sh && scripts/test-core.sh`
Expected: FAIL. Lỗi `cannot find 'SessionRules' in scope`, hoặc target không có source.

- [ ] **Step 3: Cài đặt tối thiểu**

`Packages/KickCore/Sources/KickCore/SessionRules.swift`:
```swift
import Foundation

/// Rules of the "count to 10" (Cardiff) method.
public enum SessionRules {
    public static let targetCount = 10
    public static let overdueThreshold: TimeInterval = 2 * 60 * 60
    /// Taps closer together than this are treated as an accidental double tap.
    public static let debounceInterval: TimeInterval = 0.5
}
```

- [ ] **Step 4: Chạy để thấy pass**

Run: `scripts/test-core.sh`
Expected: `Test run with 1 test ... passed`.

- [ ] **Step 5: App shell, assets, project.yml**

`App/KickCounterApp.swift` (thay thế ở Task 8):
```swift
import SwiftUI
import KickCore

@main
struct KickCounterApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Kick Counter — \(SessionRules.targetCount)")
        }
    }
}
```

`App/Assets.xcassets/Contents.json`:
```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

`App/Assets.xcassets/AccentColor.colorset/Contents.json` (hồng san hô dịu; bản tối sáng hơn để đủ tương phản):
```json
{
  "colors" : [
    { "idiom" : "universal",
      "color" : { "color-space" : "srgb", "components" : { "red" : "0.847", "green" : "0.365", "blue" : "0.412", "alpha" : "1.000" } } },
    { "idiom" : "universal",
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" : { "red" : "0.957", "green" : "0.557", "blue" : "0.588", "alpha" : "1.000" } } }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`App/Assets.xcassets/AppIcon.appiconset/Contents.json` (ảnh icon 1024×1024 thêm ở Task 14):
```json
{
  "images" : [ { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`project.yml`:
```yaml
name: KickCounter
options:
  bundleIdPrefix: com.lmtiep
  deploymentTarget:
    iOS: "17.0"
  developmentLanguage: en
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    LOCALIZATION_PREFERS_STRING_CATALOGS: YES
    SWIFT_EMIT_LOC_STRINGS: YES
packages:
  KickCore:
    path: Packages/KickCore
targets:
  KickCounter:
    type: application
    platform: iOS
    sources:
      - App
    dependencies:
      - package: KickCore
    info:
      path: App/Info.plist
      properties:
        CFBundleDisplayName: Kick Counter
        CFBundleLocalizations: [en, vi]
        UILaunchScreen: {}
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
        ITSAppUsesNonExemptEncryption: false
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lmtiep.kickcounter
        TARGETED_DEVICE_FAMILY: "1"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
schemes:
  KickCounter:
    build:
      targets:
        KickCounter: all
```

- [ ] **Step 6: Script CI, workflow, hook, gitignore, README**

`scripts/ci.sh`:
```bash
#!/usr/bin/env bash
# Full quality gate. Runs on GitHub Actions (requires Xcode + XcodeGen).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> KickCore unit tests"
scripts/test-core.sh

if [[ -d Packages/KickData ]]; then
  echo "==> KickData unit tests"
  (cd Packages/KickData && swift test)
fi

echo "==> Generating Xcode project"
xcodegen generate --quiet

DEVICE_ID="$(xcrun simctl list devices available | grep -m1 -E '^[[:space:]]+iPhone' | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')"
[[ -n "$DEVICE_ID" ]] || { echo "No available iPhone simulator" >&2; exit 1; }

XCODE_ACTION="build"
rm -rf build && mkdir -p build/screenshots
echo "==> xcodebuild $XCODE_ACTION on simulator $DEVICE_ID"
STATUS=0
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination "id=$DEVICE_ID" \
  -resultBundlePath build/KickCounter.xcresult \
  CODE_SIGNING_ALLOWED=NO -quiet "$XCODE_ACTION" || STATUS=$?

if [[ "$XCODE_ACTION" == "test" ]]; then
  echo "==> Exporting screenshots"
  xcrun xcresulttool export attachments --path build/KickCounter.xcresult --output-path build/screenshots || true
  python3 - <<'PY'
import json, os
d = "build/screenshots"
manifest = os.path.join(d, "manifest.json")
if os.path.exists(manifest):
    for test in json.load(open(manifest)):
        for a in test.get("attachments", []):
            src = os.path.join(d, a["exportedFileName"])
            name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
            if os.path.exists(src):
                os.rename(src, os.path.join(d, name))
PY
fi

[[ $STATUS -eq 0 ]] && echo "==> All checks passed"
exit $STATUS
```

`scripts/ci-wait.sh`:
```bash
#!/usr/bin/env bash
# Waits for the CI run of HEAD, prints failed logs, downloads artifacts to ci-artifacts/.
set -euo pipefail
cd "$(dirname "$0")/.."
SHA="$(git rev-parse HEAD)"
RUN_ID=""
for _ in $(seq 1 30); do
  RUN_ID="$(gh run list --workflow ci.yml --commit "$SHA" --limit 1 --json databaseId -q '.[0].databaseId')"
  [[ -n "$RUN_ID" ]] && break
  sleep 5
done
[[ -n "$RUN_ID" ]] || { echo "No CI run found for $SHA — was it pushed?" >&2; exit 1; }

STATUS=0
gh run watch "$RUN_ID" --exit-status --interval 20 > /dev/null || STATUS=$?
rm -rf ci-artifacts && mkdir -p ci-artifacts
gh run download "$RUN_ID" --dir ci-artifacts 2>/dev/null || true
if [[ $STATUS -ne 0 ]]; then
  gh run view "$RUN_ID" --log-failed | tail -150
  echo "CI FAILED: $(gh run view "$RUN_ID" --json url -q .url)" >&2
else
  echo "CI PASSED: $(gh run view "$RUN_ID" --json url -q .url)"
fi
exit $STATUS
```

`.github/workflows/ci.yml`:
```yaml
name: CI
on:
  push:
    branches: ["**"]
  pull_request:
  workflow_dispatch:
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  test:
    runs-on: macos-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
      - name: Select latest stable Xcode
        run: |
          XCODE="$(ls -d /Applications/Xcode_*.app | grep -vi beta | sort -V | tail -1)"
          sudo xcode-select -s "$XCODE/Contents/Developer"
          xcodebuild -version
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Run quality gate
        run: scripts/ci.sh
      - name: Upload screenshots
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: screenshots
          path: build/screenshots
          if-no-files-found: ignore
      - name: Upload result bundle
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: xcresult
          path: build/KickCounter.xcresult
          if-no-files-found: ignore
```

`.githooks/pre-push`:
```bash
#!/usr/bin/env bash
# Local gate before push. The dev Mac has no Xcode, so only KickCore can be
# checked here; the iOS build, KickData and UI tests are gated by CI.
exec "$(git rev-parse --show-toplevel)/scripts/test-core.sh"
```

`.gitignore`:
```
.DS_Store
*.xcodeproj/
App/Info.plist
Widgets/Info.plist
build/
ci-artifacts/
DerivedData/
.build/
.swiftpm/
xcuserdata/
*.xcuserstate
*.p8
```

`README.md`:
```markdown
# Kick Counter (Đếm thai máy)

App iPhone đếm cử động thai theo phương pháp đếm đến 10.

## Phát triển không cần Xcode
- Logic (`Packages/KickCore`) test local: `scripts/test-core.sh`
- Mọi thứ khác (SwiftData, build iOS, UI test, ảnh chụp) chạy trên GitHub Actions:
  push rồi chạy `scripts/ci-wait.sh`; ảnh chụp nằm ở `ci-artifacts/screenshots/`.
- Bật pre-push hook (mỗi bản clone một lần): `git config core.hooksPath .githooks`

## Có Xcode
    brew install xcodegen && xcodegen generate && open KickCounter.xcodeproj

Dự án Xcode được sinh từ `project.yml` — sửa `project.yml`, không sửa `.xcodeproj`.

## Phát hành TestFlight
    gh workflow run testflight.yml
```

Run:
```bash
chmod +x scripts/*.sh .githooks/pre-push
git config core.hooksPath .githooks
```

- [ ] **Step 7: Tạo repo GitHub public và push. HỎI NGƯỜI DÙNG XÁC NHẬN TRƯỚC**, vì đây là hành động công khai ra bên ngoài. Nói rõ tên repo `kick-counter`, tài khoản đang đăng nhập `gh`, chế độ public. Chỉ chạy khi người dùng đồng ý:

```bash
git add .
git commit -m "chore: scaffold KickCore, app shell, local and CI quality gates"
gh repo create kick-counter --public --source . --remote origin --push
```

- [ ] **Step 8: Xác minh CI**

Run: `scripts/ci-wait.sh`
Expected: `CI PASSED: <url>`. Log CI có `Test run with 1 test ... passed` và `==> All checks passed`.

Sau đó nhắc người dùng làm Task 0 Step 4 (đặt secrets) khi thuận tiện. Chỉ cần xong trước Task 13.

---

### Task 2: SessionEngine (logic đếm thuần)

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/SessionEngine.swift`
- Create: `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/SessionEngineTests.swift`

**Interfaces:**
- Consumes: `SessionRules`
- Produces:
  - `public enum SessionStatus: String, Codable, Sendable { case active, completed, cancelled }`
  - `public struct SessionState: Equatable, Sendable { startedAt: Date; kicks: [Date]; status: SessionStatus; endedAt: Date?; exceededThreshold: Bool; var count: Int; var duration: TimeInterval? }` với `init(startedAt:kicks:status:endedAt:exceededThreshold:)` (mặc định `[]`, `.active`, `nil`, `false`)
  - `public enum KickOutcome: Equatable, Sendable { case added(count: Int), completed(duration: TimeInterval), ignoredDebounce, ignoredInactive }`
  - `public enum SessionEngine` với `static func addKick(to: inout SessionState, at: Date) -> KickOutcome`, `@discardableResult static func undoLastKick(_: inout SessionState) -> Bool`, `static func cancel(_: inout SessionState, at: Date)`, `static func isOverdue(_: SessionState, now: Date) -> Bool`, `static func elapsed(_: SessionState, now: Date) -> TimeInterval`
  - Test helper `func date(_ iso: String) -> Date`

- [ ] **Step 1: Viết test fail**

`Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`:
```swift
import Foundation

/// Parses an ISO-8601 timestamp such as "2026-09-01T20:00:00Z".
func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}
```

`Packages/KickCore/Tests/KickCoreTests/SessionEngineTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct SessionEngineTests {
    let t0 = date("2026-09-01T20:00:00Z")

    private func kick(_ state: inout SessionState, _ times: Int, every seconds: TimeInterval = 60) -> KickOutcome {
        var outcome = KickOutcome.ignoredInactive
        for i in 0..<times {
            outcome = SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(Double(i) * seconds))
        }
        return outcome
    }

    @Test func firstKickIsCounted() {
        var state = SessionState(startedAt: t0)
        #expect(SessionEngine.addKick(to: &state, at: t0) == .added(count: 1))
        #expect(state.count == 1)
        #expect(state.status == .active)
    }

    @Test func tenthKickCompletesSession() {
        var state = SessionState(startedAt: t0)
        let outcome = kick(&state, 10)
        #expect(outcome == .completed(duration: 9 * 60))
        #expect(state.status == .completed)
        #expect(state.endedAt == t0.addingTimeInterval(9 * 60))
        #expect(state.duration == 9 * 60)
        #expect(state.exceededThreshold == false)
    }

    @Test func tapsCloserThanDebounceAreIgnored() {
        var state = SessionState(startedAt: t0)
        _ = SessionEngine.addKick(to: &state, at: t0)
        #expect(SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(0.3)) == .ignoredDebounce)
        #expect(SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(0.5)) == .added(count: 2))
    }

    @Test func kickAfterCompletionIsIgnored() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 10)
        #expect(SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(3600)) == .ignoredInactive)
        #expect(state.count == 10)
    }

    @Test func undoRemovesLastKick() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 3)
        #expect(SessionEngine.undoLastKick(&state))
        #expect(state.kicks == [t0, t0.addingTimeInterval(60)])
    }

    @Test func undoWithNoKicksDoesNothing() {
        var state = SessionState(startedAt: t0)
        #expect(SessionEngine.undoLastKick(&state) == false)
    }

    @Test func undoAfterCompletionIsNotAllowed() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 10)
        #expect(SessionEngine.undoLastKick(&state) == false)
        #expect(state.count == 10)
    }

    @Test func completionAtOrAfterTwoHoursIsFlagged() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 9)
        let outcome = SessionEngine.addKick(to: &state, at: t0.addingTimeInterval(SessionRules.overdueThreshold))
        #expect(outcome == .completed(duration: SessionRules.overdueThreshold))
        #expect(state.exceededThreshold)
    }

    @Test func overdueBoundaryIsInclusive() {
        let state = SessionState(startedAt: t0)
        #expect(SessionEngine.isOverdue(state, now: t0.addingTimeInterval(SessionRules.overdueThreshold - 1)) == false)
        #expect(SessionEngine.isOverdue(state, now: t0.addingTimeInterval(SessionRules.overdueThreshold)))
    }

    @Test func completedSessionIsNeverOverdue() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 10)
        #expect(SessionEngine.isOverdue(state, now: t0.addingTimeInterval(10 * 3600)) == false)
    }

    @Test func cancelEndsActiveSession() {
        var state = SessionState(startedAt: t0)
        _ = kick(&state, 2)
        SessionEngine.cancel(&state, at: t0.addingTimeInterval(300))
        #expect(state.status == .cancelled)
        #expect(state.endedAt == t0.addingTimeInterval(300))
    }

    @Test func elapsedUsesEndDateWhenFinished() {
        var state = SessionState(startedAt: t0)
        #expect(SessionEngine.elapsed(state, now: t0.addingTimeInterval(90)) == 90)
        _ = kick(&state, 10)
        #expect(SessionEngine.elapsed(state, now: t0.addingTimeInterval(99_999)) == 9 * 60)
    }
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter SessionEngineTests`
Expected: FAIL — `cannot find 'SessionState' in scope`.

- [ ] **Step 3: Cài đặt**

`Packages/KickCore/Sources/KickCore/SessionEngine.swift`:
```swift
import Foundation

public enum SessionStatus: String, Codable, Sendable {
    case active, completed, cancelled
}

/// Value snapshot of a counting session; the engine operates only on this.
public struct SessionState: Equatable, Sendable {
    public var startedAt: Date
    public var kicks: [Date]
    public var status: SessionStatus
    public var endedAt: Date?
    public var exceededThreshold: Bool

    public init(
        startedAt: Date,
        kicks: [Date] = [],
        status: SessionStatus = .active,
        endedAt: Date? = nil,
        exceededThreshold: Bool = false
    ) {
        self.startedAt = startedAt
        self.kicks = kicks
        self.status = status
        self.endedAt = endedAt
        self.exceededThreshold = exceededThreshold
    }

    public var count: Int { kicks.count }

    public var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }
}

public enum KickOutcome: Equatable, Sendable {
    case added(count: Int)
    case completed(duration: TimeInterval)
    case ignoredDebounce
    case ignoredInactive
}

public enum SessionEngine {
    public static func addKick(to state: inout SessionState, at now: Date) -> KickOutcome {
        guard state.status == .active else { return .ignoredInactive }
        if let last = state.kicks.last, now.timeIntervalSince(last) < SessionRules.debounceInterval {
            return .ignoredDebounce
        }
        state.kicks.append(now)
        guard state.count >= SessionRules.targetCount else { return .added(count: state.count) }

        let duration = now.timeIntervalSince(state.startedAt)
        state.status = .completed
        state.endedAt = now
        state.exceededThreshold = duration >= SessionRules.overdueThreshold
        return .completed(duration: duration)
    }

    @discardableResult
    public static func undoLastKick(_ state: inout SessionState) -> Bool {
        guard state.status == .active, !state.kicks.isEmpty else { return false }
        state.kicks.removeLast()
        return true
    }

    public static func cancel(_ state: inout SessionState, at now: Date) {
        guard state.status == .active else { return }
        state.status = .cancelled
        state.endedAt = now
    }

    public static func isOverdue(_ state: SessionState, now: Date) -> Bool {
        state.status == .active && now.timeIntervalSince(state.startedAt) >= SessionRules.overdueThreshold
    }

    public static func elapsed(_ state: SessionState, now: Date) -> TimeInterval {
        max(0, (state.endedAt ?? now).timeIntervalSince(state.startedAt))
    }
}
```

- [ ] **Step 4: Chạy để thấy pass**

Run: `scripts/test-core.sh --filter SessionEngineTests`
Expected: PASS, 12 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/KickCore
git commit -m "feat(core): add SessionEngine with count-to-10, debounce, undo and 2h threshold"
git push
scripts/ci-wait.sh
```

---

### Task 3: SessionRepository (KickCore) + package KickData (SwiftData, KickStore)

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/SessionRepository.swift`, `Packages/KickCore/Sources/KickCore/Settings.swift`
- Create: `Packages/KickData/Package.swift`
- Create: `Packages/KickData/Sources/KickData/Models.swift`, `Packages/KickData/Sources/KickData/KickPersistence.swift`, `Packages/KickData/Sources/KickData/KickStore.swift`
- Test: `Packages/KickData/Tests/KickDataTests/TestSupport.swift`, `Packages/KickData/Tests/KickDataTests/KickStoreTests.swift`
- Modify: `project.yml` (thêm package `KickData` + dependency của app)

**Interfaces:**
- Consumes: `SessionState`, `SessionStatus`, `KickOutcome`, `SessionEngine`, `SessionRules`
- Produces:
  - (KickCore) `public struct SessionRecord: Equatable, Sendable { id: UUID; state: SessionState }`
  - (KickCore) `public struct KickResult: Equatable, Sendable { record: SessionRecord; outcome: KickOutcome; didStartSession: Bool }`
  - (KickCore) `public enum AppGroup { static let identifier = "group.com.lmtiep.kickcounter"; static var defaults: UserDefaults }`, `public enum SettingsKey { reminderEnabled, reminderHour, reminderMinute, dueDate, hasCompletedOnboarding }` (hằng String), `public enum SettingsDefault { reminderHour = 20; reminderMinute = 0 }`
  - (KickCore) `@MainActor public protocol SessionRepository: AnyObject { func activeSession() throws -> SessionRecord?; func addKick(at: Date) throws -> KickResult; func undoLastKick() throws -> SessionRecord?; func cancelActive(at: Date) throws -> SessionRecord? }`
  - (KickData) `@Model public final class KickSession { id; startedAt; endedAt; targetCount; statusRaw; exceededThreshold; kicks: [Kick]?; var status: SessionStatus; var state: SessionState; var record: SessionRecord; init(id:startedAt:) }`
  - (KickData) `@Model public final class Kick { timestamp: Date; session: KickSession?; init(timestamp:) }`
  - (KickData) `public enum KickPersistence { static let schema: Schema; static func makeContainer(inMemory: Bool) throws -> ModelContainer }`
  - (KickData) `@MainActor public final class KickStore: SessionRepository { init(context: ModelContext) }`

- [ ] **Step 1: Protocol và khóa cài đặt trong KickCore.** Chỉ có khai báo, không có logic nên không cần test riêng. Protocol được kiểm qua fake ở Task 6 và qua KickStore ở các bước sau.

`Packages/KickCore/Sources/KickCore/SessionRepository.swift`:
```swift
import Foundation

/// A stored session: its identity plus a value snapshot of its state.
public struct SessionRecord: Equatable, Sendable {
    public let id: UUID
    public let state: SessionState

    public init(id: UUID, state: SessionState) {
        self.id = id
        self.state = state
    }
}

public struct KickResult: Equatable, Sendable {
    public let record: SessionRecord
    public let outcome: KickOutcome
    public let didStartSession: Bool

    public init(record: SessionRecord, outcome: KickOutcome, didStartSession: Bool) {
        self.record = record
        self.outcome = outcome
        self.didStartSession = didStartSession
    }
}

/// Persistence for counting sessions. Implementations must keep at most one
/// active session and apply `SessionEngine` rules to every change.
@MainActor
public protocol SessionRepository: AnyObject {
    func activeSession() throws -> SessionRecord?
    /// Adds a kick to the active session, starting a new session if none is active.
    func addKick(at now: Date) throws -> KickResult
    func undoLastKick() throws -> SessionRecord?
    func cancelActive(at now: Date) throws -> SessionRecord?
}
```

`Packages/KickCore/Sources/KickCore/Settings.swift`:
```swift
import Foundation

public enum AppGroup {
    public static let identifier = "group.com.lmtiep.kickcounter"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Keys for preferences stored in `AppGroup.defaults` (read via @AppStorage).
public enum SettingsKey {
    public static let reminderEnabled = "reminderEnabled"
    public static let reminderHour = "reminderHour"
    public static let reminderMinute = "reminderMinute"
    /// `timeIntervalSince1970`; 0 means "not set".
    public static let dueDate = "dueDate"
    public static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

public enum SettingsDefault {
    public static let reminderHour = 20
    public static let reminderMinute = 0
}
```

Run: `scripts/test-core.sh`
Expected: PASS. Mọi test hiện có vẫn xanh, KickCore biên dịch được.

- [ ] **Step 2: Viết test fail cho KickStore**

`Packages/KickData/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

// Requires Xcode (SwiftData macros); built and tested on CI only.
let package = Package(
    name: "KickData",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "KickData", targets: ["KickData"])],
    dependencies: [.package(path: "../KickCore")],
    targets: [
        .target(name: "KickData", dependencies: ["KickCore"]),
        .testTarget(name: "KickDataTests", dependencies: ["KickData"]),
    ]
)
```

`Packages/KickData/Tests/KickDataTests/TestSupport.swift`:
```swift
import Foundation

func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}
```

`Packages/KickData/Tests/KickDataTests/KickStoreTests.swift`:
```swift
import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct KickStoreTests {
    let t0 = date("2026-09-01T20:00:00Z")
    let container: ModelContainer
    let store: KickStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = KickStore(context: container.mainContext)
    }

    @Test func noActiveSessionInitially() throws {
        #expect(try store.activeSession() == nil)
    }

    @Test func firstKickStartsSessionAndCountsOne() throws {
        let result = try store.addKick(at: t0)
        #expect(result.didStartSession)
        #expect(result.outcome == .added(count: 1))
        #expect(result.record.state.startedAt == t0)
        #expect(try store.activeSession()?.id == result.record.id)
    }

    @Test func subsequentKicksReuseActiveSession() throws {
        let first = try store.addKick(at: t0)
        let second = try store.addKick(at: t0.addingTimeInterval(30))
        #expect(second.didStartSession == false)
        #expect(second.record.id == first.record.id)
        #expect(second.outcome == .added(count: 2))
    }

    @Test func tenKicksCompleteAndPersistState() throws {
        var last: KickResult?
        for i in 0..<10 { last = try store.addKick(at: t0.addingTimeInterval(Double(i) * 60)) }
        #expect(last?.outcome == .completed(duration: 540))
        #expect(try store.activeSession() == nil)

        let saved = try container.mainContext.fetch(FetchDescriptor<KickSession>())
        #expect(saved.count == 1)
        #expect(saved[0].status == .completed)
        #expect(saved[0].state.count == 10)
        #expect(saved[0].endedAt == t0.addingTimeInterval(540))
    }

    @Test func kickAfterCompletionStartsNewSession() throws {
        for i in 0..<10 { _ = try store.addKick(at: t0.addingTimeInterval(Double(i) * 60)) }
        let next = try store.addKick(at: t0.addingTimeInterval(3600))
        #expect(next.didStartSession)
        #expect(next.outcome == .added(count: 1))
    }

    @Test func undoRemovesPersistedKick() throws {
        _ = try store.addKick(at: t0)
        _ = try store.addKick(at: t0.addingTimeInterval(10))
        let record = try store.undoLastKick()
        #expect(record?.state.kicks == [t0])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Kick>()) == 1)
    }

    @Test func undoWithoutActiveSessionReturnsNil() throws {
        #expect(try store.undoLastKick() == nil)
    }

    @Test func cancelMarksSessionCancelled() throws {
        _ = try store.addKick(at: t0)
        let cancelled = try store.cancelActive(at: t0.addingTimeInterval(120))
        #expect(cancelled?.state.status == .cancelled)
        #expect(cancelled?.state.endedAt == t0.addingTimeInterval(120))
        #expect(try store.activeSession() == nil)
    }

    @Test func duplicateActiveSessionsAreResolvedToNewest() throws {
        // Simulates two devices each starting a session, merged by iCloud sync.
        let older = KickSession(startedAt: t0)
        let newer = KickSession(startedAt: t0.addingTimeInterval(600))
        container.mainContext.insert(older)
        container.mainContext.insert(newer)
        try container.mainContext.save()

        #expect(try store.activeSession()?.id == newer.id)
        #expect(older.status == .cancelled)
    }
}
```

- [ ] **Step 3: Cài đặt**

`Packages/KickData/Sources/KickData/Models.swift`:
```swift
import Foundation
import KickCore
import SwiftData

// CloudKit-compatible: every attribute has a default or is optional,
// relationships are optional, and no unique constraints are used.

@Model
public final class KickSession {
    public var id: UUID = UUID()
    public var startedAt: Date = Date()
    public var endedAt: Date?
    public var targetCount: Int = 10
    public var statusRaw: String = "active"
    public var exceededThreshold: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Kick.session)
    public var kicks: [Kick]? = []

    public init(id: UUID = UUID(), startedAt: Date) {
        self.id = id
        self.startedAt = startedAt
    }

    public var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .cancelled }
        set { statusRaw = newValue.rawValue }
    }

    public var state: SessionState {
        SessionState(
            startedAt: startedAt,
            kicks: (kicks ?? []).map(\.timestamp).sorted(),
            status: status,
            endedAt: endedAt,
            exceededThreshold: exceededThreshold
        )
    }

    public var record: SessionRecord {
        SessionRecord(id: id, state: state)
    }
}

@Model
public final class Kick {
    public var timestamp: Date = Date()
    public var session: KickSession?

    public init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
```

`Packages/KickData/Sources/KickData/KickPersistence.swift`:
```swift
import Foundation
import KickCore
import SwiftData

public enum KickPersistence {
    public static let schema = Schema([KickSession.self, Kick.self])

    /// On-device store in the App Group, mirrored to the user's private iCloud
    /// database when the CloudKit entitlement is present and the user is signed in.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: .automatic
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
```

`Packages/KickData/Sources/KickData/KickStore.swift`:
```swift
import Foundation
import KickCore
import SwiftData

/// SwiftData-backed SessionRepository. Enforces "at most one active session".
@MainActor
public final class KickStore: SessionRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func activeSession() throws -> SessionRecord? {
        try activeModel()?.record
    }

    public func addKick(at now: Date) throws -> KickResult {
        let session: KickSession
        let didStart: Bool
        if let existing = try activeModel() {
            session = existing
            didStart = false
        } else {
            session = KickSession(startedAt: now)
            context.insert(session)
            didStart = true
        }
        var state = session.state
        let outcome = SessionEngine.addKick(to: &state, at: now)
        apply(state, to: session)
        try context.save()
        return KickResult(record: session.record, outcome: outcome, didStartSession: didStart)
    }

    public func undoLastKick() throws -> SessionRecord? {
        guard let session = try activeModel() else { return nil }
        var state = session.state
        guard SessionEngine.undoLastKick(&state) else { return session.record }
        apply(state, to: session)
        try context.save()
        return session.record
    }

    public func cancelActive(at now: Date) throws -> SessionRecord? {
        guard let session = try activeModel() else { return nil }
        var state = session.state
        SessionEngine.cancel(&state, at: now)
        apply(state, to: session)
        try context.save()
        return session.record
    }

    private func activeModel() throws -> KickSession? {
        let active = SessionStatus.active.rawValue
        let descriptor = FetchDescriptor<KickSession>(
            predicate: #Predicate { $0.statusRaw == active },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let sessions = try context.fetch(descriptor)
        guard let newest = sessions.first else { return nil }
        if sessions.count > 1 {
            for duplicate in sessions.dropFirst() {
                duplicate.status = .cancelled
                duplicate.endedAt = duplicate.endedAt ?? newest.startedAt
            }
            try context.save()
        }
        return newest
    }

    /// Writes an engine state back onto the model, adding/removing Kick rows
    /// so that the stored kicks match `state.kicks`.
    private func apply(_ state: SessionState, to session: KickSession) {
        session.status = state.status
        session.endedAt = state.endedAt
        session.exceededThreshold = state.exceededThreshold

        var stored = (session.kicks ?? []).sorted { $0.timestamp < $1.timestamp }
        while stored.count > state.kicks.count {
            let removed = stored.removeLast()
            session.kicks?.removeAll { $0 === removed }
            context.delete(removed)
        }
        for timestamp in state.kicks.dropFirst(stored.count) {
            let kick = Kick(timestamp: timestamp)
            context.insert(kick)
            kick.session = session
        }
    }
}
```

- [ ] **Step 4: Nối KickData vào project**

Trong `project.yml`, thêm vào `packages:`:
```yaml
  KickData:
    path: Packages/KickData
```
và thêm vào `targets.KickCounter.dependencies`:
```yaml
      - package: KickData
```

- [ ] **Step 5: Commit, push, xác minh trên CI**

Không chạy được KickData ở local. `scripts/ci.sh` tự chạy `swift test` cho KickData khi thư mục tồn tại.

```bash
scripts/test-core.sh
git add Packages project.yml
git commit -m "feat(data): add SessionRepository and SwiftData-backed KickStore package"
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`. Log có bước `==> KickData unit tests` với 9 test pass.

---

### Task 4: HistorySummary, GestationalAge

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/HistorySummary.swift`
- Create: `Packages/KickCore/Sources/KickCore/GestationalAge.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/HistorySummaryTests.swift`, `Packages/KickCore/Tests/KickCoreTests/GestationalAgeTests.swift`

**Interfaces:**
- Consumes: `SessionState`, `SessionStatus`
- Produces:
  - `public struct DailySummary: Equatable, Identifiable, Sendable { day: Date; minutesToTarget: Double; exceededThreshold: Bool; var id: Date }`
  - `public enum HistorySummary { static let defaultDays = 14; static func daily(_ sessions: [SessionState], endingAt now: Date, days: Int = 14, calendar: Calendar = .current) -> [DailySummary] }`
  - `public struct GestationalWeek: Equatable, Sendable { weeks: Int; days: Int }`, `public enum GestationalAge { static func week(dueDate: Date, now: Date, calendar: Calendar = .current) -> GestationalWeek? }`

- [ ] **Step 1: Viết test fail**

`Packages/KickCore/Tests/KickCoreTests/HistorySummaryTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct HistorySummaryTests {
    let now = date("2026-09-14T22:00:00Z")

    private func completed(_ start: String, minutes: Double, exceeded: Bool = false) -> SessionState {
        let startedAt = date(start)
        return SessionState(
            startedAt: startedAt,
            kicks: Array(repeating: startedAt, count: 10),
            status: .completed,
            endedAt: startedAt.addingTimeInterval(minutes * 60),
            exceededThreshold: exceeded
        )
    }

    @Test func usesLatestCompletedSessionPerDay() {
        let sessions = [
            completed("2026-09-14T08:00:00Z", minutes: 40),
            completed("2026-09-14T20:00:00Z", minutes: 15),
        ]
        let result = HistorySummary.daily(sessions, endingAt: now, calendar: utcCalendar)
        #expect(result == [DailySummary(day: date("2026-09-14T00:00:00Z"), minutesToTarget: 15, exceededThreshold: false)])
    }

    @Test func ignoresCancelledAndActiveSessions() {
        let cancelled = SessionState(startedAt: date("2026-09-13T20:00:00Z"), status: .cancelled, endedAt: date("2026-09-13T20:05:00Z"))
        let active = SessionState(startedAt: date("2026-09-14T21:00:00Z"))
        #expect(HistorySummary.daily([cancelled, active], endingAt: now, calendar: utcCalendar).isEmpty)
    }

    @Test func onlyIncludesLastFourteenDaysSortedAscending() {
        let sessions = [
            completed("2026-09-14T20:00:00Z", minutes: 10),
            completed("2026-09-01T20:00:00Z", minutes: 20),       // day 14 of window (inclusive)
            completed("2026-08-31T20:00:00Z", minutes: 30),       // outside window
            completed("2026-09-05T20:00:00Z", minutes: 125, exceeded: true),
        ]
        let result = HistorySummary.daily(sessions, endingAt: now, calendar: utcCalendar)
        #expect(result.map(\.day) == [
            date("2026-09-01T00:00:00Z"), date("2026-09-05T00:00:00Z"), date("2026-09-14T00:00:00Z"),
        ])
        #expect(result[1].exceededThreshold)
        #expect(result[1].minutesToTarget == 125)
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/GestationalAgeTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct GestationalAgeTests {
    @Test func dueDateIn84DaysIsWeek28() {
        let now = date("2026-09-01T10:00:00Z")
        let due = date("2026-11-24T10:00:00Z") // 84 days later → 196 days = 28w0d
        #expect(GestationalAge.week(dueDate: due, now: now, calendar: utcCalendar) == GestationalWeek(weeks: 28, days: 0))
    }

    @Test func partialWeeksReportDays() {
        let now = date("2026-09-01T10:00:00Z")
        let due = date("2026-11-21T10:00:00Z") // 81 days → 199 days = 28w3d
        #expect(GestationalAge.week(dueDate: due, now: now, calendar: utcCalendar) == GestationalWeek(weeks: 28, days: 3))
    }

    @Test func implausibleDueDatesReturnNil() {
        let now = date("2026-09-01T10:00:00Z")
        #expect(GestationalAge.week(dueDate: date("2027-09-01T10:00:00Z"), now: now, calendar: utcCalendar) == nil)
        #expect(GestationalAge.week(dueDate: date("2026-07-01T10:00:00Z"), now: now, calendar: utcCalendar) == nil)
    }
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter "HistorySummaryTests|GestationalAgeTests"`
Expected: FAIL — `cannot find 'HistorySummary' in scope`.

- [ ] **Step 3: Cài đặt**

`Packages/KickCore/Sources/KickCore/HistorySummary.swift`:
```swift
import Foundation

public struct DailySummary: Equatable, Identifiable, Sendable {
    public let day: Date
    public let minutesToTarget: Double
    public let exceededThreshold: Bool
    public var id: Date { day }

    public init(day: Date, minutesToTarget: Double, exceededThreshold: Bool) {
        self.day = day
        self.minutesToTarget = minutesToTarget
        self.exceededThreshold = exceededThreshold
    }
}

public enum HistorySummary {
    public static let defaultDays = 14

    /// One bar per day for the last `days` days (today inclusive), using the
    /// most recently started completed session of each day.
    public static func daily(
        _ sessions: [SessionState],
        endingAt now: Date,
        days: Int = defaultDays,
        calendar: Calendar = .current
    ) -> [DailySummary] {
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        var latestPerDay: [Date: SessionState] = [:]
        for session in sessions where session.status == .completed && session.duration != nil {
            let day = calendar.startOfDay(for: session.startedAt)
            guard day >= windowStart, day <= today else { continue }
            if let current = latestPerDay[day], current.startedAt >= session.startedAt { continue }
            latestPerDay[day] = session
        }

        return latestPerDay
            .map { day, session in
                DailySummary(
                    day: day,
                    minutesToTarget: (session.duration ?? 0) / 60,
                    exceededThreshold: session.exceededThreshold
                )
            }
            .sorted { $0.day < $1.day }
    }
}
```

`Packages/KickCore/Sources/KickCore/GestationalAge.swift`:
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

    public static func week(dueDate: Date, now: Date, calendar: Calendar = .current) -> GestationalWeek? {
        let components = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)
        )
        guard let daysUntilDue = components.day else { return nil }
        let elapsed = pregnancyLengthDays - daysUntilDue
        guard (0...(pregnancyLengthDays + maxDaysPastDue)).contains(elapsed) else { return nil }
        return GestationalWeek(weeks: elapsed / 7, days: elapsed % 7)
    }
}
```

- [ ] **Step 4: Chạy để thấy pass**

Run: `scripts/test-core.sh`
Expected: PASS, tất cả test.

- [ ] **Step 5: Commit**

```bash
git add Packages/KickCore
git commit -m "feat(core): add 14-day history summary and gestational age"
git push
scripts/ci-wait.sh
```

---

### Task 5: NotificationScheduler

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/NotificationScheduler.swift`
- Modify: `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift` (thêm `FakeNotificationCenter`)
- Test: `Packages/KickCore/Tests/KickCoreTests/NotificationSchedulerTests.swift`

**Interfaces:**
- Consumes: `SessionRules`
- Produces:
  - `public struct NotificationText: Equatable, Sendable { title: String; body: String; init(title:body:) }`
  - `@MainActor public protocol NotificationCenterClient: AnyObject { func add(_: UNNotificationRequest) async throws; func removePending(ids: [String]); func requestAuthorization() async throws -> Bool; func authorizationStatus() async -> UNAuthorizationStatus }`
  - `@MainActor public final class SystemNotificationCenter: NotificationCenterClient` (`init()`)
  - `@MainActor public final class NotificationScheduler { init(center:); static let dailyReminderID = "daily-reminder"; static func overdueID(for: UUID) -> String; func isAuthorized() async -> Bool; func requestAuthorizationIfNeeded() async -> Bool; func scheduleDailyReminder(hour:minute:text:) async throws; func cancelDailyReminder(); func scheduleOverdueAlert(sessionID:startedAt:now:text:) async throws; func cancelOverdueAlert(sessionID:) }`
  - Test fake `FakeNotificationCenter` (`added`, `removed`, `status`, `grantOnRequest`, `requestCount`)

- [ ] **Step 1: Viết test fail**

Thêm vào cuối `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`:
```swift
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
final class FakeNotificationCenter: NotificationCenterClient {
    var added: [UNNotificationRequest] = []
    var removed: [String] = []
    var status: UNAuthorizationStatus = .authorized
    var grantOnRequest = true
    var requestCount = 0

    func add(_ request: UNNotificationRequest) async throws {
        added.removeAll { $0.identifier == request.identifier }
        added.append(request)
    }

    func removePending(ids: [String]) {
        removed.append(contentsOf: ids)
        added.removeAll { ids.contains($0.identifier) }
    }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        status = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }
}
```

`Packages/KickCore/Tests/KickCoreTests/NotificationSchedulerTests.swift`:
```swift
import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct NotificationSchedulerTests {
    let center = FakeNotificationCenter()
    let text = NotificationText(title: "T", body: "B")
    var scheduler: NotificationScheduler { NotificationScheduler(center: center) }

    @Test func dailyReminderRepeatsAtChosenTime() async throws {
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 30, text: text)
        let request = try #require(center.added.first)
        #expect(request.identifier == NotificationScheduler.dailyReminderID)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 20)
        #expect(trigger.dateComponents.minute == 30)
        #expect(request.content.title == "T")
        #expect(request.content.body == "B")
    }

    @Test func reschedulingDailyReminderReplacesIt() async throws {
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 0, text: text)
        try await scheduler.scheduleDailyReminder(hour: 21, minute: 0, text: text)
        #expect(center.added.count == 1)
        #expect((center.added[0].trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour == 21)
    }

    @Test func cancelDailyReminderRemovesIt() {
        scheduler.cancelDailyReminder()
        #expect(center.removed == [NotificationScheduler.dailyReminderID])
    }

    @Test func overdueAlertFiresTwoHoursAfterStart() async throws {
        let id = UUID()
        let start = date("2026-09-01T20:00:00Z")
        try await scheduler.scheduleOverdueAlert(sessionID: id, startedAt: start, now: start.addingTimeInterval(600), text: text)
        let request = try #require(center.added.first)
        #expect(request.identifier == NotificationScheduler.overdueID(for: id))
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == SessionRules.overdueThreshold - 600)
        #expect(trigger.repeats == false)
    }

    @Test func overdueAlertIsSkippedWhenAlreadyPastThreshold() async throws {
        let start = date("2026-09-01T20:00:00Z")
        try await scheduler.scheduleOverdueAlert(sessionID: UUID(), startedAt: start, now: start.addingTimeInterval(7200), text: text)
        #expect(center.added.isEmpty)
    }

    @Test func cancelOverdueAlertUsesSessionID() {
        let id = UUID()
        scheduler.cancelOverdueAlert(sessionID: id)
        #expect(center.removed == ["overdue-\(id.uuidString)"])
    }

    @Test func requestsAuthorizationOnlyWhenUndetermined() async {
        center.status = .notDetermined
        #expect(await scheduler.requestAuthorizationIfNeeded())
        #expect(await scheduler.requestAuthorizationIfNeeded())
        #expect(center.requestCount == 1)
    }

    @Test func deniedAuthorizationIsReported() async {
        center.status = .denied
        #expect(await scheduler.requestAuthorizationIfNeeded() == false)
        #expect(center.requestCount == 0)
        #expect(await scheduler.isAuthorized() == false)
    }
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter NotificationSchedulerTests`
Expected: FAIL — `cannot find type 'NotificationCenterClient' in scope`.

- [ ] **Step 3: Cài đặt**

`Packages/KickCore/Sources/KickCore/NotificationScheduler.swift`:
```swift
import Foundation
import OSLog
@preconcurrency import UserNotifications

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "notifications")

public struct NotificationText: Equatable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }
}

/// Seam over UNUserNotificationCenter so scheduling can be unit tested.
@MainActor
public protocol NotificationCenterClient: AnyObject {
    func add(_ request: UNNotificationRequest) async throws
    func removePending(ids: [String])
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
}

@MainActor
public final class SystemNotificationCenter: NotificationCenterClient {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    public func removePending(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
}

@MainActor
public final class NotificationScheduler {
    public static let dailyReminderID = "daily-reminder"

    public static func overdueID(for sessionID: UUID) -> String {
        "overdue-\(sessionID.uuidString)"
    }

    private let center: NotificationCenterClient

    public init(center: NotificationCenterClient) {
        self.center = center
    }

    public func isAuthorized() async -> Bool {
        switch await center.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    /// Prompts only if the user has never been asked; otherwise reports the current status.
    public func requestAuthorizationIfNeeded() async -> Bool {
        guard await center.authorizationStatus() == .notDetermined else { return await isAuthorized() }
        do {
            return try await center.requestAuthorization()
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    public func scheduleDailyReminder(hour: Int, minute: Int, text: NotificationText) async throws {
        center.removePending(ids: [Self.dailyReminderID])
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: Self.dailyReminderID, content: text.makeContent(), trigger: trigger))
    }

    public func cancelDailyReminder() {
        center.removePending(ids: [Self.dailyReminderID])
    }

    public func scheduleOverdueAlert(sessionID: UUID, startedAt: Date, now: Date, text: NotificationText) async throws {
        let fireIn = startedAt.addingTimeInterval(SessionRules.overdueThreshold).timeIntervalSince(now)
        guard fireIn > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
        try await center.add(UNNotificationRequest(identifier: Self.overdueID(for: sessionID), content: text.makeContent(), trigger: trigger))
    }

    public func cancelOverdueAlert(sessionID: UUID) {
        center.removePending(ids: [Self.overdueID(for: sessionID)])
    }
}
```

- [ ] **Step 4: Chạy để thấy pass**

Run: `scripts/test-core.sh`
Expected: PASS, tất cả test.

- [ ] **Step 5: Commit**

```bash
git add Packages/KickCore
git commit -m "feat(core): add NotificationScheduler for daily reminder and 2h overdue alert"
git push
scripts/ci-wait.sh
```

---

### Task 6: LiveActivityManaging + KickCoordinator

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/LiveActivityManaging.swift`
- Create: `Packages/KickCore/Sources/KickCore/KickCoordinator.swift`
- Modify: `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift` (thêm `FakeSessionRepository`, `FakeLiveActivities`, `TestClock`)
- Test: `Packages/KickCore/Tests/KickCoreTests/KickCoordinatorTests.swift`

**Interfaces:**
- Consumes: `SessionRepository`, `SessionRecord`, `KickResult`, `NotificationScheduler`, `NotificationText`, `SessionEngine`, `SessionState`, `KickOutcome`, `SessionRules`
- Produces:
  - `@MainActor public protocol LiveActivityManaging: AnyObject { var isAvailable: Bool { get }; func hasActivity(for: UUID) -> Bool; func start(sessionID: UUID, startedAt: Date, count: Int) async; func update(count: Int, completedAt: Date?) async; func end(dismissAfter: TimeInterval) async; func endAll() async }`
  - `public enum KickFailure: Equatable, Sendable { case loadFailed, saveFailed }`
  - `@MainActor @Observable public final class KickCoordinator` với:
    - `private(set) var activeSession: SessionState?`, `activeSessionID: UUID?`, `completedSession: SessionState?`, `failure: KickFailure?`
    - `init(store: SessionRepository, notifications: NotificationScheduler, liveActivities: LiveActivityManaging, overdueText: NotificationText, now: @escaping @MainActor () -> Date = { Date() })`
    - `func load() async`, `@discardableResult func recordKick() async -> KickOutcome`, `func undo() async`, `func cancelSession() async`, `func dismissCompletion()`, `func clearFailure()`, `func isOverdue(at: Date) -> Bool`
    - `func setDailyReminder(enabled: Bool, hour: Int, minute: Int, text: NotificationText) async -> Bool`, `func notificationsAuthorized() async -> Bool`, `var liveActivitiesAvailable: Bool`
    - `static let completedActivityLinger: TimeInterval = 900`

- [ ] **Step 1: Viết test fail**

Thêm vào cuối `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`:
```swift
/// In-memory SessionRepository with the same rules as KickStore.
@MainActor
final class FakeSessionRepository: SessionRepository {
    struct WriteFailed: Error {}

    private(set) var sessions: [UUID: SessionState] = [:]
    private var activeID: UUID?
    var failNextWrite = false

    func activeSession() throws -> SessionRecord? {
        guard let id = activeID, let state = sessions[id] else { return nil }
        return SessionRecord(id: id, state: state)
    }

    func addKick(at now: Date) throws -> KickResult {
        if failNextWrite {
            failNextWrite = false
            throw WriteFailed()
        }
        var didStart = false
        if activeID == nil {
            let id = UUID()
            sessions[id] = SessionState(startedAt: now)
            activeID = id
            didStart = true
        }
        let id = activeID!
        var state = sessions[id]!
        let outcome = SessionEngine.addKick(to: &state, at: now)
        sessions[id] = state
        if state.status != .active { activeID = nil }
        return KickResult(record: SessionRecord(id: id, state: state), outcome: outcome, didStartSession: didStart)
    }

    func undoLastKick() throws -> SessionRecord? {
        guard let id = activeID, var state = sessions[id] else { return nil }
        SessionEngine.undoLastKick(&state)
        sessions[id] = state
        return SessionRecord(id: id, state: state)
    }

    func cancelActive(at now: Date) throws -> SessionRecord? {
        guard let id = activeID, var state = sessions[id] else { return nil }
        SessionEngine.cancel(&state, at: now)
        sessions[id] = state
        activeID = nil
        return SessionRecord(id: id, state: state)
    }
}

@MainActor
final class FakeLiveActivities: LiveActivityManaging {
    var isAvailable = true
    var activeIDs: Set<UUID> = []
    var started: [(id: UUID, startedAt: Date, count: Int)] = []
    var updates: [(count: Int, completedAt: Date?)] = []
    var ended: [TimeInterval] = []
    var endAllCount = 0

    func hasActivity(for sessionID: UUID) -> Bool { activeIDs.contains(sessionID) }

    func start(sessionID: UUID, startedAt: Date, count: Int) async {
        activeIDs.insert(sessionID)
        started.append((sessionID, startedAt, count))
    }

    func update(count: Int, completedAt: Date?) async { updates.append((count, completedAt)) }

    func end(dismissAfter: TimeInterval) async {
        ended.append(dismissAfter)
        activeIDs.removeAll()
    }

    func endAll() async {
        endAllCount += 1
        activeIDs.removeAll()
    }
}

@MainActor
final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}
```

`Packages/KickCore/Tests/KickCoreTests/KickCoordinatorTests.swift`:
```swift
import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct KickCoordinatorTests {
    let t0 = date("2026-09-01T20:00:00Z")
    let overdueText = NotificationText(title: "Overdue", body: "Call your doctor")
    let repository: FakeSessionRepository
    let center: FakeNotificationCenter
    let live: FakeLiveActivities
    let clock: TestClock
    let coordinator: KickCoordinator

    init() {
        let repository = FakeSessionRepository()
        let center = FakeNotificationCenter()
        let live = FakeLiveActivities()
        let clock = TestClock(date("2026-09-01T20:00:00Z"))
        self.repository = repository
        self.center = center
        self.live = live
        self.clock = clock
        coordinator = Self.makeCoordinator(repository, center, live, clock)
    }

    private static func makeCoordinator(
        _ repository: FakeSessionRepository,
        _ center: FakeNotificationCenter,
        _ live: FakeLiveActivities,
        _ clock: TestClock
    ) -> KickCoordinator {
        KickCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            liveActivities: live,
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor"),
            now: { clock.now }
        )
    }

    private func kick(times: Int) async {
        for _ in 0..<times {
            await coordinator.recordKick()
            clock.advance(60)
        }
    }

    @Test func firstKickStartsSessionLiveActivityAndOverdueAlert() async throws {
        let outcome = await coordinator.recordKick()
        #expect(outcome == .added(count: 1))
        let id = try #require(coordinator.activeSessionID)
        #expect(coordinator.activeSession?.count == 1)
        #expect(live.started.count == 1)
        #expect(live.started[0].id == id)
        #expect(center.added.map(\.identifier) == [NotificationScheduler.overdueID(for: id)])
    }

    @Test func liveActivityIsSkippedWhenUnavailable() async {
        live.isAvailable = false
        await coordinator.recordKick()
        #expect(live.started.isEmpty)
        #expect(coordinator.activeSession?.count == 1)
    }

    @Test func overdueAlertIsSkippedWhenNotificationsDenied() async {
        center.status = .denied
        await coordinator.recordKick()
        #expect(center.added.isEmpty)
        #expect(coordinator.activeSession?.count == 1)
    }

    @Test func laterKicksUpdateLiveActivity() async {
        await kick(times: 3)
        #expect(live.updates.map(\.count) == [2, 3])
        #expect(live.updates.allSatisfy { $0.completedAt == nil })
    }

    @Test func tenthKickCompletesAndCleansUp() async throws {
        await kick(times: 9)
        let id = try #require(coordinator.activeSessionID)
        let outcome = await coordinator.recordKick()

        #expect(outcome == .completed(duration: 9 * 60))
        #expect(coordinator.activeSession == nil)
        #expect(coordinator.activeSessionID == nil)
        #expect(coordinator.completedSession?.count == 10)
        #expect(center.removed.contains(NotificationScheduler.overdueID(for: id)))
        #expect(live.updates.last?.count == 10)
        #expect(live.updates.last?.completedAt == t0.addingTimeInterval(9 * 60))
        #expect(live.ended == [KickCoordinator.completedActivityLinger])
    }

    @Test func debouncedTapChangesNothing() async {
        await coordinator.recordKick()
        clock.advance(0.2)
        #expect(await coordinator.recordKick() == .ignoredDebounce)
        #expect(coordinator.activeSession?.count == 1)
        #expect(live.updates.isEmpty)
    }

    @Test func saveFailureIsReported() async {
        repository.failNextWrite = true
        #expect(await coordinator.recordKick() == .ignoredInactive)
        #expect(coordinator.failure == .saveFailed)
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func undoUpdatesStateAndLiveActivity() async {
        await kick(times: 3)
        await coordinator.undo()
        #expect(coordinator.activeSession?.count == 2)
        #expect(live.updates.last?.count == 2)
    }

    @Test func cancelEndsEverything() async throws {
        await kick(times: 2)
        let id = try #require(coordinator.activeSessionID)
        await coordinator.cancelSession()
        #expect(coordinator.activeSession == nil)
        #expect(center.removed.contains(NotificationScheduler.overdueID(for: id)))
        #expect(live.ended == [0])
    }

    @Test func loadRestoresActiveSessionAndRestartsMissingLiveActivity() async {
        await kick(times: 2)
        live.activeIDs.removeAll()   // e.g. user dismissed it, or the app was killed

        let restored = Self.makeCoordinator(repository, center, live, clock)
        await restored.load()
        #expect(restored.activeSession?.count == 2)
        #expect(live.started.count == 2)
        #expect(live.started.last?.count == 2)
    }

    @Test func loadWithoutSessionEndsStrayActivities() async {
        await coordinator.load()
        #expect(live.endAllCount == 1)
    }

    @Test func overdueReflectsElapsedTime() async {
        await coordinator.recordKick()
        #expect(coordinator.isOverdue(at: t0.addingTimeInterval(7199)) == false)
        #expect(coordinator.isOverdue(at: t0.addingTimeInterval(7200)))
    }

    @Test func dailyReminderRequiresAuthorization() async {
        center.status = .notDetermined
        center.grantOnRequest = false
        let ok = await coordinator.setDailyReminder(enabled: true, hour: 20, minute: 0, text: overdueText)
        #expect(ok == false)
        #expect(center.added.isEmpty)
    }

    @Test func dailyReminderSchedulesAndCancels() async {
        #expect(await coordinator.setDailyReminder(enabled: true, hour: 20, minute: 0, text: overdueText))
        #expect(center.added.map(\.identifier) == [NotificationScheduler.dailyReminderID])
        #expect(await coordinator.setDailyReminder(enabled: false, hour: 20, minute: 0, text: overdueText))
        #expect(center.added.isEmpty)
    }
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter KickCoordinatorTests`
Expected: FAIL. Lỗi `cannot find type 'LiveActivityManaging' in scope`.

- [ ] **Step 3: Cài đặt**

`Packages/KickCore/Sources/KickCore/LiveActivityManaging.swift`:
```swift
import Foundation

/// Seam over ActivityKit. The real implementation lives in the app target
/// (ActivityKit and the activity attributes are iOS-only).
@MainActor
public protocol LiveActivityManaging: AnyObject {
    /// False when the user has turned Live Activities off in Settings.
    var isAvailable: Bool { get }
    func hasActivity(for sessionID: UUID) -> Bool
    func start(sessionID: UUID, startedAt: Date, count: Int) async
    func update(count: Int, completedAt: Date?) async
    /// `dismissAfter <= 0` removes the activity immediately.
    func end(dismissAfter: TimeInterval) async
    func endAll() async
}
```

`Packages/KickCore/Sources/KickCore/KickCoordinator.swift`:
```swift
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "coordinator")

public enum KickFailure: Equatable, Sendable {
    case loadFailed
    case saveFailed
}

/// Single entry point for counting actions, used by the UI and by AddKickIntent.
/// Keeps the repository, the overdue notification and the Live Activity in step.
@MainActor
@Observable
public final class KickCoordinator {
    public static let completedActivityLinger: TimeInterval = 15 * 60

    public private(set) var activeSession: SessionState?
    public private(set) var activeSessionID: UUID?
    public private(set) var completedSession: SessionState?
    public private(set) var failure: KickFailure?

    private let store: SessionRepository
    private let notifications: NotificationScheduler
    private let liveActivities: LiveActivityManaging
    private let overdueText: NotificationText
    private let now: @MainActor () -> Date

    public init(
        store: SessionRepository,
        notifications: NotificationScheduler,
        liveActivities: LiveActivityManaging,
        overdueText: NotificationText,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.notifications = notifications
        self.liveActivities = liveActivities
        self.overdueText = overdueText
        self.now = now
    }

    public var liveActivitiesAvailable: Bool { liveActivities.isAvailable }

    /// Refreshes state from the store and reconciles the Live Activity.
    /// Call on launch and whenever the app becomes active.
    public func load() async {
        do {
            let record = try store.activeSession()
            publish(record)
            if let record {
                if liveActivities.isAvailable, !liveActivities.hasActivity(for: record.id) {
                    await liveActivities.start(sessionID: record.id, startedAt: record.state.startedAt, count: record.state.count)
                }
            } else {
                await liveActivities.endAll()
            }
        } catch {
            logger.error("Loading active session failed: \(error.localizedDescription)")
            failure = .loadFailed
        }
    }

    @discardableResult
    public func recordKick() async -> KickOutcome {
        let time = now()
        let result: KickResult
        do {
            result = try store.addKick(at: time)
        } catch {
            logger.error("Saving kick failed: \(error.localizedDescription)")
            failure = .saveFailed
            return .ignoredInactive
        }

        let record = result.record
        switch result.outcome {
        case .added(let count):
            publish(record)
            if result.didStartSession {
                await startSideEffects(for: record, at: time)
            } else {
                await liveActivities.update(count: count, completedAt: nil)
            }
        case .completed:
            publish(nil)
            completedSession = record.state
            notifications.cancelOverdueAlert(sessionID: record.id)
            await liveActivities.update(count: record.state.count, completedAt: record.state.endedAt)
            await liveActivities.end(dismissAfter: Self.completedActivityLinger)
        case .ignoredDebounce, .ignoredInactive:
            break
        }
        return result.outcome
    }

    public func undo() async {
        do {
            guard let record = try store.undoLastKick() else { return }
            publish(record)
            await liveActivities.update(count: record.state.count, completedAt: nil)
        } catch {
            logger.error("Undo failed: \(error.localizedDescription)")
            failure = .saveFailed
        }
    }

    public func cancelSession() async {
        do {
            guard let record = try store.cancelActive(at: now()) else { return }
            notifications.cancelOverdueAlert(sessionID: record.id)
            publish(nil)
            await liveActivities.end(dismissAfter: 0)
        } catch {
            logger.error("Cancel failed: \(error.localizedDescription)")
            failure = .saveFailed
        }
    }

    public func dismissCompletion() {
        completedSession = nil
    }

    public func clearFailure() {
        failure = nil
    }

    public func isOverdue(at date: Date) -> Bool {
        activeSession.map { SessionEngine.isOverdue($0, now: date) } ?? false
    }

    /// Returns false if the reminder could not be scheduled (usually: permission denied).
    public func setDailyReminder(enabled: Bool, hour: Int, minute: Int, text: NotificationText) async -> Bool {
        guard enabled else {
            notifications.cancelDailyReminder()
            return true
        }
        guard await notifications.requestAuthorizationIfNeeded() else { return false }
        do {
            try await notifications.scheduleDailyReminder(hour: hour, minute: minute, text: text)
            return true
        } catch {
            logger.error("Scheduling daily reminder failed: \(error.localizedDescription)")
            return false
        }
    }

    public func notificationsAuthorized() async -> Bool {
        await notifications.isAuthorized()
    }

    private func publish(_ record: SessionRecord?) {
        activeSession = record?.state
        activeSessionID = record?.id
    }

    private func startSideEffects(for record: SessionRecord, at time: Date) async {
        if liveActivities.isAvailable {
            await liveActivities.start(sessionID: record.id, startedAt: record.state.startedAt, count: record.state.count)
        }
        guard await notifications.requestAuthorizationIfNeeded() else { return }
        do {
            try await notifications.scheduleOverdueAlert(
                sessionID: record.id, startedAt: record.state.startedAt, now: time, text: overdueText
            )
        } catch {
            logger.error("Scheduling overdue alert failed: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 4: Chạy để thấy pass**

Run: `scripts/test-core.sh`
Expected: PASS, tất cả test (trong đó có 14 test `KickCoordinatorTests`).

- [ ] **Step 5: Commit, push, CI**

```bash
git add Packages/KickCore
git commit -m "feat(core): add KickCoordinator facade syncing repository, notifications and Live Activity"
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 7: Bản địa hóa (L10n + String Catalog)

**Files:**
- Create: `Shared/L10n.swift`, `Shared/Localizable.xcstrings`, `Shared/InfoPlist.xcstrings`
- Modify: `project.yml` (thêm `Shared` vào sources của `KickCounter`)

**Interfaces:**
- Produces: `enum L10n` với các thuộc tính `static var` trả về `String` (danh sách đầy đủ bên dưới); `static func counterProgress(_ count: Int, _ target: Int) -> String`, `static func counterWeek(_ week: GestationalWeek) -> String`, `static func completionDuration(_ text: String) -> String`, `static func historyRowCount(_ count: Int) -> String`.

- [ ] **Step 1: Tạo String Catalog bằng script sinh một lần**

Chạy (sinh `Shared/Localizable.xcstrings` và `Shared/InfoPlist.xcstrings`; về sau sửa trực tiếp trong Xcode):

```bash
mkdir -p Shared && python3 - <<'PY'
import json
S = {
 "tab.counter": ("Count", "Đếm"),
 "tab.history": ("History", "Lịch sử"),
 "tab.settings": ("Settings", "Cài đặt"),
 "counter.title": ("Kick Counter", "Đếm thai máy"),
 "counter.start": ("Tap to start", "Chạm để bắt đầu"),
 "counter.tapHint": ("Tap the circle each time you feel your baby move.", "Chạm vào vòng tròn mỗi khi mẹ cảm thấy bé cử động."),
 "counter.progress": ("%1$ld of %2$ld", "%1$ld trên %2$ld"),
 "counter.elapsed": ("Elapsed", "Đã trôi qua"),
 "counter.week": ("Week %1$ld + %2$ld days", "Tuần %1$ld + %2$ld ngày"),
 "counter.undo": ("Undo", "Hoàn tác"),
 "counter.cancel": ("Cancel session", "Hủy lượt đếm"),
 "counter.cancel.confirm.title": ("Cancel this session?", "Hủy lượt đếm này?"),
 "counter.cancel.confirm.message": ("It will be saved in History as cancelled.", "Lượt này sẽ được lưu vào Lịch sử với trạng thái đã hủy."),
 "counter.keepCounting": ("Keep counting", "Tiếp tục đếm"),
 "counter.a11y.button": ("Record movement", "Ghi nhận cử động"),
 "counter.a11y.value": ("%1$ld of %2$ld movements", "Đã có %1$ld trên %2$ld cử động"),
 "overdue.title": ("It's been over 2 hours", "Đã hơn 2 giờ"),
 "overdue.body": ("You haven't felt 10 movements yet. Please contact your doctor or maternity unit now — don't wait.", "Mẹ chưa cảm nhận đủ 10 cử động. Hãy liên hệ bác sĩ hoặc cơ sở y tế ngay, đừng chờ đợi."),
 "completion.title": ("10 movements!", "Đủ 10 cử động!"),
 "completion.duration": ("Completed in %@", "Hoàn thành trong %@"),
 "completion.exceeded": ("This took longer than 2 hours. Please mention it to your doctor.", "Lần này mất hơn 2 giờ. Mẹ hãy báo với bác sĩ nhé."),
 "completion.done": ("Done", "Xong"),
 "history.title": ("History", "Lịch sử"),
 "history.chart.title": ("Time to 10 movements · last 14 days", "Thời gian đạt 10 cử động · 14 ngày qua"),
 "history.chart.day": ("Day", "Ngày"),
 "history.chart.minutes": ("Minutes", "Phút"),
 "history.chart.threshold": ("2 hours", "2 giờ"),
 "history.empty.title": ("No sessions yet", "Chưa có lượt đếm nào"),
 "history.empty.body": ("Your counting sessions will appear here.", "Các lượt đếm của mẹ sẽ hiện ở đây."),
 "history.status.completed": ("Completed", "Hoàn thành"),
 "history.status.cancelled": ("Cancelled", "Đã hủy"),
 "history.row.count": ("%ld movements", "%ld cử động"),
 "history.delete.confirm.title": ("Delete this session?", "Xóa lượt đếm này?"),
 "common.delete": ("Delete", "Xóa"),
 "common.cancel": ("Cancel", "Hủy"),
 "common.ok": ("OK", "OK"),
 "settings.title": ("Settings", "Cài đặt"),
 "settings.reminder.section": ("Daily reminder", "Nhắc hằng ngày"),
 "settings.reminder.toggle": ("Remind me to count", "Nhắc tôi đếm"),
 "settings.reminder.time": ("Time", "Giờ nhắc"),
 "settings.pregnancy.section": ("Pregnancy", "Thai kỳ"),
 "settings.dueDate.toggle": ("Set due date", "Đặt ngày dự sinh"),
 "settings.dueDate": ("Due date", "Ngày dự sinh"),
 "settings.permissions.section": ("Permissions", "Quyền"),
 "settings.notifications.denied": ("Notifications are off. Turn them on to get reminders and the 2-hour alert.", "Thông báo đang tắt. Bật lên để nhận nhắc giờ và cảnh báo 2 giờ."),
 "settings.liveActivities.off": ("Live Activities are off. Turn them on to count from the Lock Screen.", "Live Activity đang tắt. Bật lên để đếm ngay trên màn hình khóa."),
 "settings.openSettings": ("Open Settings", "Mở Cài đặt"),
 "settings.about.section": ("About", "Thông tin"),
 "settings.medicalInfo": ("Medical information", "Thông tin y tế"),
 "settings.version": ("Version", "Phiên bản"),
 "reminder.title": ("Time to count kicks", "Đến giờ đếm thai máy"),
 "reminder.body": ("Lie on your side, relax, and count 10 movements.", "Mẹ nằm nghiêng thư giãn và đếm 10 cử động nhé."),
 "medical.title": ("Medical information", "Thông tin y tế"),
 "medical.body": ("Kick Counter helps you keep track of your baby's movements. It is not a medical device and does not replace advice from your doctor or midwife.\n\nFrom around week 28, get to know your baby's usual pattern of movements. Most babies make 10 movements within 2 hours, often much sooner.\n\nIf you notice your baby is moving less than usual, or you have not felt 10 movements within 2 hours, contact your doctor or maternity unit straight away — day or night. Do not wait until the next day, and do not rely on this app or a home heartbeat monitor to reassure you.\n\nIn an emergency, call your local emergency number.", "Kick Counter giúp mẹ theo dõi cử động của bé. App không phải thiết bị y tế và không thay thế lời khuyên của bác sĩ hay nữ hộ sinh.\n\nTừ khoảng tuần 28, mẹ hãy làm quen với nhịp cử động thường ngày của bé. Phần lớn các bé có 10 cử động trong vòng 2 giờ, thường nhanh hơn nhiều.\n\nNếu thấy bé cử động ít hơn bình thường, hoặc chưa cảm nhận đủ 10 cử động trong 2 giờ, hãy liên hệ ngay bác sĩ hoặc cơ sở y tế, dù ngày hay đêm. Đừng chờ đến hôm sau, và đừng dựa vào app này hay máy nghe tim thai tại nhà để yên tâm.\n\nTrong trường hợp khẩn cấp, hãy gọi 115."),
 "onboarding.1.title": ("Count 10 movements", "Đếm 10 cử động"),
 "onboarding.1.body": ("Tap the big circle each time you feel your baby move — a kick, roll, or flutter. When you reach 10, you're done.", "Chạm vào vòng tròn lớn mỗi khi cảm thấy bé cử động: đạp, xoay hay trườn. Đủ 10 lần là xong."),
 "onboarding.2.title": ("When to count", "Khi nào nên đếm"),
 "onboarding.2.body": ("From week 28, count once a day at a time your baby is usually active, such as after a meal or in the evening.", "Từ tuần 28, mỗi ngày đếm một lần vào lúc bé hay cử động, như sau bữa ăn hoặc buổi tối."),
 "onboarding.3.title": ("Not a substitute for medical advice", "Không thay thế tư vấn y tế"),
 "onboarding.3.body": ("If your baby is moving less than usual, contact your doctor or maternity unit right away. Don't wait for the app.", "Nếu thấy bé cử động ít hơn bình thường, hãy liên hệ ngay bác sĩ hoặc cơ sở y tế. Đừng chờ kết quả từ app."),
 "onboarding.next": ("Next", "Tiếp"),
 "onboarding.agree": ("I understand", "Tôi đã hiểu"),
 "error.save": ("Couldn't save. Please try again.", "Không lưu được. Mẹ thử lại nhé."),
 "error.load": ("Couldn't load your session. Please reopen the app.", "Không tải được lượt đếm. Mẹ hãy mở lại app."),
 "error.store.title": ("Something went wrong", "Đã có lỗi xảy ra"),
 "error.store.body": ("Your data couldn't be opened. Please close and reopen the app.", "Không mở được dữ liệu. Mẹ hãy đóng và mở lại app."),
 "intent.addKick.title": ("Record movement", "Ghi nhận cử động"),
 "la.overdue": ("Over 2 hours — contact your doctor", "Quá 2 giờ — hãy liên hệ bác sĩ"),
 "la.completed": ("Done!", "Xong!"),
 "la.add": ("+1", "+1"),
}
def entry(en, vi):
    return {"extractionState": "manual", "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": en}},
        "vi": {"stringUnit": {"state": "translated", "value": vi}}}}
with open("Shared/Localizable.xcstrings", "w", encoding="utf-8") as f:
    json.dump({"sourceLanguage": "en", "strings": {k: entry(*v) for k, v in sorted(S.items())}, "version": "1.0"}, f, ensure_ascii=False, indent=2)
info = {"CFBundleDisplayName": ("Kick Counter", "Đếm Thai Máy")}
with open("Shared/InfoPlist.xcstrings", "w", encoding="utf-8") as f:
    json.dump({"sourceLanguage": "en", "strings": {k: entry(*v) for k, v in info.items()}, "version": "1.0"}, f, ensure_ascii=False, indent=2)
print(len(S), "strings written")
PY
```
Expected: in ra `<N> strings written`, không có lỗi.

- [ ] **Step 2: Viết `Shared/L10n.swift`**

```swift
import Foundation
import KickCore

/// Typed access to Localizable.xcstrings. Every user-facing string goes through here.
enum L10n {
    private static func t(_ key: String.LocalizationValue) -> String { String(localized: key) }

    static var tabCounter: String { t("tab.counter") }
    static var tabHistory: String { t("tab.history") }
    static var tabSettings: String { t("tab.settings") }

    static var counterTitle: String { t("counter.title") }
    static var counterStart: String { t("counter.start") }
    static var counterTapHint: String { t("counter.tapHint") }
    static var counterElapsed: String { t("counter.elapsed") }
    static var counterUndo: String { t("counter.undo") }
    static var counterCancel: String { t("counter.cancel") }
    static var counterCancelConfirmTitle: String { t("counter.cancel.confirm.title") }
    static var counterCancelConfirmMessage: String { t("counter.cancel.confirm.message") }
    static var counterKeepCounting: String { t("counter.keepCounting") }
    static var counterA11yButton: String { t("counter.a11y.button") }
    static func counterA11yValue(_ count: Int, _ target: Int) -> String { String(format: t("counter.a11y.value"), count, target) }
    static func counterProgress(_ count: Int, _ target: Int) -> String { String(format: t("counter.progress"), count, target) }
    static func counterWeek(_ week: GestationalWeek) -> String { String(format: t("counter.week"), week.weeks, week.days) }

    static var overdueTitle: String { t("overdue.title") }
    static var overdueBody: String { t("overdue.body") }

    static var completionTitle: String { t("completion.title") }
    static func completionDuration(_ text: String) -> String { String(format: t("completion.duration"), text) }
    static var completionExceeded: String { t("completion.exceeded") }
    static var completionDone: String { t("completion.done") }

    static var historyTitle: String { t("history.title") }
    static var historyChartTitle: String { t("history.chart.title") }
    static var historyChartDay: String { t("history.chart.day") }
    static var historyChartMinutes: String { t("history.chart.minutes") }
    static var historyChartThreshold: String { t("history.chart.threshold") }
    static var historyEmptyTitle: String { t("history.empty.title") }
    static var historyEmptyBody: String { t("history.empty.body") }
    static var historyStatusCompleted: String { t("history.status.completed") }
    static var historyStatusCancelled: String { t("history.status.cancelled") }
    static func historyRowCount(_ count: Int) -> String { String(format: t("history.row.count"), count) }
    static var historyDeleteConfirmTitle: String { t("history.delete.confirm.title") }

    static var commonDelete: String { t("common.delete") }
    static var commonCancel: String { t("common.cancel") }
    static var commonOK: String { t("common.ok") }

    static var settingsTitle: String { t("settings.title") }
    static var settingsReminderSection: String { t("settings.reminder.section") }
    static var settingsReminderToggle: String { t("settings.reminder.toggle") }
    static var settingsReminderTime: String { t("settings.reminder.time") }
    static var settingsPregnancySection: String { t("settings.pregnancy.section") }
    static var settingsDueDateToggle: String { t("settings.dueDate.toggle") }
    static var settingsDueDate: String { t("settings.dueDate") }
    static var settingsPermissionsSection: String { t("settings.permissions.section") }
    static var settingsNotificationsDenied: String { t("settings.notifications.denied") }
    static var settingsLiveActivitiesOff: String { t("settings.liveActivities.off") }
    static var settingsOpenSettings: String { t("settings.openSettings") }
    static var settingsAboutSection: String { t("settings.about.section") }
    static var settingsMedicalInfo: String { t("settings.medicalInfo") }
    static var settingsVersion: String { t("settings.version") }

    static var reminderTitle: String { t("reminder.title") }
    static var reminderBody: String { t("reminder.body") }

    static var medicalTitle: String { t("medical.title") }
    static var medicalBody: String { t("medical.body") }

    static var onboarding1Title: String { t("onboarding.1.title") }
    static var onboarding1Body: String { t("onboarding.1.body") }
    static var onboarding2Title: String { t("onboarding.2.title") }
    static var onboarding2Body: String { t("onboarding.2.body") }
    static var onboarding3Title: String { t("onboarding.3.title") }
    static var onboarding3Body: String { t("onboarding.3.body") }
    static var onboardingNext: String { t("onboarding.next") }
    static var onboardingAgree: String { t("onboarding.agree") }

    static var errorSave: String { t("error.save") }
    static var errorLoad: String { t("error.load") }
    static var errorStoreTitle: String { t("error.store.title") }
    static var errorStoreBody: String { t("error.store.body") }

    static var laOverdue: String { t("la.overdue") }
    static var laCompleted: String { t("la.completed") }
    static var laAdd: String { t("la.add") }
}
```

(`intent.addKick.title` được `AddKickIntent` dùng trực tiếp qua `LocalizedStringResource` ở Task 11.)

- [ ] **Step 3: Thêm `Shared` vào target app**

Sửa `project.yml`, trong `targets.KickCounter.sources`:
```yaml
    sources:
      - App
      - Shared
```

- [ ] **Step 4: Kiểm tra catalog có đủ bản dịch**

Run:
```bash
python3 -c "import json;d=json.load(open('Shared/Localizable.xcstrings'));m=[k for k,v in d['strings'].items() if set(v['localizations'])!={'en','vi'}];print('missing:',m);assert not m"
```
Expected: `missing: []`. Việc build app với catalog được CI kiểm tra sau khi commit.

- [ ] **Step 5: Commit, push, CI**

```bash
git add Shared project.yml
git commit -m "feat(l10n): add English and Vietnamese string catalogs with typed L10n accessors"
git push
scripts/ci-wait.sh
```

---

### Task 8: App wiring + màn hình Đếm

**Files:**
- Create: `App/AppEnvironment.swift`, `App/TestDoubles.swift`, `App/RootView.swift`, `App/StoreErrorView.swift`, `App/Formatting.swift`
- Create: `App/Counter/CounterView.swift`, `App/Counter/KickButton.swift`, `App/Counter/OverdueBanner.swift`, `App/Counter/CompletionView.swift`
- Modify: `App/KickCounterApp.swift` (thay toàn bộ), `project.yml` (thêm target UI test), `scripts/ci.sh` (`build` → `test`)
- Test: `UITests/ScreenshotTests.swift`

**Interfaces:**
- Consumes: `KickCoordinator`, `KickStore` + `KickPersistence` (KickData), `NotificationScheduler`, `SystemNotificationCenter`, `NotificationCenterClient`, `LiveActivityManaging`, `AppGroup`, `SettingsKey`, `GestationalAge`, `SessionRules`, `L10n`
- Produces:
  - `@MainActor struct AppEnvironment { container: ModelContainer; coordinator: KickCoordinator; static let isUITesting: Bool; static let forceDarkMode: Bool; static func make() throws -> AppEnvironment }`
  - `final class ScreenshotTests: XCTestCase` với helper `launch(language:dark:)`, `snap(_:_:)`, `tapKick(_:times:)`. Task 9 và 10 thêm method vào class này.
  - `final class DisabledNotificationCenter: NotificationCenterClient`, `final class NoopLiveActivityManager: LiveActivityManaging`
  - `enum Formatting { static func duration(_ seconds: TimeInterval) -> String }`
  - `RootView` (TabView; tab History/Settings là placeholder cho tới Task 9–10), `CounterView`, `KickButton`, `CompletionView`, `OverdueBanner`, `StoreErrorView`

- [ ] **Step 1: AppEnvironment và test doubles**

`App/TestDoubles.swift`:
```swift
import Foundation
import KickCore
@preconcurrency import UserNotifications

/// Used with -uiTesting so no system permission prompt interrupts UI tests.
@MainActor
final class DisabledNotificationCenter: NotificationCenterClient {
    func add(_ request: UNNotificationRequest) async throws {}
    func removePending(ids: [String]) {}
    func requestAuthorization() async throws -> Bool { false }
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
}

@MainActor
final class NoopLiveActivityManager: LiveActivityManaging {
    var isAvailable: Bool { false }
    func hasActivity(for sessionID: UUID) -> Bool { false }
    func start(sessionID: UUID, startedAt: Date, count: Int) async {}
    func update(count: Int, completedAt: Date?) async {}
    func end(dismissAfter: TimeInterval) async {}
    func endAll() async {}
}
```

`App/AppEnvironment.swift`:
```swift
import Foundation
import KickCore
import KickData
import SwiftData

@MainActor
struct AppEnvironment {
    let container: ModelContainer
    let coordinator: KickCoordinator

    private static let arguments = ProcessInfo.processInfo.arguments
    static let isUITesting = arguments.contains("-uiTesting")
    static let forceDarkMode = arguments.contains("-forceDarkMode")

    static func make() throws -> AppEnvironment {
        if isUITesting {
            AppGroup.defaults.removePersistentDomain(forName: AppGroup.identifier)
            if arguments.contains("-skipOnboarding") {
                AppGroup.defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
            }
        }
        let container = try KickPersistence.makeContainer(inMemory: isUITesting)
        let notificationCenter: NotificationCenterClient = isUITesting ? DisabledNotificationCenter() : SystemNotificationCenter()
        let liveActivities: LiveActivityManaging = NoopLiveActivityManager() // replaced in Task 11
        let coordinator = KickCoordinator(
            store: KickStore(context: container.mainContext),
            notifications: NotificationScheduler(center: notificationCenter),
            liveActivities: liveActivities,
            overdueText: NotificationText(title: L10n.overdueTitle, body: L10n.overdueBody)
        )
        return AppEnvironment(container: container, coordinator: coordinator)
    }
}
```

- [ ] **Step 2: App entry, RootView, StoreErrorView, Formatting**

`App/KickCounterApp.swift`:
```swift
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "app")

@main
struct KickCounterApp: App {
    private let environment: Result<AppEnvironment, Error>

    init() {
        environment = Result { try AppEnvironment.make() }
        if case .failure(let error) = environment {
            logger.fault("Could not open the data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            switch environment {
            case .success(let env):
                RootView()
                    .environment(env.coordinator)
                    .modelContainer(env.container)
                    .preferredColorScheme(AppEnvironment.forceDarkMode ? .dark : nil)
            case .failure:
                StoreErrorView()
            }
        }
    }
}
```

`App/RootView.swift`:
```swift
import KickCore
import SwiftUI

struct RootView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasCompletedOnboarding, store: AppGroup.defaults)
    private var hasCompletedOnboarding = false

    var body: some View {
        TabView {
            CounterView()
                .tabItem { Label(L10n.tabCounter, systemImage: "hand.tap.fill") }
            Text(L10n.historyTitle) // replaced by HistoryView in Task 9
                .tabItem { Label(L10n.tabHistory, systemImage: "chart.bar.fill") }
            Text(L10n.settingsTitle) // replaced by SettingsView in Task 10
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
        }
        .task { await coordinator.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await coordinator.load() } }
        }
    }
}
```

`App/StoreErrorView.swift`:
```swift
import SwiftUI

struct StoreErrorView: View {
    var body: some View {
        ContentUnavailableView(
            L10n.errorStoreTitle,
            systemImage: "exclamationmark.triangle",
            description: Text(L10n.errorStoreBody)
        )
    }
}
```

`App/Formatting.swift`:
```swift
import Foundation

enum Formatting {
    /// e.g. "23 min", "1 hr, 5 min", "45 sec" — localized by the system.
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
}
```

- [ ] **Step 3: Các view của màn hình Đếm**

`App/Counter/KickButton.swift`:
```swift
import SwiftUI

/// The large tap target. Fills a progress ring as movements are recorded.
struct KickButton: View {
    let count: Int
    let target: Int
    let isActive: Bool
    let action: () -> Void

    private var progress: Double { Double(count) / Double(target) }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12))
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 16)
                    .padding(8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(8)
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(isActive ? L10n.counterProgress(count, target) : L10n.counterStart)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .monospacedDigit()
            }
        }
        .buttonStyle(PressableCircleStyle())
        .frame(maxWidth: 340)
        .aspectRatio(1, contentMode: .fit)
        .animation(.spring(duration: 0.3), value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.counterA11yButton)
        .accessibilityValue(L10n.counterA11yValue(count, target))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("kickButton")
    }
}

private struct PressableCircleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
```

`App/Counter/OverdueBanner.swift`:
```swift
import SwiftUI

struct OverdueBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "phone.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.overdueTitle).font(.headline)
                Text(L10n.overdueBody).font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
```

`App/Counter/CompletionView.swift`:
```swift
import KickCore
import SwiftUI

struct CompletionView: View {
    let session: SessionState
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(L10n.completionTitle)
                .font(.largeTitle.bold())
                .accessibilityIdentifier("completionTitle")
            if let duration = session.duration {
                Text(L10n.completionDuration(Formatting.duration(duration)))
                    .font(.title3)
            }
            if session.exceededThreshold {
                Text(L10n.completionExceeded)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            }
            Spacer()
            Button(action: onDone) {
                Text(L10n.completionDone).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("completionDone")
        }
        .padding(24)
    }
}
```

`App/Counter/CounterView.swift`:
```swift
import KickCore
import SwiftUI

struct CounterView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var confirmingCancel = false

    private var count: Int { coordinator.activeSession?.count ?? 0 }

    private var gestationalWeekText: String? {
        guard dueDate > 0,
              let week = GestationalAge.week(dueDate: Date(timeIntervalSince1970: dueDate), now: .now)
        else { return nil }
        return L10n.counterWeek(week)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let gestationalWeekText {
                        Text(gestationalWeekText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        if coordinator.isOverdue(at: context.date) {
                            OverdueBanner()
                        }
                    }

                    KickButton(
                        count: count,
                        target: SessionRules.targetCount,
                        isActive: coordinator.activeSession != nil
                    ) {
                        Task { await coordinator.recordKick() }
                    }
                    .padding(.horizontal, 24)

                    if let session = coordinator.activeSession {
                        VStack(spacing: 4) {
                            Text(L10n.counterElapsed).font(.caption).foregroundStyle(.secondary)
                            Text(session.startedAt, style: .timer)
                                .font(.title2.monospacedDigit())
                        }
                        HStack(spacing: 16) {
                            Button {
                                Task { await coordinator.undo() }
                            } label: {
                                Label(L10n.counterUndo, systemImage: "arrow.uturn.backward")
                            }
                            .disabled(session.count == 0)
                            .accessibilityIdentifier("undoButton")

                            Button(role: .destructive) {
                                confirmingCancel = true
                            } label: {
                                Label(L10n.counterCancel, systemImage: "xmark")
                            }
                            .accessibilityIdentifier("cancelSessionButton")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Text(L10n.counterTapHint)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.counterTitle)
            .sensoryFeedback(.impact(weight: .medium), trigger: count)
            .confirmationDialog(L10n.counterCancelConfirmTitle, isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button(L10n.counterCancel, role: .destructive) {
                    Task { await coordinator.cancelSession() }
                }
                Button(L10n.counterKeepCounting, role: .cancel) {}
            } message: {
                Text(L10n.counterCancelConfirmMessage)
            }
            .sheet(isPresented: completionBinding) {
                if let session = coordinator.completedSession {
                    CompletionView(session: session) { coordinator.dismissCompletion() }
                        .presentationDetents([.medium, .large])
                }
            }
            .alert(failureMessage ?? "", isPresented: failureBinding) {
                Button(L10n.commonOK) { coordinator.clearFailure() }
            }
        }
    }

    private var completionBinding: Binding<Bool> {
        Binding(
            get: { coordinator.completedSession != nil },
            set: { if !$0 { coordinator.dismissCompletion() } }
        )
    }

    private var failureMessage: String? {
        switch coordinator.failure {
        case .saveFailed: L10n.errorSave
        case .loadFailed: L10n.errorLoad
        case nil: nil
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { coordinator.failure != nil },
            set: { if !$0 { coordinator.clearFailure() } }
        )
    }
}
```

- [ ] **Step 4: Target UI test + test chụp màn hình**

`UITests/ScreenshotTests.swift`:
```swift
import XCTest

/// Captures screenshots for visual review. CI exports them to build/screenshots,
/// and `scripts/ci-wait.sh` downloads them to ci-artifacts/screenshots.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func launch(language: String = "vi", dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "vi" ? "vi_VN" : "en_US",
        ]
        if dark { app.launchArguments.append("-forceDarkMode") }
        app.launch()
        return app
    }

    @MainActor
    func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func tapKick(_ app: XCUIApplication, times: Int) {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 10))
        for _ in 0..<times {
            kick.tap()
            Thread.sleep(forTimeInterval: 0.6) // stay above the 0.5 s debounce
        }
    }

    @MainActor
    func testCounterScreens() {
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            let app = launch(dark: dark)
            tapKick(app, times: 0)
            snap(app, "counter-empty-\(suffix)")
            tapKick(app, times: 3)
            snap(app, "counter-3-\(suffix)")
            tapKick(app, times: 7)
            XCTAssertTrue(app.staticTexts["completionTitle"].waitForExistence(timeout: 5))
            snap(app, "completion-\(suffix)")
            app.terminate()
        }
        let app = launch(language: "en")
        tapKick(app, times: 2)
        snap(app, "counter-2-en")
    }
}
```

Trong `project.yml`, thêm vào `targets:`:
```yaml
  KickCounterUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - UITests
    dependencies:
      - target: KickCounter
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lmtiep.kickcounter.uitests
```
và thay khối `schemes:` bằng:
```yaml
schemes:
  KickCounter:
    build:
      targets:
        KickCounter: all
        KickCounterUITests: [test]
    test:
      targets:
        - KickCounterUITests
```

Trong `scripts/ci.sh` thay dòng `XCODE_ACTION="build"` bằng `XCODE_ACTION="test"`.

- [ ] **Step 5: Commit, push, xác minh trên CI**

```bash
git add App UITests project.yml scripts/ci.sh
git commit -m "feat(app): wire KickCoordinator and build the counting screen"
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`. Thư mục `ci-artifacts/screenshots/` có các file `counter-empty-light…png`, `counter-3-…`, `completion-…`, `counter-2-en…`.

Mở từng ảnh bằng Read tool và xác nhận:
- `counter-empty-*`: nút tròn lớn hiện "0" và "Chạm để bắt đầu", có dòng gợi ý bên dưới, không bị tràn chữ.
- `counter-3-*`: vòng tiến độ đầy khoảng 30%, hiện "3 trên 10", có đồng hồ "Đã trôi qua", có nút Hoàn tác và Hủy lượt đếm.
- `completion-*`: sheet "Đủ 10 cử động!" với dòng "Hoàn thành trong …" và nút "Xong".
- `*-dark`: nền tối, chữ đủ tương phản, màu nhấn hồng sáng hơn bản sáng.
- `counter-2-en`: toàn bộ chữ là tiếng Anh ("2 of 10").

Nếu có điểm không đạt, sửa rồi lặp lại Step 5. Có thể dùng skill `ui-ux-pro-max` để tinh chỉnh giao diện, miễn không đổi identifier hay chuỗi.

---

### Task 9: Màn hình Lịch sử + biểu đồ

**Files:**
- Create: `App/History/HistoryView.swift`, `App/History/HistoryChart.swift`, `App/History/SessionRow.swift`
- Modify: `App/RootView.swift` (thay placeholder tab History), `UITests/ScreenshotTests.swift` (thêm test chụp Lịch sử)

**Interfaces:**
- Consumes: `KickSession` (`@Query`, từ KickData), `HistorySummary.daily`, `DailySummary`, `SessionRules`, `Formatting.duration`, `L10n`
- Produces: `HistoryView`, `HistoryChart(summaries: [DailySummary], endingAt: Date)`, `SessionRow(session: KickSession)`

- [ ] **Step 1: Viết các view**

`App/History/HistoryChart.swift`:
```swift
import Charts
import KickCore
import SwiftUI

struct HistoryChart: View {
    let summaries: [DailySummary]
    let endingAt: Date

    private var domain: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endingAt))!
        let start = calendar.date(byAdding: .day, value: -HistorySummary.defaultDays, to: end)!
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.historyChartTitle).font(.headline)
            Chart {
                ForEach(summaries) { summary in
                    BarMark(
                        x: .value(L10n.historyChartDay, summary.day, unit: .day),
                        y: .value(L10n.historyChartMinutes, summary.minutesToTarget)
                    )
                    .foregroundStyle(summary.exceededThreshold ? Color.orange : Color.accentColor)
                    .cornerRadius(4)
                }
                RuleMark(y: .value(L10n.historyChartThreshold, SessionRules.overdueThreshold / 60))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text(L10n.historyChartThreshold).font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartXScale(domain: domain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) {
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                }
            }
            .chartYAxisLabel(L10n.historyChartMinutes)
            .frame(height: 200)
        }
        .padding(.vertical, 8)
    }
}
```

`App/History/SessionRow.swift`:
```swift
import KickCore
import KickData
import SwiftUI

struct SessionRow: View {
    let session: KickSession

    var body: some View {
        let state = session.state
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.startedAt, format: .dateTime.hour().minute())
                    .font(.headline)
                Text(L10n.historyRowCount(state.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let duration = state.duration {
                    Text(Formatting.duration(duration)).font(.body.monospacedDigit())
                }
                statusLabel(state)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sessionRow")
    }

    @ViewBuilder
    private func statusLabel(_ state: SessionState) -> some View {
        switch state.status {
        case .completed:
            Label(L10n.historyStatusCompleted, systemImage: state.exceededThreshold ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(state.exceededThreshold ? Color.orange : Color.green)
        case .cancelled, .active:
            Label(L10n.historyStatusCancelled, systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

`App/History/HistoryView.swift`:
```swift
import KickCore
import KickData
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "history")

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<KickSession> { $0.statusRaw != "active" },
        sort: \KickSession.startedAt,
        order: .reverse
    )
    private var sessions: [KickSession]
    @State private var pendingDelete: KickSession?

    private var days: [(day: Date, sessions: [KickSession])] {
        Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.startedAt) }
            .map { (day: $0.key, sessions: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        L10n.historyEmptyTitle,
                        systemImage: "chart.bar",
                        description: Text(L10n.historyEmptyBody)
                    )
                } else {
                    List {
                        Section {
                            HistoryChart(
                                summaries: HistorySummary.daily(sessions.map(\.state), endingAt: .now),
                                endingAt: .now
                            )
                        }
                        ForEach(days, id: \.day) { group in
                            Section(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                                ForEach(group.sessions) { session in
                                    SessionRow(session: session)
                                        .swipeActions {
                                            Button(role: .destructive) {
                                                pendingDelete = session
                                            } label: {
                                                Label(L10n.commonDelete, systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.historyTitle)
            .confirmationDialog(
                L10n.historyDeleteConfirmTitle,
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button(L10n.commonDelete, role: .destructive) { deletePending() }
                Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
            }
        }
    }

    private func deletePending() {
        guard let session = pendingDelete else { return }
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            logger.error("Deleting session failed: \(error.localizedDescription)")
            modelContext.rollback()
        }
        pendingDelete = nil
    }
}
```

- [ ] **Step 2: Nối vào RootView**

Trong `App/RootView.swift` thay:
```swift
            Text(L10n.historyTitle) // replaced by HistoryView in Task 9
                .tabItem { Label(L10n.tabHistory, systemImage: "chart.bar.fill") }
```
bằng:
```swift
            HistoryView()
                .tabItem { Label(L10n.tabHistory, systemImage: "chart.bar.fill") }
```

- [ ] **Step 3: Thêm test chụp màn hình Lịch sử**

Thêm các method sau vào class `ScreenshotTests` trong `UITests/ScreenshotTests.swift`:
```swift
    /// Confirms the cancel-session dialog (its destructive button comes first).
    @MainActor
    func confirmCancel(_ app: XCUIApplication) {
        let sheetButton = app.sheets.buttons.element(boundBy: 0)
        if sheetButton.waitForExistence(timeout: 2) {
            sheetButton.tap()
            return
        }
        // Newer iOS versions may show a popover: its button has the same label.
        let label = app.buttons["cancelSessionButton"].label
        app.buttons.matching(NSPredicate(format: "label == %@", label)).element(boundBy: 1).tap()
    }

    @MainActor
    func testHistoryScreens() {
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            let app = launch(dark: dark)
            tapKick(app, times: 10)
            XCTAssertTrue(app.buttons["completionDone"].waitForExistence(timeout: 5))
            app.buttons["completionDone"].tap()
            tapKick(app, times: 2)
            app.buttons["cancelSessionButton"].tap()
            confirmCancel(app)
            app.tabBars.buttons.element(boundBy: 1).tap()
            XCTAssertTrue(app.descendants(matching: .any)["sessionRow"].firstMatch.waitForExistence(timeout: 5))
            snap(app, "history-\(suffix)")
            app.terminate()
        }
    }
```

- [ ] **Step 4: Commit, push, xác minh trên CI**

```bash
git add App UITests
git commit -m "feat(app): add history screen with 14-day chart and session list"
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, có thêm ảnh `history-light…png` và `history-dark…png`.

Mở ảnh bằng Read tool và xác nhận:
- Biểu đồ có tiêu đề "Thời gian đạt 10 cử động · 14 ngày qua" và đường nét đứt "2 giờ". Cột của hôm nay rất thấp vì lượt test chỉ mất vài giây, như vậy là bình thường.
- Danh sách có section theo ngày với 2 dòng: một "Hoàn thành" (dấu tích xanh) và một "Đã hủy".
- Bản tối dễ đọc.

---

### Task 10: Cài đặt, Thông tin y tế, Onboarding, Privacy manifest

**Files:**
- Create: `App/Settings/SettingsView.swift`, `App/Settings/MedicalInfoView.swift`, `App/Onboarding/OnboardingView.swift`, `App/PrivacyInfo.xcprivacy`
- Modify: `App/RootView.swift` (tab Settings + onboarding cover), `UITests/ScreenshotTests.swift` (thêm test chụp Onboarding/Cài đặt)

**Interfaces:**
- Consumes: `KickCoordinator.setDailyReminder`, `.notificationsAuthorized()`, `.liveActivitiesAvailable`, `SettingsKey`, `SettingsDefault`, `AppGroup`, `NotificationText`, `L10n`
- Produces: `SettingsView`, `MedicalInfoView`, `OnboardingView(onFinish: () -> Void)`

- [ ] **Step 1: Viết các view**

`App/Settings/MedicalInfoView.swift`:
```swift
import SwiftUI

struct MedicalInfoView: View {
    var body: some View {
        ScrollView {
            Text(L10n.medicalBody)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(L10n.medicalTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

`App/Settings/SettingsView.swift`:
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

    @State private var notificationsAuthorized = true

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.settingsReminderSection) {
                    Toggle(L10n.settingsReminderToggle, isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker(L10n.settingsReminderTime, selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section(L10n.settingsPregnancySection) {
                    Toggle(L10n.settingsDueDateToggle, isOn: hasDueDate)
                    if dueDate > 0 {
                        DatePicker(
                            L10n.settingsDueDate,
                            selection: dueDateValue,
                            in: Date.now...Date.now.addingTimeInterval(300 * 86_400),
                            displayedComponents: .date
                        )
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
                    LabeledContent(L10n.settingsVersion, value: appVersion)
                }
            }
            .navigationTitle(L10n.settingsTitle)
            .task { await refreshPermissions() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshPermissions() } }
            }
            .onChange(of: reminderEnabled) { Task { await applyReminder() } }
            .onChange(of: reminderHour) { Task { await applyReminder() } }
            .onChange(of: reminderMinute) { Task { await applyReminder() } }
        }
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

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { dueDate > 0 },
            set: { enabled in
                dueDate = enabled ? Date.now.addingTimeInterval(90 * 86_400).timeIntervalSince1970 : 0
            }
        )
    }

    private var dueDateValue: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: dueDate) },
            set: { dueDate = $0.timeIntervalSince1970 }
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

Lưu ý: `notificationsAuthorized` trả `false` cả khi người dùng chưa từng được hỏi quyền. Trong trường hợp đó, mục Quyền vẫn hiện dòng nhắc kèm nút mở Settings. Đây là hành vi chấp nhận được.

`App/Onboarding/OnboardingView.swift`:
```swift
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

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
                Button(action: onFinish) {
                    Text(L10n.onboardingAgree).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingAgree")
                .padding(24)
            }
        }
        .interactiveDismissDisabled()
    }
}
```

`App/PrivacyInfo.xcprivacy`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
                <string>1C8F.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Nối vào RootView**

Trong `App/RootView.swift` thay:
```swift
            Text(L10n.settingsTitle) // replaced by SettingsView in Task 10
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
```
bằng:
```swift
            SettingsView()
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
```
và thêm modifier ngay sau `TabView { ... }` (trước `.task`):
```swift
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
```

- [ ] **Step 3: Thêm test chụp màn hình Onboarding và Cài đặt**

Thêm method sau vào class `ScreenshotTests`:
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

        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.switches.firstMatch.waitForExistence(timeout: 5))
        snap(app, "settings")
        app.switches.element(boundBy: 1).tap() // "Đặt ngày dự sinh"
        snap(app, "settings-due-date")

        app.tabBars.buttons.element(boundBy: 0).tap()
        snap(app, "counter-with-week")
    }
```

- [ ] **Step 4: Commit, push, xác minh trên CI**

```bash
git add App UITests
git commit -m "feat(app): add settings, medical info, onboarding and privacy manifest"
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, có thêm ảnh `onboarding-1/2/3`, `settings`, `settings-due-date`, `counter-with-week`.

Mở ảnh bằng Read tool và xác nhận:
- Onboarding: 3 trang có biểu tượng, tiêu đề và nội dung tiếng Việt. Trang 3 có nút "Tôi đã hiểu".
- `settings`: có các mục Nhắc hằng ngày, Thai kỳ, Quyền (hiện ra vì thông báo bị tắt trong `-uiTesting`) và Thông tin.
- `settings-due-date`: hiện ô chọn ngày dự sinh.
- `counter-with-week`: màn Đếm có dòng "Tuần 27 + 1 ngày". Ngày dự sinh mặc định là +90 ngày, tức 190 ngày = 27 tuần 1 ngày.

---

### Task 11: Live Activity (widget extension + AddKickIntent)

**Files:**
- Create: `Shared/KickActivityAttributes.swift`, `Shared/AddKickIntent.swift`
- Create: `App/SystemLiveActivityManager.swift`
- Create: `Widgets/KickCounterWidgetsBundle.swift`, `Widgets/KickLiveActivityWidget.swift`
- Modify: `App/AppEnvironment.swift`, `App/KickCounterApp.swift`, `project.yml`

**Interfaces:**
- Consumes: `LiveActivityManaging`, `KickCoordinator.recordKick()`, `SessionRules`, `L10n`
- Produces:
  - `struct KickActivityAttributes: ActivityAttributes { struct ContentState: Codable, Hashable { count: Int; completedAt: Date? }; sessionID: UUID; startedAt: Date }`
  - `@MainActor enum KickIntentBridge { static var recordKick: (@MainActor () async -> Void)? }`
  - `struct AddKickIntent: LiveActivityIntent`
  - `@MainActor final class SystemLiveActivityManager: LiveActivityManaging`

- [ ] **Step 1: Kiểu dùng chung**

`Shared/KickActivityAttributes.swift`:
```swift
import ActivityKit
import Foundation

struct KickActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var count: Int
        var completedAt: Date?
    }

    var sessionID: UUID
    var startedAt: Date
}
```

`Shared/AddKickIntent.swift`:
```swift
import AppIntents
import Foundation

/// Set by the app at launch. LiveActivityIntent.perform runs in the app's
/// process, so the handler is always present when the intent fires.
@MainActor
enum KickIntentBridge {
    static var recordKick: (@MainActor () async -> Void)?
}

struct AddKickIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.addKick.title"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await KickIntentBridge.recordKick?()
        return .result()
    }
}
```

- [ ] **Step 2: Triển khai ActivityKit trong app**

`App/SystemLiveActivityManager.swift`:
```swift
import ActivityKit
import Foundation
import KickCore
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "live-activity")

@MainActor
final class SystemLiveActivityManager: LiveActivityManaging {
    private var activities: [Activity<KickActivityAttributes>] {
        Activity<KickActivityAttributes>.activities
    }

    private var current: Activity<KickActivityAttributes>? {
        activities.first { $0.activityState == .active }
    }

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func hasActivity(for sessionID: UUID) -> Bool {
        activities.contains { $0.attributes.sessionID == sessionID && $0.activityState == .active }
    }

    func start(sessionID: UUID, startedAt: Date, count: Int) async {
        await endAll()
        let attributes = KickActivityAttributes(sessionID: sessionID, startedAt: startedAt)
        let content = ActivityContent(
            state: KickActivityAttributes.ContentState(count: count, completedAt: nil),
            staleDate: startedAt.addingTimeInterval(SessionRules.overdueThreshold)
        )
        do {
            _ = try Activity.request(attributes: attributes, content: content)
        } catch {
            logger.error("Starting Live Activity failed: \(error.localizedDescription)")
        }
    }

    func update(count: Int, completedAt: Date?) async {
        guard let activity = current else { return }
        let staleDate = completedAt == nil
            ? activity.attributes.startedAt.addingTimeInterval(SessionRules.overdueThreshold)
            : nil
        await activity.update(ActivityContent(
            state: KickActivityAttributes.ContentState(count: count, completedAt: completedAt),
            staleDate: staleDate
        ))
    }

    func end(dismissAfter: TimeInterval) async {
        guard let activity = current else { return }
        let policy: ActivityUIDismissalPolicy = dismissAfter <= 0
            ? .immediate
            : .after(Date.now.addingTimeInterval(dismissAfter))
        await activity.end(activity.content, dismissalPolicy: policy)
    }

    func endAll() async {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
```

Trong `App/AppEnvironment.swift` thay dòng:
```swift
        let liveActivities: LiveActivityManaging = NoopLiveActivityManager() // replaced in Task 11
```
bằng:
```swift
        let liveActivities: LiveActivityManaging = isUITesting ? NoopLiveActivityManager() : SystemLiveActivityManager()
```

Trong `App/KickCounterApp.swift` thay khối `init()` bằng:
```swift
    init() {
        environment = Result { try AppEnvironment.make() }
        switch environment {
        case .success(let env):
            let coordinator = env.coordinator
            KickIntentBridge.recordKick = { _ = await coordinator.recordKick() }
        case .failure(let error):
            logger.fault("Could not open the data store: \(error.localizedDescription)")
        }
    }
```

- [ ] **Step 3: Widget extension**

`Widgets/KickCounterWidgetsBundle.swift`:
```swift
import SwiftUI
import WidgetKit

@main
struct KickCounterWidgetsBundle: WidgetBundle {
    var body: some Widget {
        KickLiveActivityWidget()
    }
}
```

`Widgets/KickLiveActivityWidget.swift`:
```swift
import ActivityKit
import AppIntents
import KickCore
import SwiftUI
import WidgetKit

struct KickLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KickActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CountLabel(state: context.state).font(.title2.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedLabel(attributes: context.attributes, state: context.state)
                        .font(.title3.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.isStale && context.state.completedAt == nil {
                        Text(L10n.laOverdue).font(.caption).foregroundStyle(.orange)
                    }
                    AddKickButton(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "heart.fill").foregroundStyle(Color.accentColor)
            } compactTrailing: {
                CountLabel(state: context.state)
            } minimal: {
                Text("\(context.state.count)").foregroundStyle(Color.accentColor)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<KickActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                CountLabel(state: context.state).font(.largeTitle.bold())
                ElapsedLabel(attributes: context.attributes, state: context.state)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if context.isStale && context.state.completedAt == nil {
                    Text(L10n.laOverdue).font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            AddKickButton(state: context.state)
        }
    }
}

private struct CountLabel: View {
    let state: KickActivityAttributes.ContentState

    var body: some View {
        Text("\(state.count)/\(SessionRules.targetCount)")
            .monospacedDigit()
            .foregroundStyle(Color.accentColor)
    }
}

private struct ElapsedLabel: View {
    let attributes: KickActivityAttributes
    let state: KickActivityAttributes.ContentState

    var body: some View {
        if let completedAt = state.completedAt {
            Text(L10n.laCompleted + " " + Duration.seconds(completedAt.timeIntervalSince(attributes.startedAt).rounded())
                .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)))
        } else {
            Text(timerInterval: attributes.startedAt...Date.distantFuture, countsDown: false)
        }
    }
}

private struct AddKickButton: View {
    let state: KickActivityAttributes.ContentState

    var body: some View {
        if state.completedAt == nil {
            Button(intent: AddKickIntent()) {
                Text(L10n.laAdd)
                    .font(.title.bold())
                    .frame(minWidth: 64, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(.accentColor)
            .accessibilityLabel(L10n.counterA11yButton)
        }
    }
}
```

- [ ] **Step 4: Cập nhật project.yml**

Thay toàn bộ `project.yml` bằng:
```yaml
name: KickCounter
options:
  bundleIdPrefix: com.lmtiep
  deploymentTarget:
    iOS: "17.0"
  developmentLanguage: en
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    LOCALIZATION_PREFERS_STRING_CATALOGS: YES
    SWIFT_EMIT_LOC_STRINGS: YES
packages:
  KickCore:
    path: Packages/KickCore
  KickData:
    path: Packages/KickData
targets:
  KickCounter:
    type: application
    platform: iOS
    sources:
      - App
      - Shared
    dependencies:
      - package: KickCore
      - package: KickData
      - target: KickCounterWidgets
    info:
      path: App/Info.plist
      properties:
        CFBundleDisplayName: Kick Counter
        CFBundleLocalizations: [en, vi]
        UILaunchScreen: {}
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
        ITSAppUsesNonExemptEncryption: false
        NSSupportsLiveActivities: true
        UIBackgroundModes: [remote-notification]
    entitlements:
      path: App/KickCounter.entitlements
      properties:
        com.apple.security.application-groups: [group.com.lmtiep.kickcounter]
        com.apple.developer.icloud-container-identifiers: [iCloud.com.lmtiep.kickcounter]
        com.apple.developer.icloud-services: [CloudKit]
        aps-environment: development
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lmtiep.kickcounter
        TARGETED_DEVICE_FAMILY: "1"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
  KickCounterWidgets:
    type: app-extension
    platform: iOS
    sources:
      - Widgets
      - Shared
      - path: App/Assets.xcassets
        buildPhase: resources
    dependencies:
      - package: KickCore
      - sdk: SwiftUI.framework
      - sdk: WidgetKit.framework
    info:
      path: Widgets/Info.plist
      properties:
        CFBundleDisplayName: Kick Counter
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    entitlements:
      path: Widgets/KickCounterWidgets.entitlements
      properties:
        com.apple.security.application-groups: [group.com.lmtiep.kickcounter]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lmtiep.kickcounter.widgets
        TARGETED_DEVICE_FAMILY: "1"
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
  KickCounterUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - UITests
    dependencies:
      - target: KickCounter
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lmtiep.kickcounter.uitests
schemes:
  KickCounter:
    build:
      targets:
        KickCounter: all
        KickCounterUITests: [test]
    test:
      targets:
        - KickCounterUITests
```
Thêm vào `.gitignore` (file entitlements do XcodeGen sinh ra):
```
App/KickCounter.entitlements
Widgets/KickCounterWidgets.entitlements
```

- [ ] **Step 5: Commit, push, xác minh trên CI**

```bash
git add Shared App Widgets project.yml .gitignore
git commit -m "feat: add Live Activity with lock screen +1 button via LiveActivityIntent"
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`. App và extension build được, mọi test cũ vẫn xanh. CI chạy với `-uiTesting` (Live Activity tắt) nên không chụp được Live Activity. Phần này được kiểm trên iPhone thật qua TestFlight ở Task 14.

---

### Task 12: UI test chức năng cho luồng chính

**Files:**
- Create: `UITests/KickCounterUITests.swift` (target `KickCounterUITests` đã có từ Task 8, tự nhận file mới)

**Interfaces:**
- Consumes: accessibility identifiers trong Global Constraints; các launch argument `-uiTesting`, `-AppleLanguages`.

- [ ] **Step 1: Viết UI test**

`UITests/KickCounterUITests.swift`:
```swift
import XCTest

final class KickCounterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Fixed language so assertions can match the accessibility value text.
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        completeOnboarding()
    }

    private func completeOnboarding() {
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        next.tap()
        app.buttons["onboardingAgree"].tap()
    }

    private func tapKick(times: Int) {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 5))
        for _ in 0..<times {
            kick.tap()
            Thread.sleep(forTimeInterval: 0.6) // stay above the 0.5 s debounce
        }
    }

    /// Accessibility value of the kick button, e.g. "2 of 10 movements".
    private var kickValue: String? {
        app.buttons["kickButton"].value as? String
    }

    @MainActor
    func testCountingTenMovementsShowsCompletionAndHistory() {
        tapKick(times: 10)

        XCTAssertTrue(app.staticTexts["completionTitle"].waitForExistence(timeout: 5))
        app.buttons["completionDone"].tap()

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["sessionRow"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testUndoRemovesLastMovement() {
        tapKick(times: 3)
        app.buttons["undoButton"].tap()
        XCTAssertEqual(kickValue, "2 of 10 movements")
    }

    @MainActor
    func testCancelResetsCounter() {
        tapKick(times: 2)
        app.buttons["cancelSessionButton"].tap()
        let confirm = app.sheets.buttons["Cancel session"]
        if confirm.waitForExistence(timeout: 2) {
            confirm.tap()
        } else {
            // Newer iOS versions may render the dialog as a popover rather than a sheet.
            app.buttons.matching(identifier: "Cancel session").element(boundBy: 1).tap()
        }
        XCTAssertEqual(kickValue, "0 of 10 movements")
    }

    @MainActor
    func testDebounceIgnoresAccidentalDoubleTap() {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 5))
        kick.doubleTap()
        XCTAssertEqual(kickValue, "1 of 10 movements")
    }
}
```

Nếu cách dialog hiển thị trên phiên bản iOS của runner làm selector không khớp, hãy chỉnh selector. Không được xóa hay nới lỏng assertion.

- [ ] **Step 2: Commit, push, CI**

```bash
git add UITests
git commit -m "test: add functional UI tests for count, undo, cancel and debounce"
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`. Log có `** TEST SUCCEEDED **`. Nếu fail, đọc `ci-artifacts/xcresult` và log, sau đó dùng `superpowers:systematic-debugging`.

---

### Task 13: Phát hành TestFlight từ GitHub Actions

**Điều kiện:** Task 0 đã xong, kể cả Step 4 (secrets). Kiểm tra bằng `gh secret list && gh variable list`. Nếu thiếu, dừng lại và nhờ người dùng hoàn tất.

**Files:**
- Create: `scripts/release.sh`, `.github/workflows/testflight.yml`

**Interfaces:**
- Consumes: secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`; variable `DEVELOPMENT_TEAM`; `project.yml`.
- Produces: workflow `testflight.yml` (chạy tay). Mỗi lần chạy đẩy build số `github.run_number` lên TestFlight.

- [ ] **Step 1: Script release**

`scripts/release.sh`:
```bash
#!/usr/bin/env bash
# Archives the app and uploads it to App Store Connect (TestFlight).
# Runs on GitHub Actions; uses cloud-managed signing via an App Store Connect API key.
set -euo pipefail
: "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${DEVELOPMENT_TEAM:?}" "${BUILD_NUMBER:?}"
cd "$(dirname "$0")/.."

KEY_PATH="$HOME/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[[ -f "$KEY_PATH" ]] || { echo "Missing API key at $KEY_PATH" >&2; exit 1; }
AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

xcodegen generate --quiet
rm -rf build && mkdir -p build

xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -configuration Release -destination "generic/platform=iOS" \
  -archivePath build/KickCounter.xcarchive \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  "${AUTH[@]}" archive

cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>teamID</key><string>${DEVELOPMENT_TEAM}</string>
    <key>signingStyle</key><string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath build/KickCounter.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  "${AUTH[@]}"
echo "==> Uploaded build $BUILD_NUMBER to App Store Connect"
```

`.github/workflows/testflight.yml`:
```yaml
name: TestFlight
on:
  workflow_dispatch:
concurrency:
  group: testflight
  cancel-in-progress: false
jobs:
  release:
    runs-on: macos-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - name: Select latest stable Xcode
        run: |
          XCODE="$(ls -d /Applications/Xcode_*.app | grep -vi beta | sort -V | tail -1)"
          sudo xcode-select -s "$XCODE/Contents/Developer"
          xcodebuild -version
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Install App Store Connect API key
        env:
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_KEY_P8_BASE64: ${{ secrets.ASC_KEY_P8_BASE64 }}
        run: |
          mkdir -p ~/private_keys
          echo "$ASC_KEY_P8_BASE64" | base64 --decode > ~/private_keys/AuthKey_${ASC_KEY_ID}.p8
      - name: Archive and upload
        env:
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          DEVELOPMENT_TEAM: ${{ vars.DEVELOPMENT_TEAM }}
          BUILD_NUMBER: ${{ github.run_number }}
        run: scripts/release.sh
      - name: Remove API key
        if: always()
        run: rm -rf ~/private_keys
```

- [ ] **Step 2: Commit, push, CI**

```bash
chmod +x scripts/release.sh
git add scripts/release.sh .github/workflows/testflight.yml
git commit -m "ci: add TestFlight release workflow with cloud-managed signing"
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

- [ ] **Step 3: Chạy release. HỎI NGƯỜI DÙNG XÁC NHẬN TRƯỚC**, vì bước này tải bản build lên App Store Connect của họ.

```bash
gh workflow run testflight.yml
sleep 10
gh run watch "$(gh run list --workflow testflight.yml --limit 1 --json databaseId -q '.[0].databaseId')" --exit-status
```
Expected: log có `==> Uploaded build <n> to App Store Connect`. Khoảng 10–30 phút sau, build xuất hiện trong App Store Connect → TestFlight ở trạng thái "Processing", rồi chuyển sang "Ready to Test".

Các lỗi thường gặp:
- `No profiles for 'com.lmtiep.kickcounter' were found`: API key không có quyền Admin, hoặc App ID chưa bật đủ capability như Task 0 Step 1.
- Lỗi iCloud container / App Group: container hoặc group chưa được gán vào App ID.
- `Missing Compliance`: đã khai `ITSAppUsesNonExemptEncryption: false` trong Info.plist, nên không cần làm gì thêm.

- [ ] **Step 4: Nhờ người dùng cài TestFlight** trên iPhone. Trong App Store Connect → TestFlight → Internal Testing, thêm Apple ID của người dùng. Sau đó chuyển sang Task 14.

---

### Task 14: Kiểm thử trên máy thật + checklist phát hành

**Files:**
- Create: `docs/release-checklist.md`

- [ ] **Step 1: Viết checklist**

`docs/release-checklist.md`:
```markdown
# Checklist trước khi phát hành

## Cấu hình (một lần)
- [ ] Task 0 đã xong: identifiers, app record, API key (Admin), secrets trên GitHub.
- [ ] CloudKit Console (icloud.developer.apple.com): sau khi bản TestFlight đầu tiên đã lưu dữ liệu,
      **Deploy Schema Changes** từ Development lên Production.
- [ ] Icon 1024×1024 trong `App/Assets.xcassets/AppIcon.appiconset` (không trong suốt, không bo góc).

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
- [ ] Chế độ tối, Dynamic Type lớn nhất, VoiceOver đọc "Ghi nhận cử động, đã có n trên 10 cử động".

## App Store Connect
- [ ] Danh mục: Health & Fitness.
- [ ] App Privacy: "Data Not Collected".
- [ ] Mô tả có câu miễn trừ y tế (dùng nội dung `medical.body`).
- [ ] Ảnh chụp màn hình vi + en: lấy từ `ci-artifacts/screenshots/` hoặc chụp trên máy thật.
- [ ] Ghi chú cho reviewer: cách thử Live Activity (chạm một lần trong app rồi khóa máy).
```

- [ ] **Step 2: Commit, push, CI**

```bash
git add docs/release-checklist.md
git commit -m "docs: add device test and App Store release checklist"
git push
scripts/ci-wait.sh
```

- [ ] **Step 3: Người dùng kiểm thử trên iPhone qua TestFlight** theo phần "Kiểm thử thủ công". Mục nào lỗi thì mở task sửa riêng (dùng `superpowers:systematic-debugging`), rồi phát hành bản TestFlight mới bằng Task 13 Step 3.

---

## Spec coverage (self-review)

| Spec | Task |
|---|---|
| §1 Đếm đến 10, cảnh báo 2 giờ | 2, 5, 6, 8 |
| §1 Nút +1 trên màn hình khóa | 11 |
| §3.1 Onboarding 3 trang + miễn trừ | 10 |
| §3.2 Nút lớn, vòng tiến độ, đồng hồ, haptic, hoàn tác, hủy, màn hoàn thành, banner 2 giờ | 8 |
| §3.3 Biểu đồ 14 ngày + đường 2 giờ, danh sách theo ngày, vuốt xóa | 4, 9 |
| §3.4 Nhắc hằng ngày (mặc định 20:00), ngày dự sinh/tuần thai, thông tin y tế, trạng thái quyền | 3 (khóa cài đặt), 4, 10 |
| §4.1 Tách lớp logic / lưu trữ / UI | 3 (KickCore ↔ KickData qua `SessionRepository`) |
| §4.2 Model tương thích CloudKit | 3 |
| §4.3 SessionEngine (debounce 0,5 giây, không undo sau completed) | 2, 12 |
| §4.4 Bất biến một session active | 3 |
| §4.5 Luồng Live Activity, `Text(timerInterval:)`, đồng bộ lại khi mở app, kết thúc sau 15 phút | 6, 11 |
| §4.6 Thông báo nhắc + cảnh báo 2 giờ, xin quyền đúng lúc | 5, 6, 10 |
| §5 Xử lý lỗi | 3 (iCloud/local), 6 (failure), 8 (StoreErrorView, alert), 10 (quyền), 11 (Live Activity tắt) |
| §6 Trợ năng, chế độ tối | 8–10 (ảnh chụp sáng/tối trên CI), 14 |
| §7 Song ngữ | 7, ảnh chụp vi/en ở 8–10 |
| §8 Unit test, UI test, kiểm thử thủ công, pre-push | 1–6, 8, 12, 14 |
| §8a Build không cần Xcode local (CI + TestFlight) | 1, 13 |
| §9 App Store, privacy | 10 (PrivacyInfo), 13, 14 |
