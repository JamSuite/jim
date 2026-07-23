---
spec: "docs/specs/jim/048-partition-merge/spec.md"
status: Active
date: "2026-07-22"
---

# Research: Partition merge

Phase 0 ran against HEAD of `feat/blueprint`; every anchor below was verified
this session (direct read or Explore dispatch). Phase 1 (external) was skipped:
the feature is internal machinery with no external APIs, libraries, or prior-art
references. Origin context: `docs/brainstorms/20260722-partition-merge.md` and
`docs/research/20260722-partition-merge-context.md` (the decision-neutral
briefing; §11 there is a fuller citation index).

## Anchors

**Verbs to extend or mirror — `skills/partition/scripts/jimpartition.sh`:**

- `cmd_split_preflight` `:1015-1132` — the preflight to mirror; ARM detection
  `:1032-1037` (inverts to *absorption iff target mapped*), `target==old`
  collision exemption `:1085`, TERRITORY-IDENTITY `:1095-1105` and DIRT
  `:1107-1128` collection (both become per-source loops).
- `cmd_renumber_map` `:1143-1218` — the two lines merge generalizes: `seq=0`
  reset per child `:1202` (merge needs one global, floored seed) and the MAP
  source prefix hard-coded to the single `$old` `:1213` (merge needs a
  per-source prefix).
- `cmd_edges_diff` `:1278-1309` — `rw()` `:1293` rewrites one slug pair on the
  before side only `:1298`; the merge form needs N-source rewrite plus
  consumer==provider row elision.
- `cmd_rewrite_refs` `:1485-1581` — remap-parsed-as-whitelist `:1498-1519`;
  reusable as-is for AC 11.
- `cmd_rewrite_identity` `:1349-1464` — containment guard `:1366-1387`;
  reusable per source for AC 10.
- `cmd_identity_check` `:1675-1745` — the op filter and retirement rule AC 15
  extends; the stale header comment `:1675-1683` (says `op=rename` only; code
  handles `op=split`) rides the same edit, as does
  `partition-methodology.md:581` ("retired rename slug").
- `main()` dispatch `:1754-1772` — registers the two new verbs.

**Ledger and floor — `skills/review/scripts/jimledger.sh`, `skills/file/scripts/jimfile.sh`:**

- `cmd_vacated_max` `jimledger.sh:509-550` — the `;op=split;` gate `:539` is
  the one-line widen for AC 15; the element charset gate is op-agnostic.
- `cmd_move_spec_dir` `jimledger.sh:456-506` — reused unchanged per absorbed
  spec (AC 17).
- `cmd_commit_split` `jimledger.sh:387-440` — stages exactly the caller's
  explicit path list (`"$@"` `:420`, pathspec `:437`); the shape `commit-merge`
  mirrors with a merge subject.
- `cmd_event` `jimledger.sh:552-564` — **no key=value shape validation**; kv
  pairs are written verbatim (see Security).
- `cmd_next_id` `jimfile.sh:289-357` — `max(dir-max, vacated-max)` is exactly
  AC 9's seed semantic; its comment already names the retired-group-re-mint
  case.

**Doc surfaces:**

- `skills/blueprint/references/migrate-arms.md:29-58` — the `--split` arm's 7
  steps are the `--merge` template: `--targets`-as-whitelist wording `:34-36`
  (→ `--sources`), retirement-without-standalone-prompt `:47-51`, Contract
  Graph rewrite `:52-55`, deferred commits `:56-58`.
- `skills/partition/SKILL.md:338-379` — `## Split runs` is the structural
  template for `## Merge runs`; op=split events recorded `:344-345`/`:376-377`.
  **The file is at 500/500 lines — the budget cap** (see Recommendations).
- `skills/partition/references/partition-methodology.md:386-551` — § Split
  protocol; § Merge protocol lands after it. The Merge-duality note `:544-550`
  contains the invariant-id claim spec Insight 4 corrects — supersede it, don't
  contradict it.
- `agents/gatherer.md:30-42` — the split-dispatch role paragraph the merge role
  (AC 20) sits beside; file is 122 lines against the ≈800-token agent budget.

## Local Patterns

**Test template (AC 21):** `tests/jimpartition.sh` — hand-rolled testlib
framework (`case_*` discovery via `declare -F`, `OUT=$(...)` capture under
`set -uo pipefail`, inline heredoc fixtures, per-run `mktemp` sandbox, single
trap cleanup; scaffold via `/jim:meta-test`). Specifics to extend:

