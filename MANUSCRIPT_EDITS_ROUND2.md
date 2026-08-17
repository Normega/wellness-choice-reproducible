# Manuscript Edits — Round 2 (reframing)

Applied 2026-07-19 by `apply_manuscript_edits2.py` after author direction to recentre the
paper on the state-vs-trait transfer question. Backup: `manuscript_June19_preRound2.docx`.

Statistical values from the reproducible pipeline (see `output/completer_comparison.csv`,
`wb_parallel_analysis.csv`, `h2_effect_sizes.csv`).

---

### 1. Data Analysis / PCA

**Before:**

> At the study level, we created a composite well-being score using principal component analysis on standardized scores from the WHO-5, PHQ-4, BIPS, and mood measures. If Horn’s parallel analysis suggested that a two-factor model was more appropriate (i.e., separate flourishing and distress dimensions), we planned to analyze those components separately.

**After:**

> At the study level, we created a composite well-being score using principal component analysis on standardized scores from the WHO-5, PHQ-4, BIPS, and positive and negative affect measures. We had preregistered that, if Horn’s parallel analysis indicated more than one dimension (i.e., separable flourishing and distress components), we would analyze those components separately. The parallel analysis instead supported a single component, which accounted for 54.7% of the variance, with all five measures loading coherently on one bipolar dimension—higher perceived stress, anxiety and depression, and negative affect opposing higher WHO-5 well-being and positive affect. We therefore retained a single well-being composite, oriented so that higher scores indicate better well-being.

---

### 2. Discussion / opening

**Before:**

> Brief, app-based self-regulation training is increasingly popular, appealing to students who prefer flexible, self-guided formats. Yet does it work? The present findings offer limited support: participants showed immediate improvements in mood, arousal, and stress after each booster session, but these effects did not translate into sustained improvements in overall well-being across the four-week period.

**After:**

> Brief, app-based self-regulation training is increasingly popular, appealing to students who prefer flexible, self-guided formats. Yet does it work? The present findings point to a clear dissociation: participants reliably improved in mood, arousal, and stress from the beginning to the end of each booster session, but these repeated moments of relief did not accumulate into sustained gains in overall well-being across the four-week period. The central puzzle these data raise is therefore not whether brief sessions can shift how students feel in the moment—they can—but how, if at all, such state-level relief might be converted into durable, trait-level change. Two intuitively appealing routes to that conversion—letting students choose their preferred technique, and exposing them to a variety of brief techniques—did not appear to provide it.

---

### 3. Discussion / disconnect

**Before:**

> This disconnect between strong within-session effects and limited across-study change suggests these techniques may be better suited to managing acute stress than shifting overall well-being. Even so, scalable, low-commitment strategies that provide immediate relief may offer meaningful support for students facing academic pressure, time constraints, or limited access to services (Moghimi et al., 2023; Wang & Farb, 2023).

**After:**

> This disconnect between reliable within-session relief and the absence of across-study change is the study’s central finding: brief digital sessions appear well suited to managing acute states but, at least at this dose and format, did not transfer into lasting well-being. Identifying what would bridge that gap—more frequent or sustained practice, explicit generalization to real-world stressors, or content that builds cumulatively rather than resetting each session—remains an open and important question. Even without such transfer, scalable, low-commitment strategies that provide immediate relief may offer meaningful support for students facing academic pressure, time constraints, or limited access to services (Moghimi et al., 2023; Wang & Farb, 2023).

---

### 4. Discussion / choice week

**Before:**

> Notably, within-session stress reductions were smaller during the choice week than during the fixed weeks, suggesting that the affective benefit of autonomy operated on how participants felt entering a session rather than on how much a session improved their state, and may partly reflect less room for improvement from an already better starting point.

**After:**

> Notably, within-session stress reductions were smaller during the choice week than during the fixed weeks. Rather than indicating a benefit of autonomy on session-level change, this pattern is more consistent with diminishing returns: after three weeks of practice, participants entered the final week already feeling better and with less room to improve within a session, and any advantage from finally exercising a preference may have been offset by this attenuation. Because the choice week always fell last, its effects are also inseparable from time, cumulative practice, and habituation, and we caution against a strong autonomy interpretation.

---

### 5. Discussion / H2

**Before:**

> Our second aim, whether choosing a preferred technique enhanced training benefits, was not supported. Baseline preference showed a marginal association with within-session arousal change (p = .051), in the direction that stronger initial interest in a technique predicted greater arousal increases after practising it, but this did not reach significance and no effect was observed for stress or mood.

**After:**

> Our second aim, whether preferring a technique enhanced its benefit, was not supported. Baseline preference showed only a marginal association with within-session arousal change (p = .051), such that stronger initial interest predicted larger arousal increases, and no association with stress or mood. We are cautious not to over-read these nulls: the analysed sample fell below the number our power analysis indicated for H2, so the study was underpowered to detect a small preference effect, and the possibility that preference matters should not be dismissed. At the same time, the data bound how large any such effect is likely to be. With outcomes and preference scores standardized, the preference-by-session interactions were small throughout (|β| ≤ 0.07), and even the upper limit of the 95% confidence interval reached only β ≈ 0.14 (for arousal). If a preference-matching effect on immediate response exists, it is therefore most plausibly a small one.

---

### 6. Discussion / relative preference

**Before:**

> A follow-up model using relative preference scores showed the same pattern. Preferences among similar mind-body techniques may therefore play little role in immediate treatment response, even though they clearly guided which techniques participants chose.

**After:**

