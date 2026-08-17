# Methods-Specification Revision — July 28, 2026

Closes the eight model-specification gaps and the software/estimation
disclosures found in the pre-submission reproducibility review of the July 27
draft. Applied by `apply_methods_edits.py` and `update_supplement_tables.py`.

Backups: `manuscript_July27_preMethodsEdit.docx`,
`Supplementary_Materials_preMethodsEdit.docx`.

**No inference changed.** Every *p*-value in the paper is what it was before.
One family of effect sizes was wrong by a factor of 3–4 and is now correct.

---

## 1. Study-phase contrasts were reported on the wrong scale *(substantive)*

`06_exploratory.R` and `09_tables.R` each defined the phase contrasts with
unnormalised integer codes, `c(-1,-1,-1,3)` and `c(-1,-1,2,0)`. For a contrast
column *c*, the fitted coefficient is Σ(*c·µ*)/Σ(*c*²), so those codes divided
the choice-vs-fixed difference by **4** and the journaling-vs-mind-body
difference by **3**. The manuscript printed the divided values as though they
were mean differences in scale points.

| Effect | Printed (June/July drafts) | Correct | *p* |
|---|---|---|---|
| Choice vs. fixed, session-baseline stress | −0.04 | **−0.17** | .032 (unchanged) |
| Choice vs. fixed, session-baseline valence | 0.07 | **0.29** | <.001 (unchanged) |
| Choice vs. fixed, within-session stress change | 0.06 | **0.22** | .031 (unchanged) |
| Journaling vs. mind-body, within-session stress | 0.07 | **0.21** | .055 (unchanged) |

The contrasts are now defined **once**, in `00_config.R`, difference-scaled, and
both scripts consume them via `withStudyPhaseContrasts()` so they cannot drift
apart again. `06_exploratory.R` asserts each coefficient equals the
corresponding `emmeans` marginal-mean contrast, which fails the pipeline if the
scaling is ever disturbed.

Rescaling is a pure reparameterisation: **all 36 phase *p*-values are
bit-identical** before and after; only estimates and CIs move. Verified by diff.

## 2. Stress scale direction was stated three different ways *(substantive)*

Data Analysis claimed all scales were "reverse-coded … so that higher values
indicate better well-being"; Materials described the stress VAS as "stressed to
relaxed"; the Table S2 note said higher = greater stress. Figure S1 settles it:
the scale runs **relaxed (1) → stressed (6)** and was never reverse-coded. A
reader following the old Methods would have flipped the sign of every stress
result and concluded sessions made students worse.

- Materials now reads "stress (relaxed to stressed) … arousal (tired to awake)".
- Data Analysis now states no scale was reverse-coded and gives the sign
  convention explicitly.

## 3. H2 analytic subset was undisclosed

Table 3 reports 2,422 observations, not the 2,642 in the session data. The 220
difference is the two choice-week days on which the booster survey recorded no
practice selection, so `Pref` is undefined. Data Analysis now states the subset,
its size, and the reason.

## 4. Multiple-comparison family was unverifiable

"Corrected for the two a priori comparisons" named no family and printed no
adjusted *p*. New `11_multiplicity.R` writes `output/holm_correction.csv`,
which shows the correction step by step under two families:

- **Preregistered (2 tests)** — H1 and H2 interactions. First Holm threshold
  α/2 = .025; smallest *p* = .0266 exceeds it, so the step-down stops and
  neither survives. This reproduces the paper's claim exactly.
- **All outcomes (6 tests)** — stricter; same conclusion.

Data Analysis now names the family, the threshold, and both results.

## 5. Discussion β's came from an undisclosed second model

The standardized |β| ≤ 0.07 and CI bound ≈ 0.14 come from
`10_supplementary.R`, which refits H2 with outcome and predictor standardized —
not from Table 3. Data Analysis now says so.

## 6. Ordinal model underspecified; clustering checked and cleared

The text gave no estimator and ignored that each participant contributes three
rows whose counts sum to a constant. Both are now addressed:

- Named as a proportional-odds model (`MASS::polr`).
- A random intercept is **not estimable** here — because each participant's
  counts sum to a constant there is no participant-level outcome variance, and
  `ordinal::clmm` drives the variance to 4e-09 and returns undefined SEs. That
  is a property of the design, not a fixable fitting problem.
- Two checks that *do* apply were run: participant-clustered robust covariance
  (SE 0.206 vs. naive 0.203, **1.01×**) and a within-participant permutation
  test preserving the compositional constraint exactly (20,000 resamples,
  *p* = .0039 vs. naive .0038).

**The clustering concern raised in review was not borne out** — the naive SE is
if anything slightly conservative. Both checks are reported in the Results.

## 7. Baseline-moderator model formula and singular fit

The formula never appeared in the main text and the singular-fit caveat lived
only in a supplementary table note, away from the estimate it qualifies. Both
now appear where the estimate is reported.

## 8. Across-session level described but never reported

