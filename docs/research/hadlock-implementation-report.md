# Hadlock fetal growth — implementation report

Date: 2026-10-03. Branch `fix/hadlock-fetal-growth`. Status: **done, CI green** (not merged).

## Commits
- `296139f` fix(content): use Hadlock fetal weight with range and CRL
- `5795c63` fix(app): keep the weight range on one line when the card text wraps

## Changes
- **Model** (`PregnancyContent.swift`): `lengthCm`/`weightG: Double?` replaced by `crlMm: Double?`, `weightG`/`weightP10G`/`weightP90G: Int?`. Added `WeekContent.weightStandardLastWeek = 40` and `weightBeyondStandard` (true for weeks 41–42 with a weight).
- **Validator** (`ContentValidator.swift`): `supportedVersion = 2`; `weightWeeks = 10...42`, `crlWeeks = 7...13` replace `measurementsRequiredFromWeek`. New issues `unexpectedMeasurement` (value outside its window) and `invalidWeightRange` (not p10 ≤ p50 ≤ p90). Weights must be non-decreasing; CRL must strictly increase.
- **JSON** (`pregnancy-content.json`): version 2; Hadlock 1991 Table 1 P10/P50/P90 for weeks 10–40, with week-40 values reused at weeks 41–42; Hadlock 1992 CRL for weeks 7–13; `lengthCm` removed; both §4.3 citations added to `sources`. All `reviewed: false` are unchanged.
- **Size comparisons**: week 10 chestnut → 🍋 lime / quả chanh ta; week 11 strawberry → 🧄 bulb of garlic / củ tỏi; week 28 eggplant → 🍊 pomelo / quả bưởi; 🎃 → 🍈 at weeks 35, 38 and 41 (names kept).
- **UI** (`PregnancyCards.swift` BabySizeCard, used by home and week detail; `Formatting.swift`): CRL row "Chiều dài đầu–mông / Crown–rump length" in mm (weeks 7–13). Weight shown as "Khoảng X (thường A–B)" / "About X (typically A–B)": kg from 1,000 g, range in the 50th-percentile value's unit, and the range kept on one line. Caption note on the ±10–15% ultrasound estimate wherever a weight is shown. Weeks 41–42 add the caption "Hadlock's standard ends at week 40". No length row from week 14. VoiceOver reads the card once (combined), with units spelled out ("About 58 grams, typically 48 to 68 grams").
- **Strings** (via `scripts/add-strings.py`, en + vi): added `pregnancy.baby.crl`, `.weightValue`, `.weightValue.a11y`, `.estimateNote`, `.standardEnds`; removed `pregnancy.baby.length`.
- **UI tests**: new `testWeek12DetailScreens` (vi + en). It checks that the en card label contains "Crown–rump length", "53.5" and "typically 48 to 68". `testPastDueScreen` now checks the week-41 card for "Hadlock's standard ends at week 40".
- **Docs**: `content-review-for-doctor.md` gets item 21, asking the doctor to confirm the Hadlock figures and the "thường A–B" wording. Item 19 now notes that 🎃 was replaced.

## TDD evidence
1. Tests written first (validator, library and bundled tests; fixture moved to schema v2, weeks 7–11). The first run failed to compile because `crlMm`, `weightP10G`, `unexpectedMeasurement` and the other new names did not exist.
2. Next, model fields and enum cases were added with no new validation, and the bundled JSON was still the old one. Result: `Test run with 170 tests in 17 suites failed … with 131 issues`. 17 tests failed, among them `fixtureIsValid`, `weightIsRequiredFromWeek10AndAbsentBefore`, `weightPercentilesMustBeOrdered`, `crownRumpLengthMustStrictlyIncrease`, `versionAndSourcesAreChecked`, `bundledContentPassesValidation`, `keyWeightsEqualHadlockTable1`, `everyWeightMatchesHadlock1991`, `crownRumpLengthsMatchHadlock1992`, `weeks41And42ReuseWeek40`, `sourcesCiteHadlock` and `noJackOLanternEmoji`.
3. With the validator implemented, only the bundled-content tests (old JSON) still failed. With the JSON updated: `✔ Test run with 170 tests in 17 suites passed`. The pre-push hook re-ran these tests on both pushes, and they passed both times.