- `split_repo()` `tests/jimpartition.sh:248-306` — the two-group git fixture
  (`modules/cart` + `modules/orders`, blueprints, map with Contract Graph);
  merge needs a third-group / fresh-target variant.
- Split-preflight case block `:1514-1596` and renumber-map block `:1598-1673`
  — the per-verb case patterns merge-preflight / merge-renumber cases mirror.
- `tests/jimledger.sh`: `move_git_fixture()` `:1391-1402`; vacated-max block
  `:1484-1557` (add `op=merge` event rows); commit-split block `:1559-1601`
  (→ commit-merge cases).
- `tests/jimfile.sh`: `case_jimfile_next_id_retired_group_remint_floors` `:234`
  — the exact re-mint scenario whose merge dual AC 15 adds.

**Conventions:** `set -uo pipefail` (never `-e`); BASH_SOURCE-relative
cross-script composition; `san`/`san_field` on every emitted field; no spec IDs
in script comments (CLAUDE.md); new verbs over flag-overloading (043/047
precedent — rename/split shipped sibling verbs rather than extending flags).

## Security & Performance

- **The event writer is permissive; consumers are the boundary.** `cmd_event`
  concatenates kv args verbatim (`jimledger.sh:552-564`) — nothing validates
  `op=merge old=… new=… moved=…` at write time. This is the existing op=split
  posture, and it holds only because every machine consumer parses fail-closed
  (`vacated-max` per-element charset gate, `identity-check` slug gates,
  `RECONCILE_AWK` whitelist). AC 15's widenings must preserve that: extend
  filters only, no new value shapes. The 047 security review's
  machine-consumption finding extends unchanged; flag for the `/jim:sec` pass.
- **Archive-wide rewrite blast radius** (rewrite mode) mirrors split: bounded
  by remap-as-whitelist + the approved-set re-validation + revert-and-rerun (no
  mid-run resume). A many-source merge emits more `moved=` pairs than a typical
  split — the repeatable ≤256-byte chunk grammar already covers it, but tests
  should include a multi-chunk case.
- **Performance:** sweeps are linear in archive size; gatherer fan-out is one
  dispatch per source under `verify_fanout_cap`; no new hot paths.

## Recommendations

1. **New sibling verbs, not flags.** A `merge-preflight` and a merge renumber
   verb (rather than mode flags on the split verbs) keeps the shipped split
   verbs frozen — the 043/047 precedent, and `renumber-map`'s two hard-coded
   lines (`:1202`, `:1213`) make in-place generalization riskier than a
   sibling.
2. **Seed via caller.** Pass the floored append seed into the renumber verb
   (orchestrator runs `jimfile.sh next-id <target>` first) — keeps the verb
   pure and testable; cross-script composition inside the verb is the
   alternative (spec Insight 2).
3. **`edges-diff` merge form as a flag or sibling** — either is small (`rw()`
   is one line); a sibling keeps rc semantics untangled (spec Insight 3).
4. **`commit-merge` mirrors `commit-split`'s explicit-`"$@"` shape** with a
   merge subject; ~40 lines of parallel code beats a shared helper for
   clarity.
5. **Fund the SKILL.md cap first.** `skills/partition/SKILL.md` is at 500/500;
   `## Merge runs` cannot land without extraction. Candidates: compress
   `## Split runs` by pointing detail to methodology (the 036/044 relocation
   precedent) or extract shared migration-run boilerplate. The plan should
   budget this as its own task before any merge prose lands.
6. **Supersede the duality note.** § Merge protocol replaces the
   `:544-550` forward-compat paragraph (its invariant-id renumber-append claim
   is wrong for semantic-slug ids); leaving both texts standing would carry a
   contradiction into the doc that specs cite.

## Peer Feedback

None — findings confirm the spec as written; no AC is invalidated and no plan
exists yet.

**Alignment:** This work completes the ripple-engine verb family exactly as
ARCHITECTURE.md's evolution narrative anticipates ("`merge` remains a follow-on
consuming the `(sources, targets, assignment)`-parameterized change-set
shapes") and stays inside its documented doctrines — single-writer blueprint
authority, script-owned git primitives (no skill git grant), hard gate before
materialization, counters-only ledger, Bash-vs-Prompt split. It serves
VISION.md's north star (the spec archive as compounding institutional memory)
by making partition repair a gated, provable operation rather than a hand edit.
No divergence from locked constraints.
