# Wellness Choice — Reproducible Analysis Notes

Working log for rebuilding the analysis pipeline from raw data through to the
results reported in the manuscript.

**Status:** Complete pipeline built and validated (`R/run_all.R`, ~10s from raw data).
Manuscript edits applied — see `MANUSCRIPT_EDITS.md`.
Open questions are marked `❓Q1`, `❓Q2`, … and collected at the bottom.

> **A note on participant identifiers.** Every participant number in this
> document is a **released study ID (`pid`)**, the same ID used throughout
> `data/`, so any observation here can be checked against the published
> dataset. Where the text says `sonaID` it refers to the *column* in the
> identifiable upstream stage; the institutional numbers themselves are not
> reproduced here. The mapping between the two lives only in
> `private/id_crosswalk.csv`, which is withheld.

---

## 0. Environment

- No `R` on the system `PATH`, but three installations exist. **R 4.5.2**
  (`C:\Program Files\R\R-4.5.2`) has every package the original script needs;
  R 4.6.0 is missing `apaTables` and `paran`. The pipeline targets **4.5.2**.
- Run scripts with:
  ```
  "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" 01_assemble.R
  ```
- Analysis stays in **R** — `lme4`/`lmerTest` are what the paper reports and
  there is no equivalent-quality port. No rewrite in another language proposed.

## 1. Repository layout

```
Reproducible/
  R/
    00_config.R     paths, packages, study constants
    01_assemble.R   raw Qualtrics exports -> tidy CSVs        [DONE]
    02_clean.R      exclusions + CONSORT flow                 [DONE]
    03_score.R      questionnaire scoring, WB composite       [DONE]
    04_h1.R         Hypothesis 1                              [DONE]
    05_h2.R         Hypothesis 2                              [DONE]
    06_exploratory.R  exploratory analyses                    [DONE]
    07_descriptives.R demographics + descriptives             [DONE]
    08_consort_figure.R Figure 1                              [DONE]
  data/             generated CSVs (baseline / booster / post)
  output/           tables, figures, diagnostic reports
```

Each script is standalone and re-runnable; nothing depends on objects left in
the global environment by a previous script.

## 2. What the original pipeline did that wasn't in code

The published analyses read `Analyses/FullData.xlsx`, a workbook assembled by
hand from the three raw Qualtrics exports. Comparing the raw exports to that
workbook shows the manual steps. Good news: **the raw exports already carry
`sonaID`, `Emails`, `Condition` and `StudyDay`** as embedded data, so the
workbook is not adding information — it is repairing it. Every repair below is
now done in `01_assemble.R`.

### 2.1 Unresolved Qualtrics placeholders  *(the big one)*

Where piped embedded data failed to resolve, Qualtrics wrote the literal
reference instead of the value:

| Export   | Field       | Rows affected | Placeholder value        |
|----------|-------------|---------------|--------------------------|
| Booster  | `Condition` | **120**       | `${e://Field/Condition`  |
| Booster  | `sonaID`    | 11            | `%483%`                  |
| Baseline | `sonaID`    | 3             | `%483%`                  |

All 120 Booster rows are from **StudyDay 24–25 — the choice week**, and 118 of
them are complete sessions. The `intConditionFix` sheet in
`Analyses/FullData.xlsx` is where these were patched by hand.

This matters because the placeholder is *not* `NA`. Had the original script been
pointed at raw data, `intGood[!is.na(intGood$Condition), ]` would have kept these
rows as a **third condition level** — and since `$` sorts before letters in
ASCII, that junk level would have become the *reference* level for every
`Condition` contrast in the H1 daily models. **The manual workbook prevented
this, so the published Table 2 results are not affected.** But it is exactly the
kind of silent failure a reproducible pipeline has to close off.

`01_assemble.R` blanks any value matching `^\$\{[ef]://` or `^%\d+%$` before
anything else touches the data.

### 2.2 Condition recovered by participant, not hard-coded

Two Post rows reached the original script with `Condition = NA` (their `Emails`
field was blank, so the roster merge failed). The original script patched them
inline:

```r
postReady[which(postReady$id %in% 81), "group"] = "Nature"
postReady[which(postReady$id %in% 129), "group"] = "Choice"
```

Because randomisation is at the person level, condition is recoverable by
`sonaID` from any export that has it. `01_assemble.R` builds a condition roster
across all three exports and fills gaps from it. **This reproduces both
hard-coded values exactly** (verified), with the assignment now traceable to a
data source instead of a magic number.

### 2.3 Two rows deleted from the workbook

| Sheet    | `ResponseId`        | `sonaID` | Why it looks deleted |
|----------|---------------------|----------|----------------------|
| Baseline | *(response id withheld)* | 101     | Complete, but `Condition` blank |
| Post     | *(response id withheld)* | 81    | `Progress = 5`, not finished |

