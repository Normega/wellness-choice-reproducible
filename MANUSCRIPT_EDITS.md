# Manuscript Edits Applied

Applied to `Drafts/june19_2026/manuscript_June19.docx` on 2026-07-19 by
`apply_manuscript_edits.py`. Backup: `manuscript_June19_BACKUP_preEdit.docx`.

All 21 edits below were verified as applied. Statistical values come from the
reproducible pipeline; see `ANALYSIS_NOTES.md` sections 8-10 for derivations.

---

## Abstract / Methods

### Edit 1

**Why:** Randomised N corrected; the published 161 came from a stale code comment, and four dual-enrolled participants are now excluded.

**Before:**

> Undergraduate students (n = 161) were randomly assigned

**After:**

> Undergraduate students (n = 158) were randomly assigned

---

## Abstract / Results

### Edit 2

**Why:** H2 arousal moderation is no longer significant (p = .051). The baseline-well-being finding is algebraically equivalent to a regression-to-the-mean artefact.

**Before:**

> except for increasing arousal effects of sessions in the Wellness Choice condition. Match to stronger baseline preferences were associated with marginally greater arousal but not well-being. Participants with lower baseline well-being showed the greatest improvements over time.

**After:**

> except for greater within-session increases in arousal in the Wellness Choice condition. Stronger baseline preference for a technique was not reliably associated with greater benefit from practising it. Participants with lower baseline well-being appeared to improve most over time, but this pattern could not be distinguished from regression to the mean.

---

## Participants

### Edit 3

**Why:** Recomputed on the corrected randomised sample.

**Before:**

> Undergraduate students (n = 161) from [institution withheld for review] (Mage = 19.33, SDage = 4.08) were recruited

**After:**

> Undergraduate students (n = 158) from [institution withheld for review] (Mage = 19.35, SDage = 4.11) were recruited

---

### Edit 4

**Why:** Counts recomputed; final analysed N added, which the manuscript previously never stated despite fitting models on it.

**Before:**

> Most participants were in their first (n = 110) or second year (n = 40) of study and identified as female (n = 131).

**After:**

> Most participants were in their first (n = 107) or second year (n = 40) of study and identified as female (n = 129). After exclusions for non-adherence and missing post-intervention data, 120 participants (WC n = 63, CN n = 57) were retained for analysis; see Figure 1.

---

## Data Analysis

### Edit 5

**Why:** The preregistered four-scale composite is not computable: post-session life satisfaction was never collected. The analyses always modelled the three scales separately; only this paragraph described otherwise.

**Before:**

> At the within-session level, well-being was calculated by taking the average change in participants’ responses on four visual analogue scales that measured stress, mood, arousal, and life satisfaction before and after each booster session. All scales were reverse coded where necessary so that higher values consistently indicated better well-being. The difference between pre- and post-session scores represented within-session change.

**After:**

> At the within-session level, participants completed four visual analogue scales measuring stress, mood, arousal, and life satisfaction before each booster session. The post-session check-in repeated the stress, mood, and arousal scales but did not include life satisfaction, so the four-scale change composite specified in the preregistration could not be computed. Within-session change was therefore analysed separately for stress, mood, and arousal. All scales were reverse coded where necessary so that higher values consistently indicated better well-being, and the difference between pre- and post-session scores represented within-session change.

---

## Results / H1 study

### Edit 6

**Why:** Re-estimated on the corrected sample. Conclusion unchanged.

**Before:**

> b = -0.01, 95% CI [-0.20; 0.18], p = .911, or condition, b = 0.06, 95% CI [-0.30; 0.41], p = .750. The interaction between time and condition was nonsignificant, b = 0.16, 95% CI [-0.12; 0.44], p = .257.

**After:**

> b = -0.03, 95% CI [-0.23; 0.17], p = .765, or condition, b = -0.02, 95% CI [-0.38; 0.35], p = .936. The interaction between time and condition was nonsignificant, b = 0.18, 95% CI [-0.10; 0.47], p = .213.