Data Analysis promised three levels; Results delivered two. The description was
also wrong — the fitted model is a three-way `StudyDay × Condition × SesTime`,
not the two-way the text implied. Fixed, and the results are now reported in a
new subsection:

- Session-baseline **mood rose steadily**, *b* = 0.014/day, [0.006; 0.022],
  *p* < .001 (≈ 0.4 scale points over four weeks).
- Within-session **stress relief attenuated**, Study Day × Session Time
  *b* = 0.012, [0.001; 0.023], *p* = .038.
- No trend differed by condition (three-way *p*s > .24).

This bears directly on the paper's transfer thesis and was sitting unreported in
`h1_session_level.csv`, where any reviewer running the pipeline would find it.

## 9. Software, estimation, and coding disclosures

Data Analysis now names R 4.5.2, lme4 1.1-37, lmerTest 3.1-3, emmeans 1.11.0,
psych 2.5.3, MASS 7.3-65; REML estimation; Satterthwaite degrees of freedom;
Wald confidence intervals; treatment coding with WC and pre-session as
reference levels. `run_all.R` now writes `output/session_info.{csv,txt}` so the
claim is checkable against the run that produced the numbers. Completer
comparison tests (Welch *t*, χ²) are named in Results.

---

## Other corrections applied

| Item | Fix |
|---|---|
| Table 1 text ≠ Table 1 | Condition *b* −0.02 → **−0.01**, CI [−0.38; 0.35] → **[−0.37; 0.34]**, time *p* .765 → **.764** |
| Dangling "Table 4" | The cited table existed in neither document; its model is now **Table S5** |
| "Averaged across the 12 sessions" | Removed — describes an analysis that was never run |
| `w7ere`, `7Breathwork` | Typos removed |
| Stale "(formerly main-text Table N)" | Removed from S3, S4, S6 |

## Pipeline changes

| File | Change |
|---|---|
| `00_config.R` | Difference-scaled `studyPhaseContrasts` + `withStudyPhaseContrasts()`; added `ordinal`, `sandwich` |
| `04_h1.R` | Across-session results surfaced to `h1_across_session.csv`; sign-flip detection |
| `06_exploratory.R` | Shared contrasts; `emmeans` scaling assertion; cluster-robust + permutation checks; comparison targets updated to the current draft; sign-flip detection |
| `09_tables.R` | Shared contrasts |
| `11_multiplicity.R` | **New** — explicit Holm correction |
| `run_all.R` | Environment record; new step |

**Divergence detector fixed.** The old check used an absolute threshold
(`abs(b - pub_b) > 0.05`), which on these 0.0x-scale coefficients let a sign
flip pass as "consistent" — it had been silently mislabelling the arousal
phase-baseline estimate (published 0.04, *p* = .056; reproduced −0.005,
*p* = .847). Now checks sign explicitly and scales the magnitude test to the
target value.

## Verification

- Clean-room run in a relocated copy: **all 31 outputs byte-identical** to the
  project copy.
- Two consecutive runs identical — deterministic despite the added permutation
  test (seeded).
- 14/14 manuscript numbers match pipeline outputs (`verify.py`).
- All table cross-references resolve; S1–S6 present and cited.

---

# Addendum — WHO-5 recode and two bugs it exposed (July 28)

Applied by `apply_who5_edits.py` and `update_supplement_who5.py`.
Backups: `*_preWho5Edit.docx`.

## A. WHO-5 was never mapped onto its own metric

Qualtrics exported the five WHO-5 items as recode values `2, 4, 5, 6, 7, 9` —
six codes for six options, with gaps 2,1,1,1,2. `03_score.R` averaged them as an
interval scale. Study team confirmed (2026-07-28) that the codes ascend in
display order over the standard WHO-5 response set, so they now map to 0–5.

**No inference changes** (Spearman *r* = .997, composite *r* = .9994, H1
*p* = .213 → .212). **What changes is the description of the sample:**

| | Published | Repaired |
|---|---|---|
| WHO-5 baseline | *M* = 5.32 (no recognised metric) | 11.68/25; **percentage 46.7** |
| At or below ≤50 (poor well-being) | not reported | **57.5%** |
| At or below ≤28 (likely depression) | not reported | **16.7%** |
| At or above 80 (near ceiling) | not reported | **4.2%** |
| PHQ-4 total | 2.37 (on 1–4 codes) | 5.47/12 — **mild** band |

The manuscript described a "predominantly healthy sample" with possible
"ceiling effects" and completers having "the least room to improve". Two
validated instruments say otherwise. Those passages are rewritten; the null
longitudinal result now reads as *not* attributable to a ceiling, which is a
stronger claim than the one it replaces.

## B. BIPS reverse-keying was wrong — and the recode nearly turned it into a false finding

`psych::scoreItems(min = NULL, max = NULL)` reverses an item as
`(min + max) − x` using the range of the **entire item frame**, not the scale.
The frames carry items on 1–5, 1–6, 1–8 and (unrepaired) 2–9 scales at once, so
BIPS_8 was reversed as `10 − x` instead of the correct `6 − x`, inflating every
BIPS score by a constant 4/9 = 0.444. **The published BIPS mean of 3.81 should
read 3.36.** No inference was affected — the offset is identical for everyone at
both waves (per-person SD of the difference = 0, *r* = 1.000, α identical).

