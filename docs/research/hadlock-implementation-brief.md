# Brief: switch fetal size data to Hadlock (user-approved)

Branch `fix/hadlock-fetal-growth` (already checked out, from main). Research with every number and source: `docs/research/2026-10-03-hadlock-fetal-growth.md` (Hadlock 1991 Table 1 in §2.1, CRL values in §2.2/§4.2, citation text in §4.3, validator/test impacts in §4.4, fruit fit in §3.1). Use only numbers from that file.

## User decisions
1. **Weight:** weeks 10–40 show Hadlock 1991 50th percentile **with the 10th–90th range**, e.g. vi "Khoảng 331 g (thường 275–387 g)", en "About 331 g (typically 275–387 g)". Add a one-line note on the baby card / week detail: ultrasound estimates can differ by about 10–15% (vi + en).
   - Weeks 4–9: no weight.
   - Weeks 41–42: Hadlock's table stops at 40 weeks. Reuse the week-40 values (50th + 10th–90th) and show the extra caption "Số liệu chuẩn Hadlock chỉ đến tuần 40" / "Hadlock's standard ends at week 40".
2. **Length:** weeks 7–13 show Hadlock 1992 crown–rump length in **mm** (9.6 / 16.0 / 23.1 / 31.3 / 41.2 / 53.5 / 67.2), labelled "Chiều dài đầu–mông" / "Crown–rump length". From week 14 on, show **no length** (remove `lengthCm` everywhere). Weeks 4–6: no length.

## Changes
- **Model (KickCore `PregnancyContent`)**: replace `lengthCm` / `weightG` with optional `crlMm: Double?`, `weightG: Int?`, `weightP10G: Int?`, `weightP90G: Int?` (rename consistently; update decoding, JSON, fixture). Keep JSON schema `version` bump to 2.
- **JSON** `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`: set the new fields per the decisions for weeks 4–42; keep `reviewed: false`. Add both Hadlock citations from §4.3 to `sources`.
- **Size comparisons**: update the fruit/emoji where the research says it no longer fits Hadlock weight (at least weeks 10, 11, 28; check §3.1 for all). Pick common, Vietnam-familiar items; en/vi pairs; keep size comparisons unique (existing test); emoji must exist on iOS 17. Avoid 🎃 (jack-o'-lantern face) — use another pumpkin-like item or 🍈/🍉 etc.
- **Validator (`ContentValidator`) + tests**: per §4.4 — weight fields required for weeks 10–42 and absent before 10; p10 ≤ p50 ≤ p90; each non-decreasing by week; crlMm required weeks 7–13, absent otherwise, increasing. Replace typical-range checks with Hadlock-anchored ones (e.g. week 12 50th 48–68 g, week 20 300–360 g, week 28 1,004–1,416 g, week 40 3,400–3,800 g; CRL week 8 14–18 mm, week 12 50–57 mm). Add a test that the bundled week-20/24/28/40 50th values equal Hadlock Table 1 exactly (331 / 670 / 1210 / 3619) and week 12 CRL 53.5. TDD: write tests first, see them fail on the old JSON.
- **UI**: `App/Pregnancy/PregnancyCards.swift` (BabySizeCard) and `App/Pregnancy/WeekDetailView.swift` (and `App/Formatting.swift`): show weight "Khoảng X (thường A–B)" with kg formatting ≥1000 g as today; show CRL in mm only for weeks 7–13; no length row otherwise; the ±10–15% note; weeks 41–42 caption. VoiceOver labels updated (combined card reads weight + range once). New strings via `scripts/add-strings.py` (en + vi).
- **Medical info → Sources**: the two Hadlock citations appear (comes from JSON `sources`).
- **Docs**: add a line to `docs/content-review-for-doctor.md` asking the doctor to confirm the Hadlock-based figures and the range wording.

## Verification
`scripts/test-core.sh` green; push; `scripts/ci-wait.sh` → CI PASSED (known flake rule: if only `testCancelResetsCounter`-style waitForExistence timeouts on unrelated tests, `gh run rerun <id> --failed` once and watch that run). Visually check with the Read tool: pregnancy-home-12/24/38 (vi + en), week-24 detail, and add/inspect a week-8 or week-12 detail screenshot showing CRL in mm (extend PregnancyScreenshotTests if needed). Commit message: `fix(content): use Hadlock fetal weight with range and CRL`.
