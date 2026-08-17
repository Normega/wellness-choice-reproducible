# Wellness Choice — Reproducible Analysis Pipeline

Rebuilds every number in the manuscript with no manual steps: all tables, the
CONSORT figure, and every sample count.

## For reviewers — start here

Clone the repository and run one command; nothing else is needed.

```
Rscript R/run_all.R
```

The de-identified dataset in `data/` is included, so the pipeline runs from a
fresh clone and regenerates every table, figure and reported statistic into
`output/`. Expect roughly 7 minutes. There is no configuration step and no flag
to set: the identifiable first stage detects that its inputs are absent and
skips itself.

Three things worth knowing while reviewing:

- **`05_h1.R`, `06_h2.R` and `07_exploratory.R` hold the values printed in the
  manuscript** and print a side-by-side comparison as they run, flagging any
  result that changes sign, magnitude or inferential status. Reproducing the
  paper and detecting divergence from it are the same operation.
- **The run ends with a release audit** (`13_release_audit.R`) that scans
  everything publishable and fails the build on anything identifying. A clean
  run means it passed.
- **`ANALYSIS_NOTES.md` is the working log**, including data-integrity problems
  found in the original analysis and the decisions taken about them. Participant
  numbers there are the released study IDs, so any claim can be checked against
  `data/`.

Raw data and the identifiable stage are withheld under the study's ethics
approval — see **What may be published** below. `data/` is exactly what that
withheld stage produces, so nothing needed to reproduce the paper is missing.

The pipeline has **two stages separated by a de-identification boundary**. The
second stage is self-contained, so the released dataset is a complete
reproduction package — a third party needs nothing that is withheld.

```
RawData/  ──01_assemble──▶  private/tidy/  ──02_deidentify──▶  data/  ──03…13──▶  output/
   │                            │                                │                   │
 withheld                    withheld                        RELEASED            RELEASED
```

## Running it

```
"C:/Program Files/R/R-4.5.2/bin/Rscript.exe" R/run_all.R
```

`run_all.R` detects which stage it can run. With `RawData/` and `private/`
present it runs everything; without them it starts from `data/` and reproduces
every published number. **No flag to set** — a released copy simply works.

Paths are derived from the scripts' own location, so a clone works wherever it
is put. To override, set the `WC_PROJ_ROOT` environment variable (or define
`projRoot` before sourcing `00_config.R`).

**R 4.5.2.** Installed here but not on `PATH`; use the full path. Packages:
`readxl`, `writexl`, `dplyr`, `tidyr`, `tibble`, `psych`, `lme4`, `lmerTest`,
`emmeans`, `ggplot2`, `ggforce`, `ggpubr`, `sjPlot`, `MASS`, `ordinal`,
`sandwich`. `00_config.R` fails loudly if any is missing. The exact environment
of the last run is recorded in `output/session_info.csv`.

## What may be published

| Path | Publish? | Contents |
|---|---|---|
| `R/` | **yes** | Every script, both stages |
| `data/` | **yes** | The de-identified dataset — the entry point |
| `output/` | **yes** | All tables, figures, audit reports |
| `*.md` | **yes** | Documentation (except `PEER_REVIEW.md`) |
| `RawData/` | **no** | Raw Qualtrics exports |
| `private/` | **no** | Staff emails, identifiable tidy data, **the ID crosswalk** |
| `*.py` | **no** | One-off manuscript `.docx` editors; reproduce no analysis |
| `PEER_REVIEW.md` | **no** | Internal pre-submission self-critique |

`private/README.md` restates this. `.gitignore` excludes both withheld paths.

## Pipeline

### Stage 1 — identifiable (not distributed)

| Script | Does | Key outputs |
|---|---|---|
| `01_assemble.R` | Raw exports → tidy CSVs; repairs unresolved Qualtrics placeholders; recovers condition assignments | `private/tidy/*.csv` |
| `02_deidentify.R` | **The release boundary.** Drops staff responses, identifiers and timestamps; replaces participant numbers with arbitrary IDs; redacts free text; verifies the result | `data/{baseline,booster,post}.csv` |

### Stage 2 — de-identified (everything needed to reproduce the paper)

| Script | Does | Key outputs |
|---|---|---|
| `00_config.R` | Paths, packages, Qualtrics recode repairs, study-phase contrasts | — |
| `03_clean.R` | All participant exclusions; auditable CONSORT flow | `data/*_clean.csv`, `output/consort*.csv` |
| `04_score.R` | Scale scoring, reliabilities, WB composite, long analysis frames | `data/prepost_long.csv`, `session_long.csv`, `preferences.csv` |
| `05_h1.R` | Hypothesis 1, all three levels (Tables 1–2) | `output/h1_*.csv` |
| `06_h2.R` | Hypothesis 2 (Table 3, S3) | `output/h2_*.csv` |
| `07_exploratory.R` | Study-phase, practice-selection, baseline-moderator analyses | `output/expl_*.csv` |
| `08_descriptives.R` | Demographics and descriptive tables | `output/demographics.csv`, `descriptives_*.csv` |
| `09_consort_figure.R` | Draws Figure 1 from the computed counts | `output/Figure1_CONSORT.png` |
| `10_tables.R` | Cell contents for every appendix/supplementary table | `output/table_cells.csv` |
| `11_supplementary.R` | Completer comparison, parallel analysis, WHO-5 clinical metrics, scale-by-scale change, standardized H2 effect sizes | `output/completer_comparison.csv`, `who5_clinical.csv`, `scale_by_scale_change.csv` |
| `12_multiplicity.R` | Explicit Holm-Bonferroni correction | `output/holm_correction.csv` |
| `13_release_audit.R` | **Fails the build** if anything identifying is publishable | `output/release_audit.csv` |