It was correct only by accident. Both frames happened to reach max 9 *because of
the un-recoded WHO-5*. Repairing the WHO-5 dropped the baseline frame to max 8
and the post frame to max 6, so the two waves were reversed with different
constants — **manufacturing a spurious 0.23-point pre-post drop in perceived
stress at *p* = .0014, Holm *p* = .008.** Caught before it reached the paper.
BIPS_8 is now reversed explicitly against its own 1–5 range, and no scale key
carries psych's `-` marker.

## C. Scale-by-scale check added

New **Table S7** and a Results paragraph: no constituent of the composite moves
reliably after Holm correction across the six scales. This answers the "does the
composite hide divergent movement?" question directly rather than leaving it to
a reviewer.

## Numbers updated across both documents

Table 1 (*p* = .764 → .798, .936 → .952, .213 → .212), completer comparison
(WHO-5 percentage 46.7 vs 37.9, *d* = 0.50, *p* = .010), PCA variance
54.7% → 54.9%, Table S1 (WHO-5, BIPS, PHQ-4 rows + metric note), Materials
descriptions of all three instruments.

## Verification

Clean-room relocated run: **all 33 outputs byte-identical**. 10/10 revised
manuscript numbers match pipeline outputs. S1–S7 all present and cited, none
unresolved, no stale values remaining. Body 5,484 words (1,516 headroom).

**Confirmed:** the WHO-5 ordering was subsequently verified directly against
`Baseline_WC.qsf` — see Addendum 2.

---

# Addendum 2 — .qsf audit and preference scoring (July 28)

The study team supplied `Baseline_WC.qsf`, which lets every recode assumption
rest on the survey definition rather than on inference from the export.

## WHO-5 confirmed

The WHO-5 matrix carries `AnswerRecodeValues` 2,4,5,6,7,9 over `ColumnLabels`
"At No Time / Some of the time / Less than half the time / More than half the
time / Most of the time / All of the time", in that display order. The 0–5
mapping applied in Addendum A is correct, and because the instrument was
administered with its standard verbal anchors the comparison against the ≤50
and ≤28 thresholds is legitimate. PHQ-4 confirmed likewise (displayed "0,1,2,3"
over stored 1,2,3,4). BIPS confirmed as 1–5, with `BIPS_8` = "How often have you
felt that you were on top of things?" — the positively-worded item, correctly
identified as the reverse-keyed one.

## New: two preference dimensions were on the wrong metric

A sweep of all 268 questions flagged 38 with non-contiguous or label-offset
recodes. Most are unused or nominal. **Four touch scored variables, and two of
them feed the H2 predictor:**

| Dimension | Displayed | Stored | Issue |
|---|---|---|---|
| Ranking | 1–4 | 1,2,3,4 | clean |
| **Comfort** | 1–4 | **1,2,4,5** | **non-contiguous** |
| Benefit | 1–4 | 1,2,3,4 | clean |
| Practical | 1–4 | 1,2,3,4 | clean |
| **LongTerm** | 1–4 | **5,6,7,8** | **offset +4** |

The preference composite was therefore the mean of three items on 1–4, one on
{1,2,4,5} and one on 5–8. The LongTerm offset is a constant and harmless to any
model; the Comfort gap is a real nonlinearity, scoring the step from option 2 to
3 as double every other step. Both are now mapped back to the displayed 1–4
scale in `repairQualtricsCodes()`.

*(This corrects a claim in Addendum A that WHO-5 was the only affected scale.
That came from scanning pooled composites, where 1–4 and 5–8 items together
look like a clean 1–8 range.)*

**Impact — no conclusion changes:**

| | Before | After |
|---|---|---|
| H2 arousal (Pref × Time) | *b* = 0.107, *p* = .051 | *b* = 0.112, **p = .058** |
| H2 stress / valence | .302 / .765 | .275 / .785 |
| Relative preference | .105 / .398 / .572 | .108 / .365 / .586 |
| Practice selection | *b* = 0.59, SE 0.20, *p* = .0038 | *b* = 0.64, SE 0.22, *p* = .0034 |
| Preference α range | .77–.83 | .77–.84 |
| Standardized |β| / CI bound | ≤0.068 / 0.137 | ≤0.066 / 0.135 |

Arousal remains the largest H2 term, remains nonsignificant, and remains short
of the .025 corrected threshold. Old and repaired composites correlate .996–.997.

**Updated in the documents:** abstract (*p* = .051 → .058), Materials
(preference α range and the common 4-point scale), Results H2 (all six
interaction terms), Results practice selection (with both robustness checks),
Discussion H2, main-text Table 3, supplementary Table S3, and a scoring note
appended to Deviations from the Preregistration.

## Verification