> A follow-up model using relative preference scores showed the same pattern. Read together, these results indicate that choosing among a set of broadly similar brief techniques—delivered in the same short, self-guided format and drawn from overlapping mind-body and reflective traditions—simply did not make much difference to how much any given session helped. Preference reliably shaped which technique students selected, but not how well it worked for them. Meaningful preference effects may require choices between more genuinely distinct modalities, intensities, or delivery formats than those compared here.

---

### 7. Limitations / control

**Before:**

> Several limitations warrant consideration. First, the study lacked a passive control group, so it is unclear whether participants were protected from the well-being decline often seen in highly stressed populations (Jha et al., 2015). Second, the four-week period and brief asynchronous format may not have provided sufficient intensity or personalization to produce measurable change; studies supporting self-regulation benefits typically employ longer, more intensive training. Future research could manipulate intervention dose to examine effects on adherence and outcomes.

**After:**

> Several limitations warrant consideration. Most fundamentally, the study included no inactive (no-treatment) control condition. Because both arms were active, the design can test whether the two interventions differ from each other—they largely did not—but cannot establish that either exceeded what would occur with no intervention at all. This caveat bears on between-condition and efficacy claims; it does not negate the within-session relief itself, which was observed directly and consistently. Indeed, some pre-to-post-session improvement would be expected even with no active ingredient: pausing for six minutes, attending to and reporting one’s own state, and completing a task framed as wellness can each produce apparent relief through demand characteristics, momentary regression from an activated starting state, and the natural arc of a brief break. Our design cannot separate these processes from any genuine effect of the techniques. The warranted conclusion is thus that brief sessions were reliably followed by acute relief—not that the specific self-regulation content caused it, nor that it exceeded a credible placebo. A no-treatment or neutral-activity control, which would also clarify whether participants were protected from the well-being decline often seen in highly stressed populations (Jha et al., 2015), is needed to support stronger claims. A second limitation is dose: the four-week period and brief asynchronous format may not have provided sufficient intensity or personalization to produce measurable trait-level change, as studies supporting self-regulation benefits typically employ longer, more intensive training. Future research could manipulate intervention dose to examine effects on adherence and outcomes.

---

### 8. Limitations / sample

**Before:**

> Third, the sample limits generalizability: most participants were first- or second-year female students, and both year and gender can influence stress, coping, and intervention responsiveness (Stupar-Rutenfrans et al., 2024). The predominantly healthy sample may also have created ceiling effects on well-being promotion. More demographically diverse samples, particularly those with elevated distress, could yield more robust findings and greater sensitivity to intervention benefits.

**After:**

> Third, the sample limits generalizability: most participants were first- or second-year female students, and both year and gender can influence stress, coping, and intervention responsiveness (Stupar-Rutenfrans et al., 2024). The predominantly healthy sample may also have created ceiling effects on well-being promotion, a concern compounded by differential attrition: participants retained for analysis reported higher baseline well-being than those who were randomized but did not complete the protocol (d = 0.53 on the WHO-5; see Results), so the completers analysed here were, if anything, those with the least room to improve. More demographically diverse samples, particularly those with elevated distress, could yield more robust findings and greater sensitivity to intervention benefits.

---

### 9. Concluding Remarks

**Before:**

> As universities seek scalable approaches to student well-being, preference-based models may enhance agency and motivation by aligning techniques with individual values and lifestyles, though they may need to target at-risk or symptomatic students to reveal reliable benefits. Future research should examine whether these effects are sustained over time and how such interventions can be integrated into broader support resources. Supporting students in choosing strategies that fit their needs may offer a scalable, student-centred approach to well-being during emerging adulthood.

**After:**

> Brief, self-guided digital sessions can reliably help students feel better in the moment, but this study finds that neither letting them choose their technique nor cycling them through a variety of brief techniques was sufficient to turn that momentary relief into lasting, trait-level change. The more consequential question this leaves for the field is one of transfer: what converts repeated state-level relief into durable well-being? Candidate answers—greater dose and frequency, content designed to build cumulatively, explicit rehearsal of skills against real-world stressors, and delivery targeted to students with genuine room to improve—remain to be tested. As universities seek scalable approaches to student well-being, preference-based and self-guided models remain appealing for engagement and reach, but their value will depend on solving this transfer problem rather than on choice or variety alone.

---

### + Inserted: completer vs. non-completer paragraph (Results)

> Because analyses were restricted to adherent completers, we compared the 120 analysed participants with the 38 who were randomized and eligible but did not complete the protocol (through non-adherence, not beginning the intervention, or a missing post-intervention survey) on baseline characteristics. The groups were comparable on baseline perceived stress, anxiety and depression, positive and negative affect, belonging, age, gender, and condition (all ps > .12). They differed on baseline well-being: completers reported higher WHO-5 scores than non-completers (M = 5.32 vs. 4.78, d = 0.53, p = .007), indicating modest selective attrition of students with lower initial well-being.

---

### + Inserted: Deviations from the Preregistration (new Heading 2 before Results)

> Three departures from the preregistered plan should be noted. First, the within-session well-being composite specified in the preregistration averaged change across four visual analogue scales (stress, mood, arousal, and life satisfaction); because the post-session check-in did not collect life satisfaction, this composite could not be computed, and within-session change was instead modelled separately for stress, mood, and arousal. Second, although we preregistered analysing the study-level well-being measure as separate flourishing and distress components should parallel analysis support more than one dimension, the parallel analysis indicated a single component, so a single composite was used. Third, the number of adherent participants available for analysis (n = 120) fell below the target our power analysis specified for H2 (n = 140), leaving that test underpowered; the analyses of individual practice weeks and of practice selection during the choice week were exploratory and were not part of the preregistered confirmatory plan.
