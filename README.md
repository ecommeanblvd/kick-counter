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