Bundled tests pin the full Hadlock 1991 Table 1 (P10/P50/P90, weeks 10–40), the exact values 331 / 670 / 1210 / 3619 and CRL 53.5, and the Hadlock-anchored ranges from the brief.

## CI
- Run 1 (`296139f`): CI PASSED — https://github.com/lmtiep/kick-counter/actions/runs/37113052775
- Run 2 (`5795c63`): CI PASSED — https://github.com/lmtiep/kick-counter/actions/runs/37114187475
No reruns were needed.

## Screenshot observations
- pregnancy-home-12 vi/en (light/dark): kiwi; "Chiều dài đầu–mông 53,5 mm" / "Crown–rump length 53.5 mm"; "Khoảng 58 g (thường 48–68 g)" / "About 58 g (typically 48–68 g)"; the 10–15% note is shown. Dark mode reads well.
- week-12 vi detail: same card, with a "Tuần hiện tại" pill and no disclosure chevron.
- pregnancy-home-24 vi/en: corn; weight only, no length row. "Khoảng 670 g (thường 556–784 g)". In run 1 the line broke inside the range ("556–" / "784 g"). After the fix in run 2 it breaks before the range ("(thường" / "556–784 g)").
- week-24-en detail: "About 670 g (typically 556–784 g)" on one line, note shown.
- pregnancy-home-38 vi (light/dark): 🍈 "một quả bí đỏ", "Khoảng 3,24 kg (thường 2,69–3,79 kg)", range unbroken after the fix.
- pregnancy-home-pastdue-en (week 41): 🍈 "a large pumpkin", "About 3.62 kg (typically 3–4.23 kg)", then "Hadlock's standard ends at week 40" above the 10–15% note.
- medical-sources: both Hadlock citations are listed after the four guideline bodies.

