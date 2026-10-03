# Luna Mom — fetal size data vs Hadlock: research findings

Date: 2026-10-03. Read-only research; no repo files were changed.

## TL;DR

- **The user is right.** The app's week-by-week `weightG` / `lengthCm` are **not** Hadlock. They match, number for number, the widely copied "fetal growth chart" (8 wk 1.6 cm / 1 g ... 40 wk 51.2 cm / 3,462 g ... 42 wk 3,685 g) that is reproduced, **with no citation**, by consumer sites, e.g. Utah's *Baby Your Baby* chart [S6]. The original primary source of that chart could not be traced (**unverified**).
- **Weights are systematically low compared with Hadlock 1991's 50th percentile**: −89% at 10 wk, −76% at 12 wk, −32% at 16 wk, about −10% at 20–24 wk, −17% at 25–28 wk, −4% at 40 wk. From **10 to 17 weeks the app's "average" weight is below Hadlock's 10th percentile**. From 25 to 29 weeks it sits within about 1% of the 10th percentile, and week 27 is just below it (the 10th percentile is the cut-off SMFM uses to define fetal growth restriction [S5]). A mother whose ultrasound (Hadlock EFW, the default on the machines) shows a normal 50th-percentile baby will see a *heavier* baby than the app says is "average". That mismatch is a likely source of confusion.
- **Lengths are mixed.** For weeks 8–12 the app's numbers equal Hadlock 1992 CRL to within 1%. From week 13 they drift above it, and at 19→20 wk they switch silently from crown–rump (15.3 cm) to crown–heel (25.6 cm). There is a second unexplained jump at 24→25 wk (30.0 → 34.6 cm). **Hadlock publishes no crown–heel length standard.**
- **Recommendation:** use Hadlock 1991 Table 1 EFW (50th, with 10th–90th range) for weeks 10–40. Use Hadlock 1992 CRL for weeks 6/7–13. Show no Hadlock number before those weeks or after 40, and drop or relabel crown–heel length from week 14.

## 1. What the app currently has

Source file: `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json` (`weeks[].lengthCm`, `weeks[].weightG`, `weeks[].size.en`). The full values are in the comparison table in §3.

- Weeks 4–7: no length or weight (`null`). From week 8 on, both are present.
- `sources` lists only WHO ANC 2016, ACOG patient education, the NHS guide and Bộ Y tế national guidance. **None of these is a fetal biometry source**, and nothing cites where the numbers came from.
- Display: `App/Pregnancy/PregnancyCards.swift:61-62` shows one point value per week, via `Formatting.length(cm:)` (cm, 0–1 decimals) and `Formatting.weight(grams:)` (g below 1 kg, kg with 2 decimals above) in `App/Formatting.swift:14-32`. There is no range and no label saying what kind of length it is.
- Week semantics: `GestationalAge.week` returns completed weeks (`elapsed / 7`), so "week 20" means 20+0 to 20+6. Hadlock Table 1 rows are at exact menstrual weeks (N+0), so a Hadlock row N is the value at the *start* of the app's week N. That is conservative, and it matches how Vietnamese reports state "20 tuần 0 ngày".
- Validator (`ContentValidator.swift`): `measurementsRequiredFromWeek = 8` applies to **both** fields. It also checks for non-positive values and for decreasing week-on-week values.
- Test `BundledContentTests.measurementsAreInTypicalRanges` (lines 21–27): wk12 length 4.5–7 / weight 10–25; wk20 15–27 / 250–350; wk24 28–33 / 500–700; wk28 35–39 / 900–1200; wk40 48–54 / 3100–3700.
- Fixture `content-fixture.json` also uses week 8 = 1.6 cm / 1 g.