Each script is standalone and runs in a fresh environment under `run_all.R`, so
no step can depend on objects left behind by another.

## De-identification

`02_deidentify.R` is the only script that sees both identifiers and released
data. In order, it:

1. **Removes study-staff test responses.** This has to happen here: the
   exclusion is keyed on email, and email does not cross the boundary.
2. **Drops direct identifiers** — names, email addresses, IP addresses,
   geolocation, Qualtrics response GUIDs, external references.
3. **Replaces the institutional participant number** with an arbitrary study ID
   drawn in a seeded random order, so released IDs encode nothing, not even
   enrolment order. The crosswalk is written to `private/` only.
4. **Redacts free text while preserving whether a response was given** —
   `04_score.R` infers which practice a participant did from whether the
   journalling prompts were filled in, so the presence bit must survive even
   though the content must not.
5. **Replaces submission timestamps with a submission-order rank, and drops
   every remaining calendar date.** The only downstream use of a timestamp is
   ordering duplicate submissions; a rank preserves that exactly and removes the
   clock. Two Qualtrics embedded-data fields also carried the session date
   (`CurrentDate`, and `SumScore` despite its name); neither is read by any
   analysis script, and both are dropped, because a per-participant sequence of
   session dates is a quasi-identifier against the released demographics.
6. **Re-scans its own output and refuses to write** if anything identifying
   survives — including any surviving calendar date, which is short enough to
   pass a free-text length check.

`13_release_audit.R` then scans the entire release surface — `data/`, `output/`,
*and the published documentation and scripts* — and fails the build on any
finding. It exists because step 6 can
only guarantee the files that script writes, not the directory they land in.
That is not hypothetical: an earlier version of `01_assemble.R` wrote a
dual-enrolment report containing five participant email addresses to `output/`,
and when that write moved to `private/`, the already-written file stayed behind.
Correct code, stale artefact, live PII in the publication directory. Scanning
the artefacts is the only check that survives the code changing underneath them.

The audit reads the prose as well as the data, because documentation is
published too and nothing sanitises it on the way out. Identifiers reach a
release surface by being *quoted* as readily as by being computed: an audit
restricted to `data/` and `output/` will not see a participant's email address
in a sentence explaining a duplicate enrolment.

## Design notes

**Nothing is hard-coded.** The original analysis contained several manual
patches — two participants' conditions assigned by ID, a sign flip on the PCA
composite, an Excel workbook assembled by hand. Each is now derived from the
data and asserted, so the pipeline fails loudly rather than drifting silently.

**Qualtrics recode values are repaired, not trusted.** Four scored items export
on code sets that differ from what participants saw (WHO-5, PHQ-4, and two
preference dimensions). All are mapped back to their instruments' metrics,
verified against the survey definition file, with assertions that halt the run
if a future export changes shape. See `METHODS_EDITS.md`.

**Published values are encoded as comparisons.** `05_h1.R`, `06_h2.R` and
`07_exploratory.R` each hold the values printed in the current manuscript and
print a side-by-side comparison, flagging any result that changes sign,
magnitude or inferential status. Reproducing the paper and detecting divergence
from it are the same operation.

**Assertions guard the invariants.** Sample sizes, CONSORT branch totals,
composite orientation, contrast scaling (checked against `emmeans`), and the
absence of duplicate sessions are all checked with `stopifnot()`.

**One number is not bit-stable across re-releases.** The practice-selection
permutation test draws group by group, so its RNG stream depends on participant
ID order — which is assigned arbitrarily at the release boundary. It is fully
deterministic for a fixed dataset; `B` = 50,000 keeps the Monte Carlo error
below the reported precision. Every other output is byte-identical across runs.

## Where to look

- **`METHODS_EDITS.md`** — the July 28 methods revision: contrast scaling, scale
  direction, the multiplicity family, the WHO-5/PHQ-4/preference recodes, and
  the BIPS reverse-keying bug, with before/after values.
- **`ANALYSIS_NOTES.md`** — the working log: manual steps, data-integrity
  findings, bugs in the original script, full results comparison.
- **`MANUSCRIPT_EDITS.md`** — every change applied to the manuscript.
- **`private/README.md`** — what is withheld and why.

## Headline findings

The analysed sample is **120** (WC 63, CN 57), not the 124 the original code
produced or the 123 its comments claimed. H1 is unchanged and null at every
level. **H2 is null** (arousal *p* = .058, nothing surviving correction). The
robust result is a reliable *within-session* improvement in stress, mood and
arousal in both arms that does not accumulate into trait-level change. The
baseline-well-being moderation is algebraically equivalent to regression to the
mean. On its own metric the sample scored **46.7** on the WHO-5 percentage
scale — below the ≤50 screening threshold — so the null is not a ceiling
artefact. See `ANALYSIS_NOTES.md` §8–10 and `METHODS_EDITS.md`.