---

## Results / H1 daily

### Edit 7

**Why:** Re-estimated. All three within-session effects remain highly significant.

**Before:**

> significantly lower stress, b = -0.38, 95% CI [-0.47; -0.28], p < .001, significantly higher arousal, b = 0.26, 95% CI [0.14; 0.37], p < .001, and mood, b = 0.33, 95% CI [0.24; 0.43], p < .001.

**After:**

> significantly lower stress, b = -0.33, 95% CI [-0.42; -0.24], p < .001, significantly higher arousal, b = 0.24, 95% CI [0.13; 0.36], p < .001, and mood, b = 0.31, 95% CI [0.22; 0.40], p < .001.

---

### Edit 8

**Why:** Re-estimated. Also fixes an internal contradiction (the original said there were no significant interactions, then reported one) and the reversed inequality 'p < .498'. Flags that p = .027 no longer clears the preregistered .025 threshold.

**Before:**

> There were no significant main effects of condition across outcomes (p < .498) and no significant interactions between condition and session time. However, there was a significant interaction between condition and session time for arousal, b = -0.21 95% CI [-0.39; -0.04], p = .014, such that participants in the WC condition experienced greater increases in arousal across booster sessions compared to participants in the CN condition.

**After:**

> There were no significant main effects of condition across outcomes (all ps > .33). There was a significant interaction between condition and session time for arousal, b = -0.19, 95% CI [-0.36; -0.02], p = .027, such that participants in the WC condition experienced greater increases in arousal across booster sessions compared to participants in the CN condition; this effect did not survive Holm-Bonferroni correction for the two a priori comparisons. No other condition by session time interactions approached significance (ps > .69).

---

## Results / H2

### Edit 9

**Why:** The estimate barely moves (0.11 -> 0.107) but p crosses .05. Also names the outcome, which the original sentence omitted.

**Before:**

> A significant interaction between preference and session time was found, b = 0.11, 95% CI [0.00; 0.22], p = .042. However, no significant interactions were found for stress (b = -0.04, 95% CI [-0.13; 0.04], p = .310) or mood (b = 0.02, 95% CI [-0.07; 0.11], p = .671).

**After:**

> The interaction between preference and session time for arousal was not significant, b = 0.11, 95% CI [0.00; 0.21], p = .051. No significant interactions were found for stress (b = -0.04, 95% CI [-0.13; 0.04], p = .302) or mood (b = 0.01, 95% CI [-0.07; 0.10], p = .765).

---

## Results / H2 relative

### Edit 10

**Why:** Cross-reference corrected (Table 5 -> Table 4) and estimates updated.

**Before:**

> (see Table 5). The interaction between relative preference and session time was not statistically significant, b = 0.09, 95% CI [-0.02; 0.19], p = .097. Interactions were also nonsignificant for stress (b = -0.04, 95% CI [-0.23; 0.04], p = .356) and mood (b = 0.03, 95% CI [-0.06; 0.11], p = .521).

**After:**

> (see Table 4). The interaction between relative preference and session time was not statistically significant, b = 0.09, 95% CI [-0.02; 0.19], p = .105. Interactions were also nonsignificant for stress (b = -0.04, 95% CI [-0.12; 0.05], p = .398) and mood (b = 0.03, 95% CI [-0.06; 0.11], p = .572).

---

## Results / exploratory phase

### Edit 11

**Why:** Cross-reference corrected; the appendix has six tables, and Table 5 is the study-phase table.

**Before:**

> (see Table 5 and 6).

**After:**

> (see Table 5).

---

### Edit 12

**Why:** Re-estimated with the full choice week restored (see below). The arousal trend (p = .056) disappears entirely once the omitted sessions are included.

**Before:**