## Week table (bundled data)
| Week | Weight P50 (P10–P90) g | CRL mm | Size comparison (en / vi) |
|---|---|---|---|
| 4 | — | — | 🌱 a poppy seed / một hạt anh túc |
| 5 | — | — | 🌱 a sesame seed / một hạt vừng |
| 6 | — | — | 🫘 a mung bean / một hạt đậu xanh |
| 7 | — | 9.6 | 🫐 a blueberry / một quả việt quất |
| 8 | — | 16.0 | 🍒 a cherry / một quả anh đào |
| 9 | — | 23.1 | 🍇 a grape / một quả nho |
| 10 | 35 (29–41) | 31.3 | 🍋 a lime / một quả chanh ta |
| 11 | 45 (37–53) | 41.2 | 🧄 a bulb of garlic / một củ tỏi |
| 12 | 58 (48–68) | 53.5 | 🥝 a kiwi / một quả kiwi |
| 13 | 73 (61–85) | 67.2 | 🍋 a lemon / một quả chanh vàng |
| 14 | 93 (77–109) | — | 🍑 a peach / một quả đào |
| 15 | 117 (97–137) | — | 🍎 an apple / một quả táo |
| 16 | 146 (121–171) | — | 🥑 an avocado / một quả bơ |
| 17 | 181 (150–212) | — | 🍐 a pear / một quả lê |
| 18 | 223 (185–261) | — | 🫑 a bell pepper / một quả ớt chuông |
| 19 | 273 (227–319) | — | 🥭 a mango / một quả xoài |
| 20 | 331 (275–387) | — | 🍌 a banana / một quả chuối |
| 21 | 399 (331–467) | — | 🥕 a carrot / một củ cà rốt |
| 22 | 478 (398–559) | — | 🥒 a cucumber / một quả dưa chuột |
| 23 | 568 (471–665) | — | 🍠 a large sweet potato / một củ khoai lang to |
| 24 | 670 (556–784) | — | 🌽 an ear of corn / một bắp ngô |
| 25 | 785 (652–918) | — | 🥦 a head of broccoli / một cây súp lơ xanh |
| 26 | 913 (758–1,068) | — | 🥬 a head of lettuce / một cây xà lách |
| 27 | 1,055 (876–1,234) | — | 🥬 a head of napa cabbage / một cây cải thảo |
| 28 | 1,210 (1,004–1,416) | — | 🍊 a pomelo / một quả bưởi |
| 29 | 1,379 (1,145–1,613) | — | 🥥 a coconut / một quả dừa |
| 30 | 1,559 (1,294–1,824) | — | 🥬 a head of cabbage / một bắp cải |
| 31 | 1,751 (1,453–2,049) | — | 🍈 a cantaloupe / một quả dưa lưới |
| 32 | 1,953 (1,621–2,285) | — | 🍌 a bunch of bananas / một nải chuối |
| 33 | 2,162 (1,794–2,530) | — | 🍍 a pineapple / một quả dứa |
| 34 | 2,377 (1,973–2,781) | — | 🍈 a large cantaloupe / một quả dưa lưới to |
| 35 | 2,595 (2,154–3,036) | — | 🍈 a small pumpkin / một quả bí đỏ nhỏ |
| 36 | 2,813 (2,335–3,291) | — | 🥥 a pair of coconuts / hai quả dừa |
| 37 | 3,028 (2,513–3,543) | — | 🍍 a pair of pineapples / hai quả dứa |
| 38 | 3,236 (2,686–3,786) | — | 🍈 a pumpkin / một quả bí đỏ |
| 39 | 3,435 (2,851–4,019) | — | 🥬 a large head of cabbage / một bắp cải lớn |
| 40 | 3,619 (3,004–4,234) | — | 🍉 a small watermelon / một quả dưa hấu nhỏ |
| 41 | 3,619 (3,004–4,234) — week-40 values + caption | — | 🍈 a large pumpkin / một quả bí đỏ lớn |
| 42 | 3,619 (3,004–4,234) — week-40 values + caption | — | 🍉 a watermelon / một quả dưa hấu |

## Deviations
- Fixture extended from weeks 7–9 to 7–11 so it can test the weight rules, which only start at week 10.
- `decreasingMeasurement` is also used for CRL that does not strictly increase. No separate case was added; this is documented in the enum.
- Pumpkin names at 35/38/41 kept; only the emoji changed to 🍈 (a green melon).
- The week-41 detail screen was not screenshotted separately. The caption is verified on the past-due home screen.
- Brief example "About 331 g" uses grams. At ≥1,000 g the range is shown in kg with up to 2 decimals (e.g. "3–4.23 kg"), so the lower end can lose a trailing zero ("3" rather than "3.00").

## Concerns
- CRL values come from inverting the Hadlock 1992 equation (research §2.2, confidence medium-high). They are not from a published table, yet the source line in the app reads as if the paper gives them directly.
- Fruit weights are unverified everyday estimates. The new choices (lime, garlic bulb, pomelo) were mine and fit Hadlock weight only loosely. They also use stand-in emoji: 🍋 for lime, 🍊 for pomelo, 🍈 for pumpkin. The doctor should review them (doc item 21).
- The 10–15% note wording is a simplification of the SD of ±12.7% [S1]; it appears in doc item 21 for the doctor to confirm.
- Older planning docs (`docs/superpowers/plans|specs/2026-10-02-*`) still mention `lengthCm`; left unchanged as historical records.

## Review fixes (commit `fb18190`, on top of `5795c63`)