Both would have been dropped by the script's own exclusion rules anyway, so
deleting them changed nothing. `01_assemble.R` keeps them and lets `02_clean.R`
exclude them, so the CONSORT counts come out of code rather than out of Excel.

## 3. Validation of `01_assemble.R`

Pipeline output vs. the hand-built `FullData.xlsx`, matched on `ResponseId`:

| Sheet    | Rows (mine / FullData) | `Condition` mismatches | Explanation |
|----------|------------------------|------------------------|-------------|
| Booster  | 1586 / 1586            | 6                      | 3 recovered by pipeline (101, 8, 162); 3 deliberately left blank (dual enrolments, see ❓Q1) |
| Post     | 142 / 141              | 2                      | Exactly the two hard-coded fixes, now derived — ✅ |
| Baseline | 232 / 231              | 48                     | Pipeline fills conditions the workbook leaves blank — see ❓Q2 |

Row-count differences are the two deleted rows in §2.3.

## 4. Data-integrity findings

### 4.1 Four participants were randomised into *both* conditions  ❓Q1

`sonaID` 6, 63, 47 and 118 each appear at baseline under **both**
Choice and Nature, and completed booster sessions under both. `118` did it with
two email addresses differing only by a dot in the local part, which is how the
double enrolment escaped a roster keyed on exact address.

Booster sessions split roughly evenly across the two arms (e.g. 6: 9 Choice /
8 Nature). In the original pipeline the condition each ended up in was decided
by whichever baseline row happened to sort first — i.e. **arbitrary**.

`01_assemble.R` leaves their `Condition` blank and writes
`output/dual_enrolments.csv` for review. **Needs a decision before `02_clean.R`.**

### 4.2 Duplicate baseline submissions ❓Q2

48 baseline rows have a blank `Condition` in the workbook. These are not all the
same thing — several are **repeat baseline submissions by the same person**
(`sonaID` 153 has *three* baseline rows; 137, 130 and others have two).

The original script's ordering is:

```r
# 1. drop duplicate sonaIDs, keeping whichever sorted first
# 2. drop Progress != 100
# 3. drop is.na(Condition)
```

Because dedup runs *before* the `Condition` filter, a participant whose retained
row is the one missing `Condition` is dropped from the study entirely — even
though their other baseline row was complete and assigned. The blank-`Condition`
field is doing exclusion work incidentally rather than by design.

I have **not** changed this yet, because filling those conditions in would change
the analysed sample. Needs a decision.

### 4.3 Latent bug in the duplicate-removal loop

```r
dupeList = vector()
for (thisrow in 2:nrows) { ... }
baseData = baseDataSorted[-dupeList,]
```

If `dupeList` is ever empty, `-numeric(0)` selects **no rows** and the data frame
is silently emptied. It works on the current data only because duplicates
happen to exist in all three files. Being replaced with an explicit
`distinct()`/`slice()` in `02_clean.R`.

## 5. Discrepancies between the manuscript and the analysis code

### 5.1 The preregistered within-session composite cannot be computed ❗ ❓Q3

The manuscript's Data Analysis section states:

> At the within-session level, well-being was calculated by taking the average
> change in participants' responses on **four visual analogue scales** that
> measured stress, mood, arousal, and life satisfaction before and after each
> booster session.

The booster survey collects **four** pre-session VAS but only **three**
post-session:

| Construct        | Pre-session      | Post-session |
|------------------|------------------|--------------|
| Stress           | `PreStress`      | `poststress` |
| Arousal          | `PreArousal`     | `postenergy` |
| Valence / mood   | `PreValence`     | `postmood`   |
| Life satisfaction| `PreSatisfaction`| **absent**   |

So the four-scale change composite was never computable, and the analysis code
does something different: it models **stress, arousal and valence separately**,
which is what Table 2 and Table 3 actually report. The Results text is
consistent with the code; only the Data Analysis section describes the
uncomputable composite.

This is a deviation a reviewer is likely to catch. It needs a sentence in Data
Analysis explaining that post-session life satisfaction was not collected and
that the three remaining scales were modelled separately.

### 5.2 Table cross-references don't resolve ❓Q4

The Results text cites tables that don't line up with the appendix:

| Results text says | Appendix has | Appears to mean |
|-------------------|--------------|-----------------|
| "relative score … (see Table 5)" | Table 4 = *Relative Preference* | **Table 4** |
| "study phase … (see Table 5 and 6)" | Table 5 = *Study Phase Effects* | **Table 5** (and a 2nd table that may be missing) |
| "baseline well-being … (see Table 7)" | Table 6 = *Baseline WB Moderator* | **Table 6** |

There are 6 tables in the appendix and the text refers to a Table 7. Also, the
"Did Participants Choose their Original Preferred Interventions?" section has an
unresolved authoring note in place of a citation:

> (see Table [make table for this as it is just a raw score on the results doc or
> we could use the graph])

### 5.3 H2 result doesn't name its outcome ❓Q4

> A significant interaction between preference and session time was found,
> b = 0.11, 95% CI [0.00; 0.22], p = .042. However, no significant interactions
> were found for stress … or mood …

The significant effect is never identified as **arousal**. From the code
(`lm.H2.arousal`) and the Discussion ("baseline preference significantly
moderated changes in arousal") it clearly is. Reads as a dropped word.

### 5.4 Sample-size figures need reconciling ❓Q5

| Source | Figure |
|--------|--------|
| Manuscript abstract & participants | n = 161 |
| Script comment, final analysed | "Choice 66 Nature 57" = **123** |
| Script comment, two lines later | `length(unique(demoData$id))` = **124** |

66 + 57 = 123, not 124. The manuscript reports no final analysed N at all — it
reports 161 (post-attention-check baseline) and then never states how many
participants the models were actually fit on. Reviewers will ask. The CONSORT
figure presumably has it; I haven't seen the figure file.

## 6. Bugs in the analysis script

Line numbers refer to `Analyses/WC_Analysis_March23_2026_Cleanup2.R`.

| Line | Issue | Effect |
|------|-------|--------|
| 770 | `lm.belong.complete = lmer(Neg ~ Time * boosterCompletions …)` — outcome should be `Belong` | The "belonging" column in that `tab_model` is a duplicate of the `Neg` model. Not reported in the paper. |
| 1189 | `HiPos = basePos > median(completeData$Pos)` | Median taken over *both* timepoints instead of baseline. Inconsistent with the other nine `Hi*` splits. |
| 1190 | `HiNeg = baseNeg > median(completeData$Neg)` | Same. |
| 1196 | `HiSatisfaction = Satisfaction > median(Satisfaction)` | Uses *current* rather than baseline satisfaction — not a baseline moderator at all. |
| 1181–1196 | `median()` called without `na.rm = TRUE` | Any `NA` makes the median `NA` and the whole split `NA`. |
| 488 | `postKeys = make.keys(baseData, …)` builds the Post scoring key from **`baseData`** | Works only because `scoreItems()` matches on item names; fragile and confusing. Should be `postData`. |
| 155–165 etc. | duplicate-removal loop (see §4.3) | Silent data loss if no duplicates. |

None of these are in the critical path for the results the paper reports, with
the possible exception of line 488 — **which I still need to verify produces
identical Post scale scores.** That check is on the list for `03_score.R`.

## 7. Method decisions I plan to carry forward unchanged

Recording these so they're explicit rather than implicit:

- **WB composite** = first component of a PCA over `BIPS`, `WHO5`, `PHQ`, `Pos`,
  `Neg`, sign-flipped so higher = better. Fitted on baseline and post rows
  **stacked**, so the component is defined once across both timepoints rather
  than separately per wave. Defensible, but should be stated in the manuscript.
- **Adherence** = ≥ 8 of 12 booster sessions (preregistered "two-thirds").
- **Attention checks** = ≥ 3 of 4 correct. Applied at baseline (2 exclusions);
  no one failed at post.
- **Study phase** mapping for the Choice arm: days 1–7 Mindfulness, 8–14 Breath,
  15–21 Journal, 22+ Choice.
- **Phase contrasts**: `FixedVsChoice` (−1,−1,−1,3), `JournalVsMindBody`
  (−1,−1,2,0), `BreathVsMindfulness` (−1,1,0,0). These are orthogonal — good.

## 8. Sample-size reconciliation ✅

`02_clean.R` reproduces the published sample exactly, with every remaining
difference accounted for. I re-ran the original script's own exclusion chain
against `Analyses/FullData.xlsx` to get its true numbers rather than trusting
its comments.

| | Original code | Pipeline | Difference |
|---|---|---|---|
| Baseline, randomised & eligible | **162** (Choice 82, Nature 80) | **158** (Choice 80, Nature 78) | −4 dual enrolments |
| Adherent (≥ 8 sessions) | 129 | 125 | −4 |
| **Final analysed** | **124** (Choice 66, Nature 58) | **120** (Choice 63, Nature 57) | −4 |

The final-sample difference is exactly four named participants:

- **47, 6, 63** — dual enrolments (decision Q1). The fourth,
  118, did not reach the original's final sample anyway.
- **107** — the adherence double-count described in §8.2 below.

### 8.1 The manuscript's reported *n* is wrong

The paper states **n = 161** in both the abstract and Participants. The original
script's own chain yields **162**. The 161 comes from a stale code comment
(`#82 / 79`) that no longer matches what the code does — the actual split is
82 / 80. **The manuscript needs correcting regardless of which other decisions
are taken.**

The manuscript also never reports the final analysed *N* — it reports 161 and
then presents models fitted on ~124 people. A reviewer will ask. Recommend
stating both, plus the CONSORT attrition path.

### 8.2 Adherence was counted on duplicated sessions ❗

In the original script the order of operations is:

```r
# line 216  boosterCompletion <- table(intData$sonaID)   # <- adherence counted here
# line 523  intData <- intData[-dupeList, ]              # <- duplicate id x day removed HERE
```

Adherence is computed **before** duplicate `id × StudyDay` sessions are removed,
so a participant who submitted the same study day twice is credited with two
sessions. **sonaID 107** clears the ≥ 8 threshold this way on only **7 distinct
study days**, and is included in the published analysed sample as a result.

Three booster rows in total are duplicate `id × day` submissions. 107 is the
only participant whose *adherence status* changes once they are removed.

The pipeline counts distinct study days and asserts uniqueness before counting.

### 8.3 Attention checks must be applied before deduplication ❗

sonaID **101** submitted the baseline twice, three minutes apart — failing the
attention checks on the first attempt (1 of 4 correct) and passing on the second
(4 of 4). Whether this participant is retained therefore depends entirely on
which submission the dedup step happens to keep, and the original script keeps
whichever sorted first.

A failed attention check invalidates a *submission*, not a *person*. The
pipeline filters invalid rows first and deduplicates second, which makes the
result independent of row order. 101 is correctly retained.

This reordering also changes the headline attention-check exclusion count: 3
submissions fail (not 2), but only 1 participant is lost, because 101 has a
valid retake.

## 9. Scoring findings (`03_score.R`)

### 9.1 Reliabilities reproduce the manuscript ✅

Computed on the analysed sample (n = 120):

| Scale | Pipeline (base / post) | Manuscript | |
|---|---|---|---|
| BIPS | .872 / .840 | .87 / .84 | ✅ |
| PHQ-4 | .865 / .822 | .87 / .83 | ✅ |
| WHO-5 | .833 / .811 | .82 / .81 | ✅ |
| Positive affect | .714 / .818 | .72 / .81 | ✅ |
| Negative affect | .807 / .793 | .81 / .78 | ✅ |
| Belonging | .743 / .821 | .75 / .82 | ✅ |

The **preference** composites differ slightly — pipeline .762 / .772 / .850 /
.776 (mindfulness / breath / journalling / nature) vs. manuscript .78 / .80 /
.83 / .77. These were almost certainly computed on the full baseline sample
rather than the analysed subset. Worth confirming which sample the manuscript
intends to report; the numbers move either way once N changes.

### 9.2 The post-survey scoring-key bug is harmless ✅

Line 488 of the original builds the *post* key matrix from `baseData`. This is
safe only because `psych::scoreItems()` matches keys to items by name. I built
each key from the frame it scores and asserted the results are identical — they
are, so **published scale scores are unaffected**. Fixed anyway, since it breaks
silently the moment the two surveys diverge.

### 9.3 The PCA sign flip was fragile ❗

The original fixes the composite's orientation with a hard-coded
`WB = -1 * WB.pca$scores`. The sign of a principal component is arbitrary and
sample-dependent, so any change to the analysed sample could silently invert the
primary outcome — turning "well-being" into "distress" with no error raised.

The pipeline orients the component by requiring a positive correlation with
WHO-5 and asserts the expected loading pattern. On the current sample the
component explains **54.7%** of variance with loadings BIPS −0.87, WHO-5 +0.71,
PHQ −0.83, Positive +0.46, Negative −0.76 — one clean bipolar well-being
dimension, consistent with the manuscript's single-factor decision.

### 9.4 One booster session in the choice week captured no practice data ❗❗

On **study days 24 and 25**, the booster survey recorded *no* practice-selection
information at all: no `ChooseActiveVid` / `ChooseNatureVid`, no per-video page
timings, and none of the choice-week preference items. The pre- and post-session
ratings came through intact. This is the **same session on which `Condition`
failed to pipe** (§2.1), so it looks like a survey-flow fault on one session of
the choice week rather than participant behaviour.

It accounts for **106 of the 109** sessions whose practice cannot be identified
(the remaining 3 are scattered singletons, plus one session where two practice
blocks were both touched — sonaID 55, day 23 — left unclassified as genuinely
ambiguous).

**Why this matters.** The original script filtered `!is.na(Training)` once, up
front, so these sessions were removed from *every* downstream analysis. That is
correct for H2, which needs to know which practice was practised. It is **not**
correct for the exploratory study-phase comparisons, where phase is a function of
`StudyDay` alone — dropping them discards about a third of the choice week for
no reason, and the choice week is exactly what those analyses are about.

The pipeline keeps `Training = NA` rows in `session_long.csv` and lets each
analysis filter on what it actually requires. **This will change the exploratory
choice-week results** (the reported *b* = −0.03, *p* = .046 for stress and
*b* = 0.07, *p* < .001 for valence), which were computed on the reduced set.
Before/after comparison to follow in `06_exploratory.R`.

## 10. Results: pipeline vs. published

Analysed sample **n = 120** (WC 63, CN 57) for study-level models; session-level
models use all **125 adherent** participants, since they do not require the
post-intervention survey.

### 10.1 H1 — unchanged ✅

| Effect | Published | Pipeline | |
|---|---|---|---|
| WB: Time | −0.01, *p* = .911 | −0.030, *p* = .765 | ns both |
| WB: Condition | 0.06, *p* = .750 | −0.015, *p* = .936 | ns both |
| WB: Time × Condition | 0.16, *p* = .257 | 0.182, *p* = .213 | ns both |
| Stress: session time | −0.38, *p* < .001 | −0.330, *p* < .001 | ✅ |
| Arousal: session time | 0.26, *p* < .001 | 0.244, *p* < .001 | ✅ |
| Valence: session time | 0.33, *p* < .001 | 0.309, *p* < .001 | ✅ |
| Arousal: Condition × session time | −0.21, *p* = .014 | **−0.190, *p* = .0266** | ⚠️ |

**Every H1 conclusion holds.** The one caveat is the arousal interaction. The
manuscript preregisters Holm-Bonferroni for two a priori comparisons, giving an
adjusted threshold of **.025**. At *p* = .014 it cleared that; at *p* = .0266 it
does not. It remains nominally significant at .05 but should no longer be
described as surviving correction.

### 10.2 H2 — the significant effect no longer reaches .05 ❗

| Effect | Published | Pipeline | |
|---|---|---|---|
| **Arousal × preference** | **0.11, *p* = .042** | **0.107, *p* = .0509** | ⚠️ changed |
| Stress × preference | −0.04, *p* = .310 | −0.044, *p* = .302 | ✅ |
| Valence × preference | 0.02, *p* = .671 | 0.013, *p* = .765 | ✅ |
| Arousal × relative preference | 0.09, *p* = .097 | 0.088, *p* = .105 | ✅ |
| Stress × relative preference | −0.04, *p* = .356 | −0.036, *p* = .398 | ✅ |
| Valence × relative preference | 0.03, *p* = .521 | 0.025, *p* = .572 | ✅ |

The **estimate barely moves** (0.11 → 0.107); only the *p*-value crosses the
threshold, from .042 to .0509, driven by the four excluded participants. This is
a knife-edge result either way, and it never approached the preregistered .025
threshold. The honest description is that H2 was **not supported**.

### 10.3 Exploratory — two changes

| Effect | Published | Pipeline | |
|---|---|---|---|
| Choice vs fixed: stress (session baseline) | −0.03, *p* = .046 | −0.044, *p* = .032 | ✅ stronger |
| Choice vs fixed: valence | 0.07, *p* < .001 | 0.073, *p* < .001 | ✅ |
| Choice vs fixed: arousal | 0.04, *p* = .056 | **−0.005, *p* = .847** | ⚠️ estimate collapsed |
| Journal vs mind-body × session time: stress | 0.08, *p* = .032 | **0.070, *p* = .0546** | ⚠️ changed |
| Practice selection ← relative preference | 0.55, *p* = .006 | 0.587, *p* = .004 | ✅ |

The two changes both stem from **restoring the day 24–25 choice-week sessions**
(§9.4) that the original dropped for lack of a `Training` label. The arousal
estimate in particular collapses from 0.04 to −0.005 once the full choice week is
included — the published near-significant trend was an artefact of analysing
roughly two-thirds of the choice week.

### 10.4 The baseline-moderator analysis is structurally degenerate ❗❗

This one needs attention before submission.

`baseWB` is the participant's baseline WB, and at `Time == "Baseline"` the
outcome `WB` **is that same number** (verified: max difference = 0). Consequences:

1. Baseline rows are fitted exactly — residual SD ≈ 6 × 10⁻⁹, random-intercept
   variance ≈ 5 × 10⁻⁵. **lme4 reports a singular fit**, so the standard error
   and *p*-value are not trustworthy.
2. The interaction is not an independent result. It is algebraically the ANCOVA
   slope minus one:

   | | |
   |---|---|
   | `Post ~ Baseline` slope | 0.655 (SE 0.064) |
   | slope − 1 | **−0.345** |
   | `TimePost:baseWB` from the mixed model | **−0.345** |

   A slope below 1.0 on a repeated measure is the **textbook definition of
   regression to the mean**. Equivalently, `cor(change, baseline) = −0.445`.

Without a passive control group, a genuine differential treatment response
cannot be separated from this artefact. The Discussion already hedges
("This pattern could also reflect regression to the mean"), but the **Abstract
states it as a finding**: *"Participants with lower baseline well-being showed
the greatest improvements over time."*

Recommendation: report the ANCOVA parameterisation (non-singular and more
transparent), and downgrade the claim in the Abstract. The published
*b* = −0.55 also does not reproduce (−0.345), because the WB component is
re-estimated on the corrected sample.

---

## Decisions taken (2026-07-19)

| # | Decision | Consequence |
|---|----------|-------------|
| Q1 | **Exclude all four dual-enrolled participants entirely** (6, 63, 47, 118) | Reduces analysed N by up to 4 vs. published. Needs a CONSORT line and one sentence in Participants. |
| Q2 | **Recover `Condition` by `sonaID`**, then dedup baseline keeping the most complete row | Retains participants the original pipeline dropped by accident. **Will change the analysed N vs. the published 123/124** — magnitude reported in §8. |
| Q3 | **Revise the manuscript text to match the code** | Data Analysis to state that post-session life satisfaction was not collected and the three scales were modelled separately. No re-analysis needed. |
| Q6 | **Scope = paper + supplementary** | Unreported exploratory models (multinomial/Poisson choice, the ten `Hi*` splits) are not ported. |

Q1 and Q2 pull in opposite directions on N — Q1 removes up to 4, Q2 adds some
back. The net change against the published numbers is reported in §8 once
`02_clean.R` runs.

---

## Open questions

**❓Q1 — Dual enrolments.** Four participants (6, 63, 47, 118) were
randomised into both conditions and have booster data under each. Options:
(a) exclude all four entirely; (b) keep only their first enrolment and discard
the second arm's sessions; (c) something else. Currently they are flagged and
left unassigned. *This changes the analysed N and should be stated in the paper.*

**❓Q2 — Baseline rows with blank `Condition`.** Should condition be filled in
from the person's booster/post records (which would retain participants the
original pipeline dropped), or should a blank baseline `Condition` continue to
act as an exclusion? Related: what's the intended rule for repeat baseline
submissions — keep first, keep last, or keep the most complete?