Clean-room relocated run: **all 33 outputs byte-identical**; deterministic across
runs. 16/16 manuscript values match pipeline outputs; S1–S7 present and cited,
none unresolved; no stale values detected. Body 5,571 words (1,429 headroom).

---

# Addendum 3 — De-identification and pipeline restructure (July 28)

The pipeline is now split at a release boundary, so the de-identified dataset is
the entry point for reproduction rather than an afterthought.

```
RawData/ ─01_assemble─▶ private/tidy/ ─02_deidentify─▶ data/ ─03…13─▶ output/
  withheld                withheld                    RELEASED      RELEASED
```

`run_all.R` detects which stage it can run: with `RawData/` and `private/` it
runs both; without them it starts from `data/`. No flag to set — a published copy
just works.

## What 02_deidentify.R does

1. Removes study-staff test responses (keyed on email; this is the last step
   that can see one).
2. Drops direct identifiers: names, emails, IP addresses, geolocation, Qualtrics
   response GUIDs, external references, unused timestamps.
3. Replaces the institutional participant number with an arbitrary study ID in a
   seeded random order, so released IDs encode nothing — not even enrolment
   order. Crosswalk written to `private/` only.
4. Redacts free text **while preserving whether a response was given**, because
   `04_score.R` infers which practice a participant did from whether the
   journalling prompts were filled in.
5. Replaces submission timestamps with a zero-padded submission-order rank. The
   only downstream use is ordering duplicate submissions; the rank preserves
   that ordering exactly.
6. Re-scans its own output and refuses to write if anything identifying survives.

## 13_release_audit.R — and why it is separate

Step 6 can only guarantee the files that script writes, not the directory they
land in. **A real leak in this project's history proves the point:** an earlier
`01_assemble.R` wrote a dual-enrolment report containing five participant email
addresses to `output/`. When that write was moved to `private/`, the
already-written file stayed behind — correct code, stale artefact, live PII in
the directory intended for publication. It was found by scanning artefacts, not
code.

`13_release_audit.R` therefore runs last over the whole release surface
(`data/` **and** `output/`) and fails the build on any finding. Verified both
ways: it passes clean, and re-planting that exact file makes it exit non-zero
with 4 findings.

The stale file has been deleted. `private/` and `RawData/` are now
`.gitignore`d, `private/README.md` states what must never be shared, and
`experimenterEmails` is read from `private/` instead of being hard-coded — so
publishing `00_config.R` no longer publishes three real addresses.

## Renumbering

`02_clean`→`03_clean` … `11_multiplicity`→`12_multiplicity`, plus new
`02_deidentify` and `13_release_audit`. In stage-2 scripts `sonaID`→`pid` and
`StartDate`→`SubmissionOrder`, matching the released columns.

## Verification

| Check | Result |
|---|---|
| Full pipeline from raw (13 steps) | passes |
| Stage 2 alone from the release (11 steps) | passes |
| **Release run vs full run** | **all 33 shared outputs byte-identical** |
| Release audit, both runs | zero findings |
| Manuscript vs pipeline | 16/16 match |
| PII scan of `data/` + `output/` | clean |

Only `consort.csv` changed relative to the pre-restructure state, and only as
intended: the three "remove experimenter responses" rows moved to
`deidentification_report.csv`, and the step label reads `pid` rather than
`sonaID`. Every count is unchanged.

**One caveat.** The practice-selection permutation test draws group by group, so
its RNG stream depends on participant ID order — which is now assigned
arbitrarily at the release boundary. It is fully deterministic for a fixed
dataset, and `B` was raised to 50,000 so Monte Carlo error sits below the
reported precision (*p* = .0036, reported as .004). Every other output is
byte-identical across runs and across entry points.

---

# Addendum 4 — Sample size reported accurately at both levels (July 28)

Applied by `apply_sample_size_edits.py`, `update_table_sample_notes.py` and
`refresh_figure1.py`. Backups: `*_preSampleEdit.docx`, `*_preSampleNotes.docx`,
`*_preFigureSwap.docx`.

## The problem

The study analyses at two levels on two different samples, and the paper
reported only one of them:

| Sample | n | WC | CN | Used for |
|---|---|---|---|---|
| Adherent (≥ 8 of 12 sessions) | **125** | 65 | 60 | within-session change, H2, study phase |
| Adherent **+ post survey** | **120** | 63 | 57 | baseline-to-post change, baseline moderator |
| Adherent, no post survey | 5 | 2 | 3 | session-level models only |

Session-level models need booster sessions and a baseline but not the
post-intervention survey, so they correctly retain five adherent participants
who never completed it. Tables 2, 3, S3 therefore printed `N id = 125` while
every sentence in the paper said 120 — including the abstract, which attributed
*both* levels to "120 adherent participants". The study-phase tables printed
`N id = 65` (the WC arm) with no explanation at all.

## Fixed

- **Abstract** now separates the two: within-session change in 125 (WC 65,
  CN 60), baseline-to-post change in the 120 of those who also completed the
  post survey (WC 63, CN 57).
- **Participants** distinguishes the two exclusion gates instead of reporting
  them as one, and names the five session-level-only participants.