- **Size items match their emoji.** Week 10 🫚 a knob of ginger / một củ gừng (was lime 🍋). Week 28 🍍 a small pineapple / một quả dứa nhỏ (was pomelo 🍊). Week 35 🍈 a honeydew melon / một quả dưa lê. Week 38 🍉 a small watermelon / một quả dưa hấu nhỏ. Week 40 🍉 a medium watermelon / một quả dưa hấu vừa. Week 41 🍌 two bunches of bananas / hai nải chuối. Week 42 🍉 a large watermelon / một quả dưa hấu to. Pumpkin, pomelo and lime are gone, and all names stay unique. The new test `sizeEmojiDepictsTheItem` maps item keywords to the emoji allowed for them and rejects pumpkin, pomelo and lime.
- **CRL wording.** The Hadlock 1992 source now ends "— crown–rump length at weeks 7–13, calculated from this paper's regression equation." Sources are single-language strings in the JSON, so there is no separate Vietnamese line. The card shows "Khoảng 53,5 mm" / "About 53.5 mm", and VoiceOver reads "About 53.5 millimeters". New string key: `pregnancy.baby.crlValue`.
- **kg formatting.** Exactly one decimal for kg values and ranges, e.g. "About 3.6 kg (typically 3.0–4.2 kg)" and "Khoảng 3,2 kg (thường 2,7–3,8 kg)".
- **Caption.** "Hadlock's standard ends at week 40." / "Số liệu chuẩn Hadlock chỉ đến tuần 40." now end with a period.
- **L10n comment.** The comment on `pregnancyBabyEstimateNote` now describes ultrasound measurement error, as distinct from the 10th–90th population spread.
- **Tests added.** `sourceJSONHasNoLegacyLengthKey` reads the source JSON file; it passed from the start, since the key was already removed, so it acts as a regression guard. `crlSourceSaysValuesAreCalculated` and `sizeEmojiDepictsTheItem` both failed before the fix (1 issue and 5 issues). After the fix: `✔ Test run with 173 tests in 17 suites passed`. The UI test now checks for "About 53.5".
- **Doctor doc.** Items 19 and 21 updated (new size items, calculated-CRL note, "Khoảng 53,5 mm").
- **CI.** CI PASSED — https://github.com/lmtiep/kick-counter/actions/runs/37115415426 (no rerun).
- **Screenshots re-checked.**
  - week-12-vi: "Chiều dài đầu–mông / Khoảng 53,5 mm", "Khoảng 58 g (thường 48–68 g)".
  - home-24-en: "About 670 g (typically 556–784 g)", with the range on one line.
  - home-38-vi: 🍉 "một quả dưa hấu nhỏ", "Khoảng 3,2 kg (thường 2,7–3,8 kg)".
  - past-due week 41 (en): 🍌 "two bunches of bananas", "About 3.6 kg (typically 3.0–4.2 kg)", "Hadlock's standard ends at week 40.".
- **Remaining notes.**
  - 🍌 shows a single banana while the items are bunches (weeks 32 and 41). The same convention was already used at week 32.
  - In Vietnam, "dưa lê" often means a smaller melon than a Western honeydew. The doctor or product team should confirm the wording.
  - The fruit and vegetable weights are still unverified everyday estimates.

### Updated week table (sizes changed at 10, 28, 35, 38, 40, 41, 42; weights/CRL unchanged)
| Week | Size (en / vi) |
|---|---|
| 10 | 🫚 a knob of ginger / một củ gừng |
| 28 | 🍍 a small pineapple / một quả dứa nhỏ |
| 35 | 🍈 a honeydew melon / một quả dưa lê |
| 38 | 🍉 a small watermelon / một quả dưa hấu nhỏ |
| 40 | 🍉 a medium watermelon / một quả dưa hấu vừa |
| 41 | 🍌 two bunches of bananas / hai nải chuối |
| 42 | 🍉 a large watermelon / một quả dưa hấu to |