**❓Q3 — The four-scale within-session composite.** Post-session life
satisfaction was never collected, so the composite described in Data Analysis
doesn't exist. Do you want me to (a) revise the Data Analysis text to describe
what was actually done (three scales modelled separately), or (b) additionally
compute a three-scale composite as a supplementary analysis closer to the
preregistration's spirit?

**❓Q4 — Manuscript text fixes.** Should I compile a list of text corrections
(table cross-references, the missing "arousal" in the H2 sentence, the unresolved
`[make table for this…]` note) as a separate markdown file for you to apply, or
do you want me editing the `.docx` directly?

**❓Q4 — Manuscript text fixes.** *Resolved.* Applied directly to the `.docx`;
see `MANUSCRIPT_EDITS.md` for all 21 edits and `apply_manuscript_edits.py` for
the script. Backup at `manuscript_June19_BACKUP_preEdit.docx`.

**❓Q5 — Final analysed N.** *Resolved, see §8.* The original code gives 124
(not the 123 in its comments); the corrected pipeline gives **120**. The old
CONSORT figure showed 123 and also carried three errors of its own — see §11.

**❓Q7 — Do the corrected exclusions change the results?** *Resolved, see §10.*
H1 unchanged; H2's one significant effect moves to *p* = .051; two exploratory
results change.

