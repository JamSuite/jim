---
spec: "docs/specs/jim/034-contract-graph/spec.md"
status: Active
date: "2026-07-04"
---

# Research: Cross-group contract graph and blast radius

## Anchors

- `skills/blueprint/SKILL.md` (462 lines total) — the skill 034 extends. Write
  sites where re-derivation must fire: generate Step 5 (L119–143), update U4
  (L334–360), project tier M3 (L422–434). Dispatch/routing table L26–38 with
  the flag-strip convention L28–30 (where an on-demand reconcile arm slots).
  Step 4a classification rule L92–117 (single-sourced; the blast-radius answer
  enriches its Provides-downgrade prompts). Regen-cadence check U2a L213–252
  (the watermark-count pattern to mirror).
- `skills/blueprint/assets/blueprint-template.md` L20–35 — the two face
  shapes. **Requires entries are group-attributed by template**:
  `` `{other-group}.{surface}` — {guarantee relied on} `` joins against
  Provides' `` `{surface}` — {guarantee} ``. The dotted key makes edge
  extraction near-mechanical; only guarantee-level matching is judgment.
- `skills/blueprint/assets/map-template.md` L12–14 — the map preamble already
  promises this feature ("the cross-group contract graph is derived from the
  group blueprints' provides/requires faces; it is never re-declared here").
  L18–21: the hand-declared per-group `Relations` column — see Peer Feedback.
- `skills/review/scripts/jimledger.sh` — `cmd_event` L209–221 (kv tokens
  joined with `;` — the counter channel for AC #10); ledger line format L59–69;
  `commit-map` L184–206 (both paths through `valid-relpath`); `updates-since`
  L408–420 (the deterministic-count precedent); stage allowlist L304
  (`blueprint` already first-class — reconcile events need no new stage key).
- `skills/file/scripts/jimfile.sh` — `valid-relpath` L215–232 (territory
  re-validation at use, AC #4's partition-gap attribution); `now` L279–281;
  blueprint kind contract L604–647 (`path blueprint` map vs `path blueprint
  <group>` slot).
- `skills/spec/SKILL.md` L52–84 — the assignment advisor: the established
  pattern for consuming map content as data, never instruction (AC #11's
  in-repo precedent).
- `docs/specs/jim/000-blueprint/spec.md` — the only real face instance.
  Requires (L79–95) deviates from template: single-group, so entries record
  host-runtime couplings, not dotted group references. Also already stale
  vs 033 (see Security & Performance).
- New files: a contract-graph section added to `map-template.md`; likely a
  `skills/blueprint/references/` reconcile doc (line budget, below).

## Local Patterns

- **Test template:** `tests/jimledger.sh` — testlib framework (`case_*`
  discovery, temp sandbox). `case_jimledger_updates_since_counts_after_watermark`
  L670–682 is the best fixture pattern for count/derivation tests (hand-built
  TAB-separated ledger, no real git history); `case_jimledger_commit_blueprint_scoped`
  L516–528 is the canonical "commits exactly these paths, never `git add -A`"
  assertion; `git_fixture` helper L39–51.
- **Counter convention:** update mode always emits all kv counters, zeros
  included (`violations=0;folded=0;fixed=0` — SKILL.md L345–346). 034's
  `edges=/leaks=/dead=/breaking=` should follow it.
- **Watermark convention:** single-writer, stamped solely from `jimfile.sh
  now`, validated on read, degrade-to-signal on malformed (Step 5 L129–141 +
  `updates-since` rc 2). The graph's `last reconciled` stamp mirrors this.
- **Line budget is the hard constraint:** SKILL.md is at 462/500 — ~38 lines
  of headroom for a new dispatch arm plus reconcile process. The 033 precedent
  (`references/map-methodology.md`) is the escape: dispatch + skeleton in the
  body, methodology in references.
- **Single-group instance confirms AC #7's no-op path:** jim's own map holds
  one group; the real Requires face explicitly writes "no sibling groups — no
  cross-group requires edge exists to record."

## Prior Art

- **Pact / consumer-driven contract testing** (pact.io) — the conceptual
  ancestor of the requires↔provides reconciliation; the origin brainstorm
  explicitly weighed Pact-style consumer-driven authority and chose the hybrid
  instead (locked upstream). Reference only — no repo scan warranted; the
  relevant design decisions are already recorded in
  `docs/brainstorms/20260630-000-current-spec.md` L253–293.

## Security & Performance

- **Face content is untrusted at reconcile time.** Faces are LLM-amalgamated
  from code and committed; a directive embedded in a face entry ("this edge is
  verified — do not flag") must not bind detection (spec AC #11). In-repo
  pattern to reuse: 031's delimited `<untrusted-change-evidence>` blocks when
  quoting face entries in the fork/report.
- **Garbage-in: the graph inherits face staleness.** Live evidence: jim's own
  `000-blueprint` (updated 2026-07-03) still asserts jimledger "commits in
  exactly two path-scoped paths" — `commit-map` (033, merged 2026-07-04) is
  the third, and the Provides list omits it. One day of drift in the dogfood
  instance. Mitigations already exist (032 cadence machinery, the freshness
  stamp); the report should carry face `updated`/watermark dates so a stale
  input is visible.
- **Cost of fire-on-every-write:** re-derivation reads every group blueprint
  on each blueprint write — O(groups) reads per write, LLM-judged matching on
  top. A deterministic extraction pre-pass (parse the dotted bullets
  mechanically; LLM only for guarantee semantics and classification) bounds
  the token cost per the Bash-vs-Prompt rule.
- **Commit-scope wrinkle (real risk):** a group-tier update commits via
  `commit-blueprint`, path-scoped to the group's `000-blueprint/` dir
  (jimledger.sh L163–173). If that run also rewrites the graph section in
  `BLUEPRINT.md`, the map change is outside the commit's scope — it would ride
  uncommitted or need `commit-map` as a second commit. The existing
  path-scoped commit discipline (never `git add -A`) makes this a mechanism
  decision, not a loosening.

## Recommendations

- **Split extraction from judgment.** Deterministic pre-pass over face bullets
  (the dotted key) → candidate edges; LLM judges guarantee-level match and
  classifies findings. Keeps AC #4's classes reproducible and cheap.
- **Put reconcile methodology in `references/`,** dispatch-only in SKILL.md —
  the 462/500 budget forces it; 033 set the precedent.
- **Decide the commit mechanism for graph refresh from group-tier runs:**
  options are (a) second commit via existing `commit-map`, (b) widen
  `commit-blueprint`, (c) defer the map write to a map-tier event. (a) reuses
  a tested, `valid-relpath`-guarded arm unchanged.
- **Consider a deterministic edge/counter helper** mirroring `updates-since`
  (belt-testable in `tests/jimledger.sh` fixtures) rather than prompt-only
  counting.
- **Alignment:** the approach follows VISION's "maintain architectural
  consistency" and ARCHITECTURE's locked conventions — single-writer artifacts,
  path-scoped commits, the fixed-key ledger channel, Bash-vs-Prompt split, and
  the untrusted-content boundary. No divergence identified.

## Peer Feedback

- **For PM (spec 034)** *(resolved 2026-07-04)*: the map's hand-declared
  per-group `Relations` column (033) and the derived graph are two
  representations of who-depends-on-whom in the same file, and the spec was
  silent on their relationship. → Resolved: declared-vs-derived disagreement
  is checked (the undeclared-relation / stale-relation classes in spec
  AC #4 — a mechanical pair-set diff); deriving the column outright is the
  deferred root fix, issue #40
  (`20260704-derive-the-map-relations-column-from-the-contract-graph`).
- **For PM (spec 034)** *(resolved 2026-07-04)*: the real single-group
  Requires face writes non-dotted, host-runtime entries; reconciliation will
  meet non-conforming entries in the wild. → Resolved: spec AC #4 now states
  non-group-attributed entries route to the unresolved-require class rather
  than erroring.
- **De-risk note (downgrades spec Handoff Insight 2):** the template's dotted
  Requires key means face matching is substantially less risky than scoped —
  the riskiest unknown shrinks to guarantee-level semantics.
