---
id: 20260813-verify-grades-a-violation-by-its-rule-not-by-its-breach
num: 350
title: "verify grades a violation by its rule not by its breach"
status: open
priority: high
labels: [verify, triage, noise]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-13T11:36:55Z
updated: 2026-08-13T11:36:55Z
origin: "docs/specs/jim/000-blueprint/spec.md"
---

## Description

## Description

`/jim:verify` grades an offered issue by the **rule's** criticality, never by the
**breach's** severity. `skills/verify/SKILL.md:267`:

    `priority` = the invariant's criticality (the `critical`/`high`/`medium`/`low`
    vocabulary is the priority vocabulary)

Restated at `:273` and `:280` in the filing commands, and asserted as correct by
the closing checklist at `:315` ("priority from criticality").

An invariant is `critical` because breaching it *can* be severe. A given breach
often is not. The mapping cannot tell those apart, so it grades every violation at
the ceiling of its rule.

## The evidence

Nine issues from `/jim:verify` runs sat in the collection as five `critical` and
four `high`. Re-graded 2026-08-13 against their own stated risk, two survived
their labels. Four contradicted their labels **in their own descriptions**:

- `#161` (`critical`) — "No dispatch path depends on these strings, so nothing
  fails at runtime" → `low`
- `#162` (`critical`) — "the permission still matches at runtime — the risk is
  convention drift" → `low`
- `#163` (`critical`) — "latent rather than currently firing" → `medium`
- `#164` (`high`) — "No shipped workflow skill can execute a retired gate today"
  → `low`

`#52` (`critical` → `high`) shows the second-order effect: it bundles a breach its
own text calls low-risk with a genuine unbounded-`bash -c` over-grant, and one
inherited grade had to cover both.

## The cost, which is not hypothetical

Those nine were repeatedly described in round notes as "the highest-criticality
open work in the whole collection" and deferred through **seven** consecutive
builds. Each round recorded the deferral as alarming. On the re-graded set the
deferral was correct judgment — overruled seven times by a label that was never
about the work.

A grade the pipeline assigns mechanically and a human then reasons from is worse
than no grade, because it carries the authority of a measurement while being a
restatement of the rule.

## Action

Grade the breach, not the rule. The invariant's criticality is the right *ceiling*
and the wrong *value*. The judge already produces the evidence a grade needs — it
distinguishes `partial` from a full violation, and its verdicts routinely say
whether a breach is live, latent, or inert at runtime.

Options, roughly increasing in cost:

1. Have the judge return a severity alongside its verdict, bounded above by the
   invariant's criticality, and file at that.
2. Keep the inherited grade but require the offered issue to state the runtime
   consequence in a fixed field, so a reader sees "nothing fails at runtime" next
   to the label instead of four paragraphs below it.
3. Map `partial` verdicts one grade below the invariant's criticality by
   construction, and reserve the full grade for an unqualified violation.

Whichever is taken, the closing checklist item ("priority from criticality")
should stop asserting the current behavior is correct.

## Related

This is the weak spot the blueprint merit report named and nothing tracked:
*"Mis-graded criticality manufactures noise."* That report is the only record of
it, is untracked, and has no home in any product doc.