- **Data Analysis** gains a paragraph stating which sample each model family
  uses and why restricting the session-level models to 120 would be wrong.
- **Deviations** — the H2 power shortfall is against n = 125, not 120.
- **Every table note** now names its sample: Tables 1/S6/S7 the 120-participant
  study-level sample, Tables 2/3/S3 all 125 adherent participants, Tables S4/S5
  the 65 adherent WC participants, Tables S1/S2 their respective samples.
- **`03_clean.R`** writes `output/analysis_samples.csv`, so these counts are
  generated rather than transcribed, with a `stopifnot()` that the two samples
  differ by exactly the no-post group.

## CONSORT diagram rebuilt

Figure 1 previously collapsed adherence and the post-survey requirement into a
single exclusion box and ended at one "Final sample n = 120". It now shows the
adherence gate and the post-survey gate as separate steps, with an **Adherent
(n = 65 / n = 60, session-level analyses)** row between them, an exclusion box
noting that those five are *retained in session-level analyses*, and a closing
box reporting both samples. The regenerated figure is embedded in the manuscript
and is byte-identical to `output/Figure1_CONSORT.png`.

## Verification

- 13/13 sample-size text checks pass; 7/7 table `N id` values match the pipeline.
- All previous checks still pass (16/16 statistical values, S1–S7 resolved).
- Release-only run: **all 34 outputs byte-identical**, including the new figure.
- Release audit: zero findings.
- Body 5,750 words (1,250 headroom).

---

# Addendum 5 — References and the age imbalance (July 29)

Applied by `apply_reference_fixes.py` and `apply_age_edits.py`.
Backups: `*_preRefFix.docx`, `*_preAgeEdit.docx`.

## References

- **Cantril (1965)** moved from the manuscript reference list to Supplementary
  References (alphabetically, before Cummings & Bromiley). It is cited only in
  the supplement, for the Cantril Ladder measure, which is not analysed in the
  main text.
- **`DiPlacito-Derango, 2016` → `DiPlacito-DeRango, 2016`** in the in-text
  citation, matching the reference-list entry.

Verified: every in-text citation key resolves to a reference entry, and every
entry is cited — nothing missing, nothing orphaned, in either document.

## The age imbalance is one participant

Figure 1 showed WC *SD* = 5.62 against CN *SD* = 1.16, which reads as a serious
baseline failure. It is not. In the analysed WC arm:

| Oldest WC participants removed | *n* | *M* | *SD* | max | % of WC age variance |
|---|---|---|---|---|---|
| 0 | 63 | 20.25 | **6.28** | 60 | — |
| 1 | 62 | 19.61 | 3.71 | 42 | **65.7%** |
| 2 | 61 | 19.25 | 2.34 | 32 | **86.5%** |
| 4 (all > 25) | 59 | 18.92 | 1.41 | 25 | 95.3% |
| CN reference | 57 | 18.63 | 1.05 | 24 | — |

Medians are 19 vs 18 and **the interquartile range is 18–19 in both arms**. Four
WC participants are over 25 (26, 32, 42, 60); none in CN. The difference in means
is nominally significant by *t* test (*p* = .047) but **not** by rank test
(Wilcoxon *p* = .108), and drops from 1.62 to 0.61 years once the two oldest are
removed.

So the arms are comparable in the typical participant; the mean and SD are
carrying four mature students, one of them 60.

### What changed

- **Participants** now reports median = 18, IQR 18–19, range 18–60 alongside the
  mean, so the shape of the distribution is visible.
- **Limitations** reports the arm difference, identifies the cause, gives both
  the *t* and rank tests, and notes randomization was not stratified on age.
- **`08_descriptives.R`** emits `age_by_condition.csv` (per sample, with median,
  IQR, and a count over 25) and `age_outlier_sensitivity.csv`
  (leave-the-*k*-oldest-out), so these claims are generated, not asserted.
- **Figure 1** now reports median and IQR alongside mean and SD.

### A figure bug found while checking this

The CONSORT condition boxes paired **"WC condition n = 80"** with *M*(age) =
20.25, *SD* = 6.28 — the ages of the **analysed** 63, not the randomised 80
(*M* = 19.96, *SD* = 5.62). The boxes now read their ages from the matching
sample, and `ageOf()` errors if the requested sample/condition row is missing, so
the mismatch cannot recur silently.

## Verification

- 14/14 reference and age checks pass; citation lists fully reconciled.
- All prior suites still pass: 16/16 statistical values, 13/13 sample-size
  checks, 7/7 table `N id` values.
- Embedded Figure 1 byte-identical to `output/Figure1_CONSORT.png`.
- Release-only run: **all 36 outputs byte-identical**. Release audit: zero findings.
- Body 5,884 words (1,116 headroom).

---

# Addendum 6 — Choice-week effects given their real magnitude (July 29)

Applied by `apply_choiceweek_edits.py`. Backup: `*_preChoiceWeekEdit.docx`.

The Discussion was written when the study-phase contrasts were mis-scaled, so it
treated the choice-week effects as negligible. On the corrected scale they are
among the largest in the study.