**❓Q8 — Year of study coding.** *Resolved (NF, 2026-07-19).* The item offered
five options in order: first, second, third, fourth, fifth-or-more. The
**display order is sequential but the stored recode values are not** — the raw
export contains 1, 4, 5, 6 and 7, presumably because choices 2 and 3 were
deleted and re-added during survey construction, which shifts the retained
choice IDs. Five stored codes for five options in ascending order gives:

| Code | Year |
|---|---|
| 1 | First |
| 4 | Second |
| 5 | Third |
| 6 | Fourth |
| 7 | Fifth or more |

Frequencies across the full export (122, 41, 10, 3, 2) match a first-year-heavy
undergraduate sample. `07_descriptives.R` now applies this mapping and **errors
out** if an unrecognised code ever appears, rather than silently dropping people.

Counts are unaffected by the fix — the analysed sample contains only first
(*n* = 82), second (*n* = 30) and third years (*n* = 8); the randomised sample
adds ten third-years and one fourth-year. The manuscript's "first (*n* = 107) or
second year (*n* = 40)" is correct as edited, so **no further manuscript change
is needed**.

**❓Q9 — Which sample should the reliabilities describe?** The manuscript's
alphas match the **full eligible sample** (*n* = 158), not the analysed subset —
the preference composites make this unambiguous (breath .800 vs .80, journalling
.826 vs .83, nature .771 vs .77). Both are now in
`output/scale_reliabilities.csv`. Since these are properties of the measures
rather than of the analysed models, reporting them on the full sample seems
right, but the manuscript should say which it uses. Current alphas in the text
remain accurate to two decimals either way, so **no edit was applied**.

