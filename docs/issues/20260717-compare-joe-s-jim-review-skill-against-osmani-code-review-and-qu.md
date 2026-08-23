---
id: 20260717-compare-joe-s-jim-review-skill-against-osmani-code-review-and-qu
num: 78
title: "Compare Joe's jim:review skill against Osmani code-review-and-quality blueprint"
status: open
priority: high
type: issue
filed-by: "dorsma"
claimed-by: ""
outcome: ""
labels: [review, skill, prior-art]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-17T20:53:35Z
updated: 2026-07-18T20:50:49Z
origin: docs/research/20260717-competitive-landscape-sdd-skills.md
---

## Description

Blueprint verified in the 2026-07-17 competitive-landscape research (`docs/research/20260717-competitive-landscape-sdd-skills.md`).

**Current state.** Joe's `jim:review` skill already exists, complete, on branch `origin/feat/review` (73 commits ahead of `main`, unmerged). It ships `skills/review/SKILL.md`, `skills/review/assets/review-template.md`, `skills/review/scripts/jimledger.sh`, and `agents/reviewer.md` — with a review-ledger, a `review.md` code+process metrics artifact, and a review lifecycle stage. `skills/review/` on `main` is still an empty stub. So this issue is **not** about building a review skill; it is about **comparing Joe's implementation** against the strongest external blueprint this research surfaced (Addy Osmani's `code-review-and-quality`, github.com/addyosmani/agent-skills) and the other reference architectures below.

**Prerequisite: merge first.** The comparison assumes Joe's code is in hand, but the skill is unmerged. Step one is to review `origin/feat/review`, run its tests, and **merge it → `main`** so `review.md` and the review stage are live. This also makes `review.md` a real sibling artifact and lifecycle stage — a spec carrying `review.md` = the "review" stage.

**Osmani blueprint to diff against (verified anchors, `skills/code-review-and-quality/SKILL.md`):**
- Five review axes as mandatory sections: Correctness, Readability/Simplicity, Architecture, Security, Performance.
- Severity-prefix vocabulary: no-prefix = required, `Critical:` blocks merge, `Nit:`, `Optional/Consider:`, `FYI`.
- Change-size thresholds (~100 lines good / ~300 acceptable if single logical change / ~1000 too large → split) — maps onto jim:plan task granularity, so review can flag when an implemented task's diff blew past its planned size.
- Splitting strategies (mixed concerns, wrong-layer logic) and dependency-upgrade discipline (one dep/change, read changelogs not just semver, no hand-edited lockfiles).
- Explicitly applies to the coder-agent's own output, not just human diffs (relevant since jim:coder is TDD self-reviewing).

**Comparison should also cover:**
- Overlap with jim:sec — jim:review should cross-reference, not duplicate, jim:sec's STRIDE/LINDDUN security depth.
- Matt Pocock `engineering/code-review/SKILL.md` (the receiver of `tdd`'s "refactor belongs to review, not red-green") and VoltAgent `categories/04-quality-security/code-reviewer.md` (numeric DoD: coverage >80%, complexity <10; fixed completion-notification string).
- Whether jim:review should be single-pass or adopt an adversarial/second-opinion pass (Osmani `doubt-driven-development`; Spec-Flow `optimize.md` temperature-varied voting).
- **Spec↔code drift / convergence.** The skill's own charter — *"review what a build actually shipped against its spec, plan, and architecture after /jim:build — detecting drift"* — indicates the post-build **"did the code actually do what the spec said"** pass is already covered; jim's "post-build convergence" gap looks closed by this skill. So the work here is to **confirm its depth** against the reference model — GitHub Spec Kit's `/analyze` (read-only cross-artifact spec↔plan↔tasks linter) + `/converge` (classifies gaps **missing / partial / contradicts / unrequested** and *appends* remediation tasks rather than rewriting): does Joe's skill classify gaps that way and append remediation rather than rewrite? — not to add convergence as a net-new capability.

**Runtime-review reference architectures** — two more implementations worth studying for jim:review's *runtime* mechanics (distinct from Osmani's review *rubric*):
- **`anthropics/claude-plugins-official` → `plugins/security-guidance`** (Anthropic-official, hook-driven) — a 3-tier escalation ladder (cheap regex → LLM diff review on the `Stop` hook → agentic multi-file data-flow trace via the Agent SDK on commit), **baseline-SHA session diffing** (review only what changed this session), and an `asyncRewake` primitive that forces the agent to address findings before continuing. Also names two agent-specific threat classes (Agent/Subprocess Permission Bypass, Orchestrator Template Injection). Strongly validates jim's design-time-vs-post-build split (jim:sec vs jim:review) — Anthropic separates the same way.
- **`wshobson/agents` → `plugins/comprehensive-review`** — checkpoint-gated multi-lens pipeline (`architect-review` / `code-reviewer` / `security-auditor` personas), file-based `.full-review/` state, and a PR risk-score (size×complexity×coverage×deps×security) + split heuristic.

**Deliverable:** (after merge) a gap diff — Joe's skill vs. the Osmani rubric, the two runtime-review references above, and the jim:sec boundary — plus a recommendation on what, if anything, to fold into Joe's skill.