| Effect | Scale points | SD units |
|---|---|---|
| Session-baseline **valence**, choice vs fixed | +0.29 | **0.27** [0.12, 0.42] |
| Session-baseline **stress**, choice vs fixed | −0.17 | 0.16 [0.02, 0.31] |
| Session-baseline arousal | −0.02 | −0.01 (n.s.) |

Two comparisons make the size concrete, both now computed in `07_exploratory.R`:

- The **study-wide average within-session mood improvement is 0.31 points**, so
  participants began choice-week sessions almost a full session's worth of
  improvement ahead of where they began fixed-week sessions.
- The choice week **retained only 42% of the fixed-week stress reduction**
  (−0.163 vs −0.387) — an attenuation of roughly two thirds of the study-wide
  average within-session stress effect.

Outside the within-session changes themselves (0.28–0.30 SD), nothing else in
the study reaches 0.27 SD: the H1 study-level interaction is ~0.18 SD and n.s.,
the H2 preference interactions ≤ 0.07 SD, the condition × session-time arousal
effect ~0.14 SD.

## Magnitude went up; attribution did not

Two things stop this becoming a positive result for choice, and both are now
stated explicitly rather than gestured at:

1. **The across-session trend is a quantitatively matched competitor.** The
   analysis added earlier in this revision shows session-baseline mood rising
   0.014 points/day — about **0.39 points over the protocol**, the same order as
   the 0.29-point choice-week contrast. A gradual improvement in how students
   arrived at sessions reproduces the whole pattern with no role for autonomy.
2. **The confound is structural, not adjustable.** Study phase is a
   deterministic function of study day. Entering both in one model yields
   unstable estimates rather than cleaner ones — the arousal contrast jumps from
   0.02 to 0.70 under adjustment, a pure collinearity artefact. That diagnostic
   is deliberately *not* reported in the paper, because it cannot support a
   conclusion in either direction; it is the reason the paper says the confound
   cannot be adjusted away.

The paragraph therefore closes on: a moderate and reliable choice-week advantage
in arriving affective state is established; its attribution to autonomy is not.
Counterbalancing when the choice week occurs is recommended for future work.

The paired result — better arriving state, smaller within-session gain — is
framed as a within-session ceiling, which the numbers now support rather than
merely suggest.

## Precision fix caught in verification

The first draft of this paragraph said within-session *gains* were
correspondingly smaller. Only **stress** attenuated: valence retained 87% and
arousal did not attenuate at all (170%, n.s.). Narrowed to stress in both the
Discussion and the abstract.

## Abstract

Previously reported only the absent within-session advantage. Now also reports
that participants entered choice-week sessions in better affective state
(mood, 0.27 SD) with a correspondingly smaller within-session stress reduction,
inseparable from the choice week always falling last.

## Verification

- 14/14 choice-week checks pass; every figure traced to
  `choice_week_effect_sizes.csv` / `choice_week_within_session.csv`.
- Ryan & Deci (2000) removed from this paragraph but still cited in the
  Introduction — both reference lists remain fully reconciled, nothing orphaned.
- All prior suites pass: 16/16 statistical values, 13/13 sample-size checks,
  7/7 table `N id` values, 14/14 reference and age checks.
- Release-only run: **all 38 outputs byte-identical**. Release audit: zero findings.
- Body 6,081 words (919 headroom).

---

# Addendum 7 — Informed choice, not autonomy (July 29)

Applied by `apply_informed_choice_edits.py` and `add_table_s8.py`.
Backups: `*_preInformedChoiceEdit.docx`, `*_preTableS8.docx`.

## The construct was mis-stated

Author clarification: the final week was placed last **by design**, because
choosing among the techniques presupposes having practised them. The
manipulation was *informed choice*, not autonomy in the abstract. On that
reading the timing is constitutive of the manipulation, and the earlier
recommendation to "counterbalance when the choice week occurs" was wrong — it
would dismantle the construct rather than isolate it.

The Introduction now states this rationale, the Current Study names the final
week as a third exploratory aim, and the Discussion is rebuilt around informed
choice.

## Two new analyses, and they argue against the construct

**Both arms chose in week 4.** The phase analysis had been WC-only, but CN
participants also picked a preferred video theme. Choosing among three passive
nature videos is a much thinner version of the same manipulation, so a
choice-specific account predicts a larger week-4 shift in WC. It does not appear:

| Session-baseline shift, week 4 vs weeks 1–3 | Valence | Stress |
|---|---|---|
| Wellness Choice | +0.29 [0.13, 0.46], *p* < .001 | −0.17 [−0.33, −0.02], *p* = .032 |
| Connection with Nature | +0.23 [0.05, 0.40], *p* = .013 | −0.13 [−0.31, 0.06], *p* = .180 |
| **Week × Condition** | **−0.07, *p* = .589** | **0.05, *p* = .690** |