**❓Q10 — Age outliers.** Age ranges to 60, and three participants are over 30.
This inflates the WC condition's SD (6.28 vs CN's 1.05) and shows up in the
CONSORT box. Worth a sentence, or a footnote giving the median and range.

---

## 13. Supplementary analyses and round-2 reframing

Three supporting analyses were added (`10_supplementary.R`) and the Discussion,
Limitations, and Concluding Remarks were rewritten to recentre the paper on the
**state-vs-trait transfer** question (`apply_manuscript_edits2.py`;
`MANUSCRIPT_EDITS_ROUND2.md`).

### 13.1 Completer vs. non-completer (`completer_comparison.csv`)

Completers (n = 120) vs. randomised-but-excluded participants (n = 38), on
baseline characteristics:

| Baseline measure | Completer | Non-completer | d | p |
|---|---|---|---|---|
| **WHO-5 well-being** | 5.32 | 4.78 | **0.53** | **.007** |
| BIPS (stress) | 3.81 | 3.92 | −0.15 | .414 |
| PHQ-4 | 2.37 | 2.57 | −0.24 | .209 |
| Positive affect | 3.78 | 3.66 | 0.16 | .398 |
| Negative affect | 3.02 | 3.27 | −0.26 | .189 |
| Belonging | 4.06 | 3.77 | 0.30 | .127 |
| Age | 19.48 | 18.95 | 0.13 | .260 |
| Woman % / CN % | — | — | — | .46 / .52 |