Provenance check: the *Baby Your Baby* chart [S6] lists exactly 8 wk 1.6/1, 12 wk 5.4/14, 16 wk 11.6/100, 24 wk 30/600, 28 wk 37.6/1005, 40 wk 51.2/3462, 41 wk 51.7/3597, 42 wk 51.5/3685. Its only differences from the app:
- It shows 20 wk as 16.4 cm, where the app has 25.6 cm (the "crown–heel from 20 weeks" variant).
- It shows 42 wk as 51.5 cm, where the app has 51.7 cm (probably edited to pass the validator's non-decreasing rule).
- It labels the whole table "crown to rump", although after 20 weeks its values are clearly crown–heel.

## 2. Hadlock — primary sources

### 2.1 EFW standard — Hadlock, Harrist & Martinez-Poyer, Radiology 1991;181:129–133 [S1]

Full text: the original PDF hosted by the University of Toronto Dept. of OB/GYN [S1], cross-checked against the regression equation.

- Population: 392 predominantly middle-class white women with certain menstrual dates.
- Model: `ln(EFW g) = 0.578 + 0.332·MA − 0.00354·MA²` (MA = menstrual age in weeks; R² = 99.1%).
- Spread: uniform SD of **±12.7%** of the predicted weight. Abstract: 35 g at 10 wk, rising to 3,619 g at 40 wk.
- **Table 1** gives the 3rd/10th/50th/90th/97th percentiles for weeks 10–40. Every 50th value below was recomputed from the equation and matches to the gram, which confirms the PDF text extraction.
- Two text-extraction glitches were corrected:
  - Week 31 50th reads "t751"; the equation gives **1,751**.
  - Week 30 97th reads "1,649"; the equation and the neighbouring rows give about **1,949**. Treat it as "1,949 (OCR-corrected)".
- **The table stops at 40 weeks.** Table 4 reports *observed* mean term birth weights in the study: 38 wk 3,234 g; 39 wk 3,469 g; 40 wk 3,598 g; 41 wk 3,686 g. There is no 42-week value ("ND").
- Usage today:
  - SMFM Consult #52 (2020) recommends population-based references "such as Hadlock" for EFW percentiles [S5].
  - In Vietnam, a 2024 study from Huế University Hospital states that the Hadlock 1991 reference "đang được sử dụng rộng rãi ở nhiều quốc gia, trong đó có Việt Nam" (is widely used in many countries, including Vietnam). It also says EFW was computed with "công thức Hadlock IV được cài sẵn trên máy siêu âm" (the Hadlock IV formula pre-installed on the ultrasound machine) [S7].

| Week | 3rd | 10th | 50th | 90th | 97th |
|---|---|---|---|---|---|
| 10 | 26 | 29 | 35 | 41 | 44 |
| 11 | 34 | 37 | 45 | 53 | 56 |
| 12 | 43 | 48 | 58 | 68 | 73 |
| 13 | 55 | 61 | 73 | 85 | 91 |
| 14 | 70 | 77 | 93 | 109 | 116 |
| 15 | 88 | 97 | 117 | 137 | 146 |
| 16 | 110 | 121 | 146 | 171 | 183 |
| 17 | 136 | 150 | 181 | 212 | 226 |
| 18 | 167 | 185 | 223 | 261 | 279 |
| 19 | 205 | 227 | 273 | 319 | 341 |
| 20 | 248 | 275 | 331 | 387 | 414 |
| 21 | 299 | 331 | 399 | 467 | 499 |
| 22 | 359 | 398 | 478 | 559 | 598 |
| 23 | 426 | 471 | 568 | 665 | 710 |
| 24 | 503 | 556 | 670 | 784 | 838 |
| 25 | 589 | 652 | 785 | 918 | 981 |
| 26 | 685 | 758 | 913 | 1,068 | 1,141 |
| 27 | 791 | 876 | 1,055 | 1,234 | 1,319 |
| 28 | 908 | 1,004 | 1,210 | 1,416 | 1,513 |
| 29 | 1,034 | 1,145 | 1,379 | 1,613 | 1,724 |
| 30 | 1,169 | 1,294 | 1,559 | 1,824 | 1,949 |
| 31 | 1,313 | 1,453 | 1,751 | 2,049 | 2,189 |
| 32 | 1,465 | 1,621 | 1,953 | 2,285 | 2,441 |
| 33 | 1,622 | 1,794 | 2,162 | 2,530 | 2,703 |
| 34 | 1,783 | 1,973 | 2,377 | 2,781 | 2,971 |
| 35 | 1,946 | 2,154 | 2,595 | 3,036 | 3,244 |
| 36 | 2,110 | 2,335 | 2,813 | 3,291 | 3,516 |
| 37 | 2,271 | 2,513 | 3,028 | 3,543 | 3,785 |
| 38 | 2,427 | 2,686 | 3,236 | 3,786 | 4,045 |
| 39 | 2,576 | 2,851 | 3,435 | 4,019 | 4,294 |
| 40 | 2,714 | 3,004 | 3,619 | 4,234 | 4,524 |

Source for every number in this table: [S1], Table 1. Week 30 97th is OCR-corrected as noted above.

### 2.2 CRL — Hadlock, Shah, Kanon & Lindsey, Radiology 1992;182:501–505 [S2]

- "Fetal crown-rump length: reevaluation of relation to menstrual age (5–18 weeks) with high-resolution real-time US". 416 patients; CRL measured from 2 mm to 12 cm.
- Equation, as recorded by LOINC 11910-7 [S3]: `ln(MA wk) = 1.684969 + 0.315646·CRL − 0.049306·CRL² + 0.004057·CRL³ − 0.000120456·CRL⁴` (CRL in cm). Its 95% CI is about ±8% of the predicted age.
- I inverted the equation numerically to get the CRL at each week+0. These are **derived values, not a published table**:

| Week+0 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 |
|---|---|---|---|---|---|---|---|---|---|
| CRL (mm) | 3.6 | 9.6 | 16.0 | 23.1 | 31.3 | 41.2 | 53.5 | 67.2 | 80.1 |

- At 5 wk the equation gives about 0 mm, which is outside its useful range.
- ACOG uses CRL for dating only up to 13 6/7 weeks (CRL 84 mm) [S4]. After that, CRL is no longer the clinical length measure.

### 2.3 Does Hadlock publish a fetal *length* (crown–heel) by week?

**No.** Hadlock's biometric standards cover:
- BPD, HC, AC and FL vs menstrual age (Radiology 1984;152:497–501 [S8]).
- EFW formulas from AC/FL/HC/BPD (Radiology 1984; AJOG 1985 [S8]).
- EFW percentiles (1991 [S1]) and CRL (1992 [S2]).

Crown–heel length cannot be measured on routine ultrasound. The crown–heel numbers in consumer charts come from postnatal or autopsy data, for example the Archie, Collins & Lebel 2006 regression standards for fetal autopsy [S9]. I did not retrieve that paper's tables, so **every crown–heel number is "unverified" here**. For orientation only, term newborn length is about 50 cm.

### 2.4 Newer references (context for Vietnam)

- **INTERGROWTH-21st** (multi-ethnic, 2014–2017) and the **WHO Fetal Growth Charts** (Kiserud et al., PLoS Med 2017;14:e1002220 [S10]) are the newer international alternatives.
- The Huế study found INTERGROWTH-21st to be about equivalent to Hadlock for diagnosing small-for-gestational-age babies, with higher specificity for adverse outcomes [S7].
- An earlier VJOG study (Ngô & Nguyễn 2020) found Hadlock more sensitive for screening small-for-gestational-age babies [S11].
- **Hadlock remains the de facto reference on Vietnamese ultrasound reports** [S7]. Aligning the app with Hadlock is therefore the most consistent choice for Vietnamese mothers.

## 3. Comparison table, weeks 4–42

- Δ = (app − Hadlock) / Hadlock.
- Hadlock weight is Table 1 of [S1].
- Hadlock CRL is derived from the [S2]/[S3] equation at week+0. The CRL values for weeks 14–18 are shown only for comparison, because they are past the CRL dating window [S4].
- App weights below Hadlock's 10th percentile: **weeks 10–17**. App weights within about 1.2% of the 10th percentile: **weeks 25–29**; week 27 (875 vs 876 g) is just below it.

| Wk | Fruit (en) | App weight g | Hadlock 50th g | Hadlock 10th–90th g | Δ weight | App length cm | Hadlock CRL cm (wk+0) | Δ length | Note |
|---|---|---|---|---|---|---|---|---|---|
| 4 | a poppy seed | — | n/a (<10 wk) | n/a | — | — | no Hadlock length | — | |
| 5 | a sesame seed | — | n/a (<10 wk) | n/a | — | — | no Hadlock length | — | |
| 6 | a mung bean | — | n/a (<10 wk) | n/a | — | — | 0.4 | — | |
| 7 | a blueberry | — | n/a (<10 wk) | n/a | — | — | 1.0 | — | |
| 8 | a cherry | 1 | n/a (<10 wk) | n/a | — | 1.6 | 1.6 | +0% | |
| 9 | a grape | 2 | n/a (<10 wk) | n/a | — | 2.3 | 2.3 | -0% | |
| 10 | a chestnut | 4 | 35 | 29–41 | -89% | 3.1 | 3.1 | -1% | |
| 11 | a strawberry | 7 | 45 | 37–53 | -84% | 4.1 | 4.1 | -1% | |
| 12 | a kiwi | 14 | 58 | 48–68 | -76% | 5.4 | 5.3 | +1% | |
| 13 | a lemon | 23 | 73 | 61–85 | -68% | 7.4 | 6.7 | +10% | |
| 14 | a peach | 43 | 93 | 77–109 | -54% | 8.7 | (8.0; beyond CRL dating window) | +9% | |
| 15 | an apple | 70 | 117 | 97–137 | -40% | 10.1 | (9.1; beyond CRL dating window) | +11% | |
| 16 | an avocado | 100 | 146 | 121–171 | -32% | 11.6 | (10.1; beyond CRL dating window) | +14% | |
| 17 | a pear | 140 | 181 | 150–212 | -23% | 13.0 | (11.1; beyond CRL dating window) | +17% | |
| 18 | a bell pepper | 190 | 223 | 185–261 | -15% | 14.2 | (12.0; beyond CRL dating window) | +18% | |
| 19 | a mango | 240 | 273 | 227–319 | -12% | 15.3 | no Hadlock length | — | |
| 20 | a banana | 300 | 331 | 275–387 | -9% | 25.6 | no Hadlock length | — | |
| 21 | a carrot | 360 | 399 | 331–467 | -10% | 26.7 | no Hadlock length | — | |
| 22 | a cucumber | 430 | 478 | 398–559 | -10% | 27.8 | no Hadlock length | — | |
| 23 | a large sweet potato | 501 | 568 | 471–665 | -12% | 28.9 | no Hadlock length | — | |
| 24 | an ear of corn | 600 | 670 | 556–784 | -10% | 30.0 | no Hadlock length | — | |
| 25 | a head of broccoli | 660 | 785 | 652–918 | -16% | 34.6 | no Hadlock length | — | |
| 26 | a head of lettuce | 760 | 913 | 758–1,068 | -17% | 35.6 | no Hadlock length | — | |
| 27 | a head of napa cabbage | 875 | 1,055 | 876–1,234 | -17% | 36.6 | no Hadlock length | — | |
| 28 | an eggplant | 1005 | 1,210 | 1,004–1,416 | -17% | 37.6 | no Hadlock length | — | |
| 29 | a coconut | 1153 | 1,379 | 1,145–1,613 | -16% | 38.6 | no Hadlock length | — | |
| 30 | a head of cabbage | 1319 | 1,559 | 1,294–1,824 | -15% | 39.9 | no Hadlock length | — | |
| 31 | a cantaloupe | 1502 | 1,751 | 1,453–2,049 | -14% | 41.1 | no Hadlock length | — | |
| 32 | a bunch of bananas | 1702 | 1,953 | 1,621–2,285 | -13% | 42.4 | no Hadlock length | — | |
| 33 | a pineapple | 1918 | 2,162 | 1,794–2,530 | -11% | 43.7 | no Hadlock length | — | |
| 34 | a large cantaloupe | 2146 | 2,377 | 1,973–2,781 | -10% | 45.0 | no Hadlock length | — | |
| 35 | a small pumpkin | 2383 | 2,595 | 2,154–3,036 | -8% | 46.2 | no Hadlock length | — | |
| 36 | a pair of coconuts | 2622 | 2,813 | 2,335–3,291 | -7% | 47.4 | no Hadlock length | — | |
| 37 | a pair of pineapples | 2859 | 3,028 | 2,513–3,543 | -6% | 48.6 | no Hadlock length | — | |
| 38 | a pumpkin | 3083 | 3,236 | 2,686–3,786 | -5% | 49.8 | no Hadlock length | — | |
| 39 | a large head of cabbage | 3288 | 3,435 | 2,851–4,019 | -4% | 50.7 | no Hadlock length | — | |
| 40 | a small watermelon | 3462 | 3,619 | 3,004–4,234 | -4% | 51.2 | no Hadlock length | — | |
| 41 | a large pumpkin | 3597 | n/a (table ends at 40; formula extrapolation 3,787 — not published) | n/a | — | 51.7 | no Hadlock length | — | |
| 42 | a watermelon | 3685 | n/a (formula extrapolation 3,934 — not published) | n/a | — | 51.7 | no Hadlock length | — | |

**Length artefacts in the current data:**
- 19→20 wk: 15.3 → 25.6 cm (+67% in one week), because the measure switches from CRL to crown–heel without any label.
- 24→25 wk: 30.0 → 34.6 cm, with no explanation.
- 41→42 wk: 51.7 = 51.7 (the source chart has 51.5 cm at 42 wk).

### 3.1 Size-comparison fit against Hadlock weight

Fruit and vegetable weights are approximate everyday values that I did not source (**unverified**). Comparisons like these are conventionally loose and partly length-based, so I flag only clear misfits.

| Week | Fruit | Hadlock 50th | Fit |
|---|---|---|---|
| 10 | chestnut (~10–20 g) | 35 g | **Too small.** Consider "a kumquat / small lime / fig". |
| 11 | strawberry (~15–25 g) | 45 g | **Too small.** Consider "a lime / fig". |
| 12–16 | kiwi, lemon, peach, apple, avocado | 58–146 g | OK. These fit Hadlock *better* than the app's current weights did. |
| 17–27 | pear … napa cabbage | 181–1,055 g | Mostly length-based. Acceptable. |
| 28 | eggplant (~300–500 g) | 1,210 g | **Too small by weight** (it was already a misfit at 1,005 g). Consider "a small coconut / head of cabbage". |
| 29–40 | coconut … small watermelon | 1.4–3.6 kg | Acceptable. |
| 41–42 | large pumpkin, watermelon | no Hadlock value | Fine as long as no Hadlock number is claimed. |

`BundledContentTests.sizeComparisonsAreDistinct` requires every fruit to be unique. Any rename must keep them distinct; "head of cabbage" is already used at week 30.

## 4. Recommendation

### 4.1 Weight (`weightG`)

- **Weeks 10–40:** replace with Hadlock 1991 Table 1, 50th percentile (§2.1).
- **Range:** add `weightP10G` / `weightP90G` with the Table 1 10th and 90th values. Show it as, for example, "≈ 331 g (thường 275–387 g)" or "typically 275–387 g". This tells a mother whose ultrasound differs that a ±17% spread is normal, and it avoids implying that one number is "correct".
  - Suggested footnote: "Ultrasound weight estimates can differ from actual weight by about 10–15%. Your doctor interprets your own scan." The ±12.7% SD is from [S1].
  - Do **not** compute or show a percentile for the user's own scan. That is a clinical interpretation.
- **Weeks 4–9:** no weight. Hadlock starts at 10 weeks, and early-embryo weights in grams are not clinically meaningful.
- **Weeks 41–42:** no published Hadlock 50th. Choose one of:
  - **(a, preferred)** show no weight, or show the week-40 value labelled "at term, about 3.6 kg".
  - (b) use Hadlock's *observed* mean birth weight at 41 wk, 3,686 g (Table 4 [S1]). Label it as such and keep 42 wk equal to it. **Do not** use the formula extrapolation (3,787 / 3,934 g), which is not published.

### 4.2 Length (`lengthCm`)

- **Weeks 7–13:** CRL (chiều dài đầu–mông) from the Hadlock 1992 equation, shown in **mm** with the label "crown–rump length (CRL)". This is exactly what the first-trimester Vietnamese scan report shows.
  - Values: wk7 9.6, wk8 16.0, wk9 23.1, wk10 31.3, wk11 41.2, wk12 53.5, wk13 67.2 mm.
  - Wk6 3.6 mm is optional; it is near the equation's lower limit.
  - These are derived from the equation in [S2]/[S3], not from a published table.
- **Weeks 4–6:** no length. Optionally show the text "Phôi/thai còn rất nhỏ, chưa đo được ổn định" (the embryo is still too small to measure reliably).
- **Weeks 14–42:** Hadlock has no length standard. Choose one of:
  - **(a, preferred)** drop length and show weight only. Optionally add one line noting that ultrasound now measures head (BPD/HC), abdomen (AC) and thigh bone (FL) instead of total length.
  - (b) keep an approximate crown–heel length, labelled "≈ chiều dài đầu–gót (ước lượng)" (approximate crown–heel length). Cite it as a non-Hadlock, approximate reference, fix the 24→25 jump, and never call it Hadlock. The current numbers' provenance is **unverified**, so option (a) is safer.

### 4.3 Citation text to add to `sources`

- Hadlock FP, Harrist RB, Martinez-Poyer J. In utero analysis of fetal growth: a sonographic weight standard. Radiology. 1991;181(1):129–133. doi:10.1148/radiology.181.1.1887021 — estimated fetal weight, 10th/50th/90th percentiles, weeks 10–40.
- Hadlock FP, Shah YP, Kanon DJ, Lindsey JV. Fetal crown-rump length: reevaluation of relation to menstrual age (5–18 weeks) with high-resolution real-time US. Radiology. 1992;182(2):501–505. doi:10.1148/radiology.182.2.1732970 — crown–rump length, weeks 7–13.

**Vietnamese UI wording:**
- "Cân nặng ước tính theo Hadlock (1991) – bách phân vị 50, khoảng bình thường bách phân vị 10–90" (estimated weight per Hadlock 1991: 50th percentile, normal range 10th–90th).
- "Chiều dài đầu–mông theo Hadlock (1992)" (crown–rump length per Hadlock 1992).

The test `sourcesNameTheFourGuidelineBodies` only checks that the four existing bodies are present, so adding entries keeps it passing.

### 4.4 Validator and test impacts

- `ContentValidator.measurementsRequiredFromWeek = 8` is shared by both fields. Split it per field:
  - weight from 10 (Hadlock starts at 10 wk),
  - length (CRL) from 7, *ending* at 13 if option 4.2(a) is chosen.
  - Otherwise `missingMeasurement` will fire for weeks 8–9 (weight) and for weeks ≥14 (length).
- If you add `weightP10G` / `weightP90G`, validate p10 ≤ p50 ≤ p90, with each field non-decreasing.
- The non-decreasing rule is satisfied by Hadlock (it rises monotonically). Weeks 41–42 need either a nil weight, which the validator must then allow after 40, or a value ≥ 3,619.
- `typicalMeasurements` changes:
  - **wk12 weight 10–25 → fails** (Hadlock 58). Change to e.g. 48–68 (Hadlock 10th–90th).
  - **wk12 length 4.5–7 cm** passes if it stays in cm (5.35). If length moves to mm, or to a new `crlMm` field, update it to e.g. 45–62 mm.
  - **wk20 weight 250–350** passes (331).
  - **wk20 length 15–27** fails under option (a) (nil). Remove it or make it conditional.
  - **wk24 weight 500–700** passes (670). wk24 length, same as wk20.
  - **wk28 weight 900–1200 → fails** (Hadlock 1,210). Change to 1,004–1,416.
  - **wk40 weight 3100–3700** passes (3,619). Better to use 3,004–4,234.
  - Lengths at wk28/40: drop them under option (a).
- `WeeklyContentLibraryTests` expects `content(forWeek: 8)?.weightG == 1`, and `ContentValidatorTests` / `content-fixture.json` use 8 wk = 1.6 cm / 1 g. Update the fixture and these expectations, or make the fixture independent of real data.
- Consider adding a test pinning a few exact Hadlock values (10 → 35, 20 → 331, 28 → 1,210, 40 → 3,619) so future edits can't drift away from the cited source.

## 5. Confidence

- **High** that the current data is not Hadlock and matches the uncited consumer chart: there is an exact match with [S6], and the weights differ from Hadlock at every week.
- **High** for the Hadlock 1991 values: taken from the original paper and verified against its own regression equation.
- **Medium-high** for the CRL values: the equation is from LOINC/secondary sources [S3] and I inverted it myself. I could not open the original 1992 paper (PubMed was blocked).
- **Low / unverified:** the original source of the consumer chart, any crown–heel numbers, and the fruit weights.

## Sources

- [S1] Hadlock FP, Harrist RB, Martinez-Poyer J. Radiology 1991;181:129–133. Full text: https://obgyn.utoronto.ca/sites/default/files/Hadlock%20Growth%20Chart-Radiology-1991.pdf (journal: https://pubs.rsna.org/doi/10.1148/radiology.181.1.1887021).
- [S2] Hadlock FP et al. Radiology 1992;182:501–505. https://pubmed.ncbi.nlm.nih.gov/1732970/ (abstract not retrievable here; title, population and range from search results).
- [S3] LOINC 11910-7, "Gestational age estimated from Crown rump length on US by Hadlock 1992 method" (formula): https://loinc.org/11910-7/ and https://www.findacode.com/loinc/11910-7--gestational-age-estimated-from-crown-rump-length-on-us-by-hadlock-1992-method.html
- [S4] ACOG Committee Opinion 700, Methods for Estimating the Due Date (CRL dating up to 13 6/7 wk / 84 mm): https://www.acog.org/clinical/clinical-guidance/committee-opinion/articles/2017/05/methods-for-estimating-the-due-date
- [S5] SMFM Consult Series #52, Diagnosis and management of FGR (2020): https://www.ajog.org/article/S0002-9378(20)30535-4/fulltext
- [S6] Baby Your Baby (Utah), Fetal Growth Chart (uncited; matches the app's numbers): https://babyyourbaby.org/pregnancy/during-pregnancy/fetal-chart/
- [S7] Lê Mai Linh, Cao Ngọc Thành, Nguyễn Trần Thảo Nguyên. INTERGROWTH-21st vs Hadlock 1991 in diagnosing low birth weight, Hue University Hospital. VJOG 2024, doi:10.46755/vjog.2024.1.1672: https://vjog.vn/journal/article/download/1672/1472/
- [S8] Hadlock FP et al. Estimating fetal age: computer-assisted analysis of multiple fetal growth parameters. Radiology 1984;152:497–501: https://obgyn.utoronto.ca/sites/default/files/Hadlock%20Radiology%201984.pdf ; Hadlock EFW model AJOG 1985: https://obgyn.utoronto.ca/sites/default/files/Hadlock%20Model%20for%20EFW%20AC-FL-HC%20-%20AJOG%201985.pdf
- [S9] Archie JG, Collins JS, Lebel RR. Quantitative standards for fetal and neonatal autopsy. Am J Clin Pathol 2006;126:256–265: https://pubmed.ncbi.nlm.nih.gov/16891202/ (tables not retrieved; unverified).
- [S10] Kiserud T et al. The WHO Fetal Growth Charts. PLoS Med 2017;14(1):e1002220: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5398478/
- [S11] Ngô Thanh Hà, Nguyễn Đình Vũ. Vai trò các bảng sinh trắc học thai nhi trong tầm soát thai nhỏ. Tạp chí Phụ sản 2020;18(3):9–13: https://vjog.vn/journal/article/view/1099