**The shift does not grow with prior practice.** If choosing needs expertise,
participants who had completed more of the fixed weeks should show a larger
week-4 shift. The interaction runs the other way (stress *b* = 0.18,
*p* < .001; valence *b* = −0.11, *p* = .047; both indicate a *smaller*
advantage with more practice). Reported as weak: prior sessions range only 5–9
and also index engagement.

Both are now **Table S8**, generated by `07_exploratory.R` into
`week4_by_condition.csv` and `week4_prior_practice.csv`.

## The identifying design is yoking, not counterbalancing

Moving the choice week earlier changes informedness, cumulative practice,
elapsed time and platform familiarity together, so it relocates the confound
rather than removing it. What identifies an effect of choosing is a **yoked
control at matched time**: in the target week, half of participants choose while
half are assigned a technique drawn from the choosers' distribution, so the mix
of practices is matched and only selection differs. Crossing that with early vs
late timing tests the expertise hypothesis as the interaction, with the
choose-versus-assigned contrast taken *within* each timing arm so elapsed time
cancels. Randomising whether an assigned technique matches a stated preference
would additionally convert H2 from an observational test into an experimental
one. All of this is now in the Discussion.

The paragraph closes on: a moderate and reliable week-4 advantage in arriving
affective state is established; that informed choice produced it is not.

## Abstract

Now reports that the final-week pattern **appeared equally in both arms and did
not grow with prior practice, pointing to time in the protocol rather than to
informed choice** — previously it attributed the pattern only to the choice week
falling last.

## Verification

- 16/16 informed-choice checks pass; every reported figure traced to
  `week4_by_condition.csv` / `week4_prior_practice.csv`.
- Table references resolve S1–S8, none unresolved or uncited; reference lists
  still fully reconciled (nothing missing, nothing orphaned).
- All prior suites pass: 16/16 statistical values, 13/13 sample-size checks,
  7/7 table `N id` values, 14/14 reference and age checks.
- Release-only run: **all 40 outputs byte-identical**. Release audit: zero findings.
- Body 6,418 words (582 headroom).

---

# Addendum 8 — Full read-through, number audit, and presentation (July 30)

## Defects found by reading the documents end to end

| Defect | Fix |
|---|---|
| **Across-session trends were WC-only simple slopes** reported as sample-wide. Under treatment coding the `StudyDay` coefficient in the three-way model is the slope at the reference levels (WC, pre-session). For arousal the difference is material: WC-only *b* = 0.001, *p* = .82 vs pooled *b* = 0.008, *p* = .06. | New marginal model in `05_h1.R` (`outcome ~ StudyDay + (1｜id)` on pre-session rows) → `across_session_marginal.csv`. Results and Discussion now quote the marginal estimate (mood 0.012/day, 0.34 points over four weeks). |
| **Age paragraph mixed samples** — randomised-sample means and SDs paired with analysed-sample tests. On the randomised sample the difference is *not* significant (*p* = .058, not .047). | `08_descriptives.R` emits `age_arm_comparison.csv` for all three samples; Limitations now quotes the randomised row throughout. |
| **Orphaned heading** — "Hypothesis 1 (Across Sessions)" sat *after* its own paragraph, leaving the text under the within-session heading. | Heading moved above its paragraph. |
| **Stale count** — Data Analysis said the permutation test used 20,000 resamples; it was raised to 50,000. | Corrected. |
| **Table 2 had a phantom 11th column** (last cell of every row spanned two), rendering Valence wider than the other outcomes. | Rebuilt as a symmetric 10-column grid. |
| **Inconsistent header labels** — "p-value / p / p-value" within one table. | Normalised to *p* throughout. |

## Number audit

`audit_numbers2.py` extracts every statistic from both documents and matches it
numerically against all pipeline CSVs with a rounding tolerance:

**134 statistics checked — 133 reconcile to a pipeline value or a documented
derivation.** The single exception is the a priori "90% power" target, which
predates the data.

## Presentation

**Tables (`format_tables_apa.py`).** All 11 tables across both documents now use
APA rules: rule above the header, below the header, below spanner labels, and at
the foot — no vertical rules, no interior horizontals. (The supplement had been
using Word's "Table Grid", i.e. a box around every cell, which APA does not
permit.) Header rows repeat across page breaks and rows no longer split. Table
numbers are bold on their own line with the title italic beneath. Statistical
symbols are italicised in headers and notes.

**Figure 2 — new (`14_figure2_dissociation.R`).** The paper's headline is a
dissociation across three timescales and had no figure of it; Figure 1 is the
CONSORT diagram, which is administrative. Figure 2 shows all three levels with
one visual idiom — estimated marginal means joined by a line — so the
dissociation reads without consulting a number:

- **A** within session, on a *shared* y-axis (a free axis made the smallest
  change, arousal, look like the largest)
- **B** model-implied across-session trend, pooled across arms
- **C** the study-level composite, flat

Condition is encoded by hue **and** point shape **and** line type, so the figure
survives greyscale printing and colour-vision deficiency. Hues are the Okabe-Ito
blue/vermillion pair, validated rather than eyeballed (worst adjacent ΔE 21.9
protan, 31.2 normal vision; all six checks pass).