**Selective attrition on well-being:** completers were healthier at baseline
(*d* = 0.53). Reported in Results and interpreted in Limitations (compounds the
ceiling problem — the analysed sample had the least room to improve).

### 13.2 WB composite justification (`wb_parallel_analysis.csv`)

Horn's parallel analysis on the five study-level scales returns **one** component
(the prereg said split into flourishing/distress only if >1 emerged). PC1
explains 54.7%; loadings BIPS +0.87, WHO-5 −0.71, PHQ +0.83, Pos −0.46,
Neg +0.76 — one coherent bipolar dimension. Now stated in Data Analysis and in
the new Deviations subsection.

### 13.3 H2 effect-size bounds (`h2_effect_sizes.csv`)

Standardized preference × session-time interactions, so the null can be read as
"small effect at most" rather than "no effect":

| Outcome | Predictor | std β | 95% CI | p |
|---|---|---|---|---|
| Arousal | Pref | 0.068 | [0.000, 0.137] | .051 |
| Stress | Pref | −0.035 | [−0.101, 0.031] | .302 |
| Valence | Pref | 0.010 | [−0.056, 0.077] | .765 |
| Arousal | Rel. Pref | 0.057 | [−0.012, 0.125] | .105 |

Every |β| ≤ 0.07; the largest upper CI bound is β ≈ 0.14. The revised
Discussion uses this to argue preference is *underpowered, not disproven*, but
any real effect is bounded to small.

### 13.4 Round-2 manuscript changes

Nine paragraph rewrites + two inserted sections (completer paragraph;
"Deviations from the Preregistration"). Framing now: **within-session relief is
real and reliable; the open problem is transfer to trait level; neither choice
nor variety of brief techniques was that mechanism.** Efficacy language scaled to
"relief was reliably observed" (not "caused"); demand characteristics and the
absence of an inactive control featured as the primary limitation; choice-week
attenuation reframed as diminishing returns; H2 nulls bounded by effect size.

### 13.5 APA statistical-symbol italics (`italicize_stats.py`)

A copy-edit pass normalised statistical italics to strict APA 7. The manuscript
had mixed two conventions — some statistical clauses were fully italic (numbers
and all), others fully roman. Both are now consistent:

- **Italic:** Latin statistical symbols — *M*, *SD*, *SE*, *N*, *n*, *p*, *b*,
  *t*, *d*, *r*, *R* (in *R*²), plural *ps*; and the table-note label *Note.*
- **Roman:** numbers, operators, `95% CI`, `ICC`, and — correctly — **Greek
  letters** (β, σ, τ), which APA never italicises.

