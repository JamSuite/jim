---
id: 20260703-build-the-partition-migration-skill
num: 34
title: "Build the partition migration skill"
status: open
priority: medium
labels: [migration, spec-groups, 000-blueprint]
relations:
  blocks: []
  depends-on: [20260630-build-intelligence-for-context-aware-spec-group-definition, 20260707-compute-graph-health-metrics-in-the-reconcile-pass]
  related-to: []
  duplicates: []
created: 2026-07-03T20:08:37Z
updated: 2026-07-07T03:28:37Z
origin: docs/brainstorms/20260703-context-aware-spec-group-definition.md
---

## Description

## Context

The 20260703 brainstorm (origin) resolved the partition doctrine:
**opinionated vertical-first** bounded contexts, with the axis
(`vertical|layered`) and a code-territory mode
(`directory` / `declared-paths` / `none`) as config knobs. Existing jim
projects grew **layered** partitions (`foundation` / `storage` /
`dashboard`) before the blueprint concept existed — they need a supported
path onto the new doctrine.

**2026-07-06: a full manual dry-run of this skill was performed on a
private project** (an existing non-jim Go codebase with no prior partition,
retrofitted to 12 groups, `vertical` / `declared-paths`, 46-edge graph
reconciled to zero findings). It validated the decomposition below and
supplied the design-inputs section; the worked-example artifacts (the map,
12 group blueprints, the misalignment punch-list and 2 filed refactor
issues) live in that project's own repo.

## What

A migration capability (skill for the reasoning, script for the mechanics)
that moves a project onto a chosen partition/mode. Two entry modes:

- **`repartition`** — from an existing (typically layered) map onto
  vertical-first: propose a new context map from the existing specs,
  blueprints, and code; interview to refine; materialize it in
  `BLUEPRINT.md`. Freeze-history doctrine applies: numbered specs are
  point-in-time artifacts and stay where they are — only living artifacts
  (the map, group blueprints, future spec filing) migrate. No reference
  rewriting.
- **`greenfield`** — partition a project with no prior map: jim adopted on
  an existing codebase where code (plus any sparse specs) is the only
  signal. Absorbed from #35 (2026-07-07); the dry-run was exactly this
  case, and arguably the primary retrofit shape.
- **Territory-mode upgrades (`none` → `declared-paths` → `directory`):**
  each step strengthens the mechanical verification floor; the `directory`
  step implies code moves, so it is proposed as a reviewable plan, never
  auto-applied. Retrofits default to `declared-paths`; the refactor issues
  the migration files are literally the path to `directory` mode.

LLM reasoning is required for the partition proposal (boundary judgment);
the file mechanics should be deterministic script work. Human approval gates
every materialization, per jim's phase-gate convention — gate hard on the
map, soft on the derived blueprints (maps onto `auto_blueprint`).

## Design inputs (dry-run, 2026-07-06)

- **Invert the graph derivation:** extract the real dependency
  graph from code first (imports + event pub/sub topics + service-registry
  provide/consume), then have the LLM write faces to *match* it — the
  reconcile then validates faces against ground truth instead of comparing
  two hand-authored artifacts (prose-first understated even the clean
  dry-run codebase by 6 edges). Honesty trap: a shallow extractor yields a
  falsely *sparse* graph (the dry-run project's real inter-module edges
  were event topics and registry lookups, not imports), so the derived graph must be labeled by which coupling
  channels it covered. Same derived-never-re-declared doctrine as
  [[20260704-derive-the-map-relations-column-from-the-contract-graph]]
  (#40) at the map tier.
- **Proactive coverage check:** compute territory coverage as a
  set-difference (all source dirs − union of proposed territories) before
  materializing. The dry-run's most valuable structural finding (a package 7 groups
  imported but no territory owned) was found by luck; this makes it
  guaranteed.
- **Expect platform-heavy partitions:** the dry-run landed 7 platform / 5
  domain — correct for a framework. Interview hard on platform-vs-domain
  using the platform-bar justification (what it provides, why genuinely
  shared, why churn is low).
- **The punch-list is the primary deliverable:** systematically
  offer every surfaced misalignment as a tracked issue and emit a migration
  report — the migration's real output is a backlog, and on a tangle it
  must be ranked and clustered, not dumped.
- **Tangle robustness:** on unstructured code the derived graph
  comes back dense and cyclic — a feature, it refuses to lie.
  Reconcile-clean stops meaning good-partition (hence the graph-health
  dependency below); straddling packages need flagging; invariants the code
  currently violates strain the blueprint's present-tense contract and need
  a target/violated annotation decision;
  **"partition-blocked-on-refactors" is a first-class terminal state**
  (coarse partition + unblocking backlog), not an error.
- **Process shape:** templated interview forks (coverage scope,
  kernel granularity, shared-kernel placement); kernel-first blueprint
  generation ordered by dependency depth; per-group evidence fan-out
  sitting on the deterministic extraction substrate, not re-grepping.
- **Proposed phases:** extract (script) → propose (LLM) → interview
  (hard gate) → materialize (script) → blueprint (LLM, kernel-first) →
  reconcile-to-clean + read graph-health → report + offer issues.

## Open questions (for /jim:spec)

The gating one is the **code-analysis
substrate**: jim ships no AST/dependency extraction, and existing doctrine
(#22's registry model) says AST is a hook, not a jim capability. Likely
landing: registry-wired per-language extractors + a native grep-scan
fallback + coverage labels naming which coupling channels were modeled
(imports / events / registry / DI / reflection) — decide scope at spec time
(may split into its own spec). Others: reconcile-to-clean iteration bound
before escalating; migration-report artifact vs issues-only; whether the
`declared-paths → directory` upgrade is a separate invocation consuming the
filed refactor issues as its checklist; how a blueprint records straddles
and currently-violated target invariants.

## Depends on

- [[20260630-build-intelligence-for-context-aware-spec-group-definition]]
  (#19, closed) — the vertical doctrine, `BLUEPRINT.md` context map, and
  territory modes; shipped as specs 033/034.
- [[20260707-compute-graph-health-metrics-in-the-reconcile-pass]] (#63) —
  the reconcile-to-clean phase reads graph-health as the partition-quality
  signal; face-accuracy alone is not partition-quality.