> participants reported significantly lower stress during the choice week compared to the three fixed practice weeks (b = -0.03, 95% CI [-0.06; -0.00], p = .046), and significantly higher valence during the choice week (b = 0.07, 95% CI [0.04; 0.11], p < .001). No significant difference was found for arousal, b = 0.04, 95% CI [-0.00; 0.08], p = .056. Within the fixed practice weeks, there were no significant differences between journaling and the two mind-body practices (mindfulness and breathwork), nor between mindfulness and breathwork, for any outcome (all ps > .111).

**After:**

> participants reported significantly lower stress during the choice week compared to the three fixed practice weeks (b = -0.04, 95% CI [-0.08; -0.00], p = .032), and significantly higher valence during the choice week (b = 0.07, 95% CI [0.03; 0.11], p < .001). No significant difference was found for arousal, b = -0.01, 95% CI [-0.05; 0.04], p = .847. Within the fixed practice weeks, there were no significant differences between journaling and the two mind-body practices (mindfulness and breathwork), nor between mindfulness and breathwork, for any outcome (all ps > .092).

---

### Edit 13

**Why:** Two changes, both from restoring study days 24-25 (the booster survey recorded no practice-selection data on those days, so the original analysis dropped roughly a third of the choice week). The journaling contrast falls below significance; a choice-week effect on within-session stress change emerges.

**Before:**

> Examining pre- and post-session change scores, there was a significant interaction between journaling versus the mind-body practices (mindfulness and breathwork) and session time for stress (b = 0.08, 95% CI [0.01; 0.14], p = .032), indicating that stress reductions during sessions were larger during mindfulness and breathwork weeks compared to the journaling week. No significant interactions were found for arousal or valence (all ps > .264), and the choice week did not differ significantly from the fixed practice weeks on within-session change for any outcome (all ps > .741).

**After:**

> Examining pre- and post-session change scores, the interaction between journaling versus the mind-body practices (mindfulness and breathwork) and session time for stress was no longer significant (b = 0.07, 95% CI [-0.00; 0.14], p = .055). There was, however, a significant interaction between the choice week versus the fixed practice weeks and session time for stress (b = 0.06, 95% CI [0.01; 0.11], p = .031), indicating that within-session stress reductions were smaller during the choice week than during the fixed practice weeks. No significant interactions were found for arousal or valence (all ps > .280).

---

## Results / practice selection

### Edit 14

**Why:** Unresolved authoring note removed; the inline statistics carry the result.

**Before:**

> (see Table [make table for this as it is just a raw score on the results doc or we could use the graph])

**After:**

> _(removed)_

---

### Edit 15

**Why:** Re-estimated. Conclusion unchanged and slightly stronger.

**Before:**

> b = 0.55, SE = 0.20, p = .006

**After:**

> b = 0.59, SE = 0.20, p = .004

---

## Results / baseline moderator

### Edit 16

**Why:** Cross-reference corrected (Table 7 -> Table 6) and estimates updated. The caveat is added because baseline well-being appears on both sides of this model, which makes it a singular fit and the interaction a restatement of the ANCOVA slope.

**Before:**

> (see Table 7). A significant interaction between time and baseline well-being was found (b = -0.55, 95% CI [-0.91; -0.20], p = .002). However, the three-way interaction between time, condition, and baseline was not significant (b = -0.17, 95% CI [-0.69; 0.34], p = .507), suggesting that this effect was consistent across both WC and CN groups.

**After:**

> (see Table 6). A significant interaction between time and baseline well-being was found (b = -0.35, 95% CI [-0.47; -0.22], p < .001). The three-way interaction between time, condition, and baseline was not significant (b = -0.09, 95% CI [-0.34; 0.16], p = .487), suggesting that this pattern was consistent across both WC and CN groups. This interaction is, however, algebraically equivalent to the regression of post-intervention on baseline well-being having a slope below 1.0 (b = 0.66, SE = 0.06), which is the expected signature of regression to the mean. Because the design included no passive control group, a differential treatment response cannot be distinguished from this artefact.

---

## Discussion

### Edit 17

**Why:** Hedged to match the corrected p = .027 against the preregistered .025 threshold.

**Before:**