Symbols are matched only in unambiguous context (before `= < >`, or the suffixes
`age`/`-value`/`2`/` id`), so ordinary letters in words are untouched. Body text
is normalised (symbol italic, numbers roman); table cells are additive only
(symbols italicised, the author's italic header-row style left intact). Verified:
all italic numbers are journal volume numbers in the References (APA-correct); no
body-prose number is italic; bold, table count, and paragraph count unchanged.
Backup: `manuscript_June19_preItalics.docx`.

---

## 14. Final polish (title, abstract, intro, comments, figure)

- **Title** changed to *"Immediate Relief Without Lasting Change: Choice,
  Variety, and the Transfer Problem in Brief Online Well-Being Interventions for
  Undergraduates"* — matches the reframed contribution (the old "The Role of
  Choice" oversold a null result). `apply_final_edits.py`.
- **Abstract** replaced with a reframed structured abstract (~270 words) centred
  on the state-vs-trait dissociation and the transfer problem. Statistical
  symbols italicised (*n*, *p*).
- **Introduction** strengthened in two places so the null has a target to return
  to: the Technology-Supported paragraph now names the *implicit promise* that
  brief practice yields lasting, trait-level change; the Current Study paragraph
  foregrounds the two-level (state vs trait) design and the transfer question.
- **All 4 Word review comments removed** (`strip_comments.py`) — anchor elements
  stripped from document.xml and the five comment parts (comments/commentsExtended/
  commentsIds/commentsExtensible/people.xml) deleted with their rels and
  content-type overrides. Zero comment references remain; clean copy.
- **Figure 1** font enlarged (richtext size 2.9 → 3.8) with the top-right
  exclusion box widened/re-flowed to fit; regenerated and re-embedded (6.5 × 5.2 in,
  byte-verified).
- Fixed an over-broad guard in `italicize_stats.py` (skipped any run containing
  `~`, which wrongly skipped "~6-minute" in the Methods abstract); now only
  spaced formula tildes (` ~ `) are skipped. Body scan confirms **0 missed stat
  symbols**. Backups: `_preFinal.docx`, `_preFigure.docx`.

---

## 12. Appendix tables regenerated

All seven appendix tables were rewritten from the pipeline
(`09_tables.R` → `write_appendix_tables.py`), preserving the manuscript's cell
formatting and merged-header layout. Beyond updating every number, three
structural problems in the June 19 draft were fixed:

### 12.1 Two tables sat under the wrong caption

The captions for the two study-phase tables were swapped relative to their
contents:

- The table captioned **"Study Phase Effects on Pre-Post Session Change Scores"**
  actually contained a model with **no `SesTime` term** — i.e. session *baseline*
  scores, not change scores. Its predictor rows were `Fixed vs. Choice`,
  `Mind-Body vs. Journaling`, `Mindfulness vs. Breathwork`.
- The following table, captioned as the **baseline well-being moderator**,
  actually contained the **pre-post change** study-phase model (its rows were
  `Fixed vs. Choice`, `Journaling vs. Fixed`, `Breathwork vs. Mindfulness`).
- The genuine **baseline well-being moderator** table (referenced in the text as
  "Table 7") **did not exist**.

Corrected mapping: Table 5 = session baseline scores; Table 6 = pre-post change;
Table 7 = baseline well-being moderator (newly created).

### 12.2 Table 6 was missing half its rows

The pre-post change model has **eight** fixed effects (three phase contrasts,
session time, and their four interactions), but the draft table had room for
only four predictor rows and showed just the interactions. It now lists all
eight, so the main effects and interactions are both visible.

### 12.3 Table 7 created

The baseline-moderator table was built by cloning Table 1's single-outcome
layout. Its Note records that the model is a singular fit and that the
interaction equals the ANCOVA slope minus one (see §10.4), so a reader is not
left to rediscover the regression-to-the-mean issue from the coefficient alone.

**Sample-size note:** the study-phase tables now report **N = 65** and up to
**1392 observations**, against the draft's 69 / 1322 and 69 / 661. The increases
come from restoring the day 24–25 choice-week sessions (§9.4); the small drop in
participants (69 → 65) is the dual-enrolment and adherence corrections.

---

## 11. Errors in the old CONSORT figure

The previous Figure 1 had three problems independent of the sample change, so it
has been regenerated from the pipeline (`08_consort_figure.R`):

1. **"93.6% female"** — not reproducible from any sample. The manuscript's own
   text implies 131/161 = 81.4%; the corrected analysed sample is 100/120 =
   83.3%.
2. **The attention-check exclusion didn't balance.** The figure showed
   "Randomized n = 161 (WC 82, CN 79)" then "Excluded (n = 2)" and CN dropping to
   77 — a loss of 2 from CN alone, leaving 159, but the arithmetic was presented
   as though 161 flowed through. The original code in fact yields 82/80 after
   attention checks, so the CN figure of 79 was never right.
3. **Final sample 123 (WC 66, CN 57)** — the code produces 124 (WC 66, CN 58).
   The figure was built from the same stale comments as the manuscript text.

The regenerated figure balances exactly at every node: 163 − 5 = 158;
80 − (3 + 12 + 2) = 63; 78 − (5 + 13 + 3) = 57; 63 + 57 = 120. `02_clean.R`
asserts this, so the figure cannot silently drift from the data again.
