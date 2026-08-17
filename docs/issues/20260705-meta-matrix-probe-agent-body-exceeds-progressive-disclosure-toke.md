---
id: 20260705-meta-matrix-probe-agent-body-exceeds-progressive-disclosure-toke
num: 54
title: "meta-matrix-probe agent body exceeds progressive-disclosure token budget"
status: open
priority: medium
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T00:37:36Z
updated: 2026-07-05T00:37:36Z
origin: docs/specs/jim/000-blueprint/spec.md
---

## Description

Verify (`/jim:verify jim`) found blueprint invariant **inv-7** violated (judge verdict `partial`).

**Invariant:** SKILL.md ≤ 500 lines and agent body ≈ ≤ 800 tokens (progressive disclosure — detail lives in `assets/` / `references/`).

The rule is a conjunction. The **SKILL.md clause holds cleanly** — all 27 `skills/*/SKILL.md` are ≤ 500 lines (tightest is `skills/blueprint/SKILL.md` at 497, a near-miss worth watching). The **agent-body clause holds for 10 of 11 agents** but is materially breached by one:

<untrusted-content>
agents/meta-matrix-probe.md  body lines 13-83 (~71 lines of dense prose):
  a dual-sentinel rubric, a combined truth table, a mnemonic, and a dated
  refinement note. ~1,076 words → roughly ~1,400 tokens (higher in practice —
  long identifiers like SUBST_SKILL_PATH3_PRELOAD_THRU_INJECTION tokenize into
  ~6-8 tokens each). ~75% over the ~800-token budget.
For comparison, the next-largest bodies (security.md, issue-analyst.md,
reviewer.md, judge.md) sit near ~600-820 tokens — within the "≈" tolerance.
</untrusted-content>

The `meta-matrix-probe` body inlines the full path-2/path-3 substitution rubric, truth table, mnemonic, and a decision-record note — exactly the kind of detail progressive disclosure expects to live in a `references/` doc, not in the agent's startup context. (`skills/meta-agent/SKILL.md:97` restates this budget with a loose line proxy of "≈ 150–200 lines"; by that generous line heuristic the 71-line body would pass, but the invariant is stated in tokens, and by token count it clearly does not.)

Estimation caveat: agent-body token counts are approximations (words×1.3, cross-checked against chars/4). The borderline bodies were left unflagged as within the "≈" tolerance; `meta-matrix-probe.md` is ~75% over even under the most generous estimator — a genuine gap, not measurement noise.

Suggested remedy: move the substitution rubric / truth table / refinement note out of `agents/meta-matrix-probe.md` into a `references/` doc the probe reads on demand, trimming the startup body toward the ~800-token budget.

Origin: `docs/specs/jim/000-blueprint/spec.md` (inv-7, criticality medium). Reported by `/jim:verify jim`; not yet fixed.