> However, condition only interacted with arousal, with WC participants showing greater increases than CN participants, suggesting that active self-regulation techniques promote greater physiological engagement than passive viewing, consistent with research on breathwork (Balban et al., 2023).

**After:**

> However, condition interacted only with arousal, with WC participants showing greater increases than CN participants. This effect was nominally significant but did not survive correction for multiple comparisons, so it should be treated as suggestive rather than established; it would be consistent with active self-regulation techniques promoting greater physiological engagement than passive viewing (Balban et al., 2023).

---

### Edit 18

**Why:** H2's arousal moderation is no longer significant; the claim is downgraded accordingly.

**Before:**

> Our second aim, whether choosing a preferred technique enhanced training benefits, was also only partially supported: baseline preference significantly moderated changes in arousal, such that stronger initial interest in a technique predicted greater arousal increases after practicing it, potentially reflecting engagement, agency, or competence consistent with self-determination theory (Ryan & Deci, 2000).

**After:**

> Our second aim, whether choosing a preferred technique enhanced training benefits, was not supported. Baseline preference showed a marginal association with within-session arousal change (p = .051), in the direction that stronger initial interest in a technique predicted greater arousal increases after practising it, but this did not reach significance and no effect was observed for stress or mood.

---

### Edit 19

**Why:** Rewritten so it no longer asserts an arousal benefit that the corrected analysis does not support.

**Before:**

> Preference did not, however, significantly predict changes in stress or mood, and a follow-up model using relative preference scores showed a similar but nonsignificant trend. Preferences among similar mind-body techniques may therefore play only a small role in treatment response, enhancing arousal without meaningfully improving emotion regulation.

**After:**

> A follow-up model using relative preference scores showed the same pattern. Preferences among similar mind-body techniques may therefore play little role in immediate treatment response, even though they clearly guided which techniques participants chose.

---

### Edit 20

**Why:** Updated for the corrected exploratory results, including the new choice-week effect on within-session stress change.

**Before:**

> Exploratory analyses of the choice week showed that WC participants reported lower stress and more positive mood, but not different arousal, than in fixed weeks, suggesting autonomy over technique selection may improve affective state specifically rather than activation (Ryan & Deci, 2000). Within the fixed weeks, mindfulness and breathwork produced greater stress reductions than journaling, consistent with mind-body practices supporting acute relief while journaling may operate through more gradual cognitive mechanisms (Balban et al., 2023). However, the choice week did not differ from fixed weeks on within-session change for any outcome, so the affective benefit of autonomy did not extend to session-level improvement.

**After:**

> Exploratory analyses of the choice week showed that WC participants arrived at sessions with lower stress and more positive mood, but not different arousal, than in fixed weeks, suggesting autonomy over technique selection may improve affective state specifically rather than activation (Ryan & Deci, 2000). Within the fixed weeks, the difference in stress reduction between the mind-body practices and journaling was in the expected direction but not significant. Notably, within-session stress reductions were smaller during the choice week than during the fixed weeks, suggesting that the affective benefit of autonomy operated on how participants felt entering a session rather than on how much a session improved their state, and may partly reflect less room for improvement from an already better starting point.

---

### Edit 21

**Why:** Strengthened from 'could also reflect' to the actual statistical position, since the interaction and the regression-to-the-mean artefact are the same quantity.

**Before:**

> Longitudinal effects were not entirely absent: exploratory analyses showed that students with lower baseline well-being improved more over time, consistent across both conditions and suggesting greater capacity for improvement among students with fewer existing coping resources. This pattern could also reflect regression to the mean; a true passive control group would be needed to rule this out.

**After:**

> Exploratory analyses showed that students with lower baseline well-being improved more over time, consistently across both conditions. This pattern is, however, statistically indistinguishable from regression to the mean: the effect is algebraically equivalent to the baseline-to-post regression slope being below 1.0, which is expected whenever a measure is repeated with error. A passive control group would be needed to establish whether it reflects genuine differential responsiveness among students with fewer existing coping resources.

---
