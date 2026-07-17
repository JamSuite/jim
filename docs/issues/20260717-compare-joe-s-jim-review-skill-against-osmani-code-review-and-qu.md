---
id: 20260717-compare-joe-s-jim-review-skill-against-osmani-code-review-and-qu
num: 13
title: "Compare Joe's jim:review skill against Osmani code-review-and-quality blueprint"
status: open
priority: high
labels: [review, skill, prior-art]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-17T20:53:35Z
updated: 2026-07-17T20:53:35Z
origin: docs/research/20260717-competitive-landscape-sdd-skills.md
---

## Description

Blueprint verified in the 2026-07-17 competitive-landscape research (`docs/research/20260717-competitive-landscape-sdd-skills.md`). Note: `skills/review/` currently exists as an **empty stub directory**.

**Context / reframing:** Joe reportedly already built a jim:review skill. So the primary work here is **not** to build one from scratch — it's to **compare Joe's implementation** against the strongest external blueprint this research surfaced (Addy Osmani's `code-review-and-quality`, github.com/addyosmani/agent-skills), once Joe's version is in hand.

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
- **Spec↔code drift / convergence** *(folded in from a separate candidate, 2026-07-17 — developer believes Joe may already have built this)*: does Joe's skill do a post-build **"did the code actually do what the spec said"** pass? Reference model = GitHub Spec Kit's `/analyze` (read-only cross-artifact spec↔plan↔tasks linter) + `/converge` (classifies gaps **missing / partial / contradicts / unrequested** and *appends* remediation tasks rather than rewriting). **If Joe's review already covers this, note it and stop; if not, evaluate adding it** — jim currently has no closing loop between built code and spec intent. This is jim's "post-build convergence" gap and the review skill is its natural home.

**Runtime-review reference architectures (added 2026-07-17):** two more implementations worth studying for jim:review's *runtime* mechanics (distinct from Osmani's review *rubric*):
- **`anthropics/claude-plugins-official` → `plugins/security-guidance`** (Anthropic-official, hook-driven) — a 3-tier escalation ladder (cheap regex → LLM diff review on the `Stop` hook → agentic multi-file data-flow trace via the Agent SDK on commit), **baseline-SHA session diffing** (review only what changed this session), and an `asyncRewake` primitive that forces the agent to address findings before continuing. Also names two agent-specific threat classes (Agent/Subprocess Permission Bypass, Orchestrator Template Injection). Strongly validates jim's design-time-vs-post-build split (jim:sec vs jim:review) — Anthropic separates the same way.
- **`wshobson/agents` → `plugins/comprehensive-review`** — checkpoint-gated multi-lens pipeline (`architect-review` / `code-reviewer` / `security-auditor` personas), file-based `.full-review/` state, and a PR risk-score (size×complexity×coverage×deps×security) + split heuristic.

**Deliverable:** a gap diff (Joe's skill vs. the Osmani rubric, the two runtime-review references above, and the jim:sec boundary) plus a recommendation on what, if anything, to fold into Joe's skill.