Two fidelity problems were caught by rendering and inspecting it: the free y-axis
in panel A, and panel B originally drawing `geom_smooth`'s OLS line, which need
not match the fitted model. Panel B now plots predictions from the same marginal
model the Results report.

**Vector output.** Both figures now emit PDF alongside PNG. Note that cairo
stamps a `/CreationDate` into PDFs, so they are not byte-reproducible across runs
even though their drawing content is — 7 of 8 PDF streams match exactly, the
eighth differing only in that timestamp. **Check the PNGs when verifying
reproducibility.**

## Verification

- 134 statistics audited, 133 reconciled (the exception is the a priori power target)
- All suites pass: 16/16 statistical values, 13/13 sample-size checks, 7/7 table
  `N id` values, 14/14 reference and age checks
- Tables S1–S8 resolve; Figures 1 and 2 both cited in the body
- Embedded figures byte-identical to pipeline output
- Release-only run: all CSV and PNG outputs byte-identical; release audit clean
- Body 6,469 words (531 headroom)

---

# Addendum 9 — Figure 2 panel B split by arm (July 30)

Applied by `apply_arousal_split_edits.py`. Backup: `*_preArousalSplit.docx`.

Panel B had been pooled across conditions on the grounds that no across-session
trend differed by arm. Author query: why not split it like panels A and C?

**Correct — and pooling was hiding something.** The original reason for pooling
was that per-condition `geom_smooth` lines showed a CN arousal rise the model did
not support; but that was an artefact of the OLS smooth, fixed separately when
panel B was changed to plot model-implied fits. After that fix, pooling mainly
withheld evidence for a claim the paper makes.

| Across-session trend | WC over 28 days | CN over 28 days | Interaction *p* |
|---|---|---|---|
| Stress | −0.17 | −0.04 | .49 |
| Mood | +0.39 | +0.29 | .60 |
| **Arousal** | **+0.02** | **+0.42** | **.076** |

Stress and mood are near-parallel, so splitting lets the figure *demonstrate*
that the trends do not differ rather than assert it. Arousal is the one place
they diverge: CN participants arrive progressively more alert across the
protocol while WC participants do not. Sub-threshold, so reported as an
observation.

`05_h1.R` now emits `across_session_by_arm.csv`.

**Text reconciled.** Results had said "None of the three trends differed by
condition", which the split figure visibly contradicts; it now reports the
stress/mood equivalence and the marginal arousal divergence separately. The
Figure 2 note no longer describes panel B as pooled.

**A coherence worth noting.** WC showed the larger *within-session* arousal gain
(*p* = .027, also sub-threshold). Rising baseline alertness in CN leaves less
room for a within-session gain, so the two observations are mutually consistent
under the same ceiling logic the paper already applies to the final week. Added
to the Discussion, explicitly drawing no conclusion from two sub-threshold
effects.

## Housekeeping

- **APA leading zeros.** Nine *p*-values had been written as `p = 0.076` while
  the rest of the manuscript used `p = .076`. Normalised. Cohen's *d* correctly
  keeps its leading zero (APA drops it only for statistics bounded by 1).
- **`refresh_figures.py` replaces `refresh_figure1.py`.** The old script assumed
  a single embedded image; with two figures, editing a figure script after
  insertion left a stale copy in the .docx — which is exactly what happened to
  Figure 2 after panel B was split. The new script refreshes every figure, maps
  them by document order, rescales each to its new aspect ratio, refuses to run
  against a Word lock, and verifies byte-equality afterwards.

## Verification

- 136 statistics audited, 135 reconciled (the exception remains the a priori
  power target)
- All suites pass: 16/16 statistical values, 13/13 sample-size checks, 7/7 table
  `N id` values
- Embedded figures byte-identical to pipeline output
- Release-only run: **all 44 CSV and PNG outputs byte-identical**; audit clean
- Body 6,592 words (408 headroom)

---

## Still outstanding

Nothing from the pre-submission review remains open.

| Item | Resolved in |
|---|---|
| Model specification (8 items + disclosures) | main section |
| WHO-5 / PHQ-4 recodes, BIPS reverse-keying | Addendum 1 |
| `.qsf` audit, preference-dimension recodes | Addendum 2 |
| De-identification and release boundary | Addendum 3 |
| Sample size at both analysis levels | Addendum 4 |
| References and the age imbalance | Addendum 5 |
| Choice-week effect magnitudes in the Discussion | Addendum 6 |
| Informed-choice reframing + week-4 tests across arms | Addendum 7 |
| Read-through defects, number audit, APA tables, Figure 2 | Addendum 8 |
| Figure 2 panel B split by arm; arousal divergence | Addendum 9 |

Remaining item for the authors, not a defect: confirm the OSF deposit is public
at acceptance rather than view-only.
4. Age imbalance across arms (WC SD 6.28, max 60 vs CN SD 1.05).
5. Cantril (1965) in the wrong reference list; `DiPlacito-DeRango` capitalisation.
