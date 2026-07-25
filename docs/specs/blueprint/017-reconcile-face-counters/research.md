---
spec: "spec.md"
status: Active
date: "2026-07-13"
---

# Research: Compute reconcile face-size counters deterministically

## Anchors

**The aggregating surface (new).**
- `skills/verify/scripts/jimverify.sh` — the intended home. Today `cmd_faces`
  (682–754) emits one per-entry TSV record per Provides/Requires entry (no
  aggregate), and `cmd_health` (991–1056) emits `FANIN`/`FANIN_GROUP` from the
  graph. Neither sums/maxes `provides` rows. The new verb sits alongside them.
- `groups_of()` (796–802) — emits each group slug under `## Groups`; the
  aggregator's group enumerator.
- `cmd_contracts_check` (879–977) — the **signature precedent**: takes
  `<map> <specs_root>`, iterates `groups_of`, resolves each group's face as
  `$specs_root/$g/000-blueprint/spec.md` (911), and pipes `cmd_faces "$pbp"`
  (959). The aggregator reuses this exact shape.
- Dispatch table (1120–1132) — where a new `faces-aggregate)` arm is wired;
  `usage()` (134–149) gets the matching line.

**The LLM arithmetic being replaced.**
- `skills/blueprint/SKILL.md` Step 2a (413–416) computes `faces=`/`faces_max=`/
  `faces_max_group=`/`fanin_group=` by model reasoning; finished-event payload
  (420–427); checklist (495). This becomes a copy-verbatim step.
- `skills/blueprint/references/reconcile-methodology.md` § Outcome counters
  (247–297) — the contract text; lines 261, 273–280, 290–297 name the face
  counters as Step-2a-counted and must be reworded to "script-emitted."

**Test locations.**
- `tests/jimverify.sh` (1559 lines, 76 `case_jimverify_*`) — new aggregator
  cases go in a new section (faces at 597, health at 1015 are the neighbors).
- `tests/jimledger.sh` 1319–1362 — the spec-044 four-counter payload cases;
  the exact `faces=…;faces_max=…;faces_max_group=…;fanin_group=…` strings the
  aggregator output must be able to feed (value-parity anchor).

## Local Patterns

**Test template (coder copies this).** `tests/jimverify.sh` sources
`skills/meta-test/scripts/testlib.sh` BASH_SOURCE-relative (20–25), invokes via
`run_jimverify` capturing `OUT`/`ERR`/`RC` (29–36), asserts with
`assert_eq` / `assert_match` / `assert_exit` (testlib 101/115/128). TSV fields
read via `tsv_field <id> <n>` (keys on field 1). No per-case setup/teardown —
each case builds fixtures inline (`bp_faces` 612 for face specs, `hmap` 1020
for maps); `TMP_BASE` is auto-created and trap-cleaned by testlib.
- **Direct analog** — `case_jimverify_health_acyclic` (1042–1055): builds an
  `hmap`, runs the verb, asserts `tsv_field FANIN 2 == 1`. A `faces=`/`faces_max=`
  case is the same shape.
- **Ties → all, sorted** — the fan-in-ties case (1103–1114) asserts every group
  at the max, sorted; the direct idiom for `faces_max_group` tie handling.
- Convention: `set -uo pipefail` (never `set -e` — breaks `OUT=$(...)`), each
  case opens with a `# AC:` comment. Run: `bash tests/jimverify.sh` from repo
  root (optional substring filter), or `/jim:meta-test run jimverify`.

**Sanitization primitives already in `cmd_faces`/`cmd_health`.** `san()` (strips
tabs/CR, caps length), `is_slug()` (`^[a-z0-9][a-z0-9-]*$`), `slugify()`, and
the health verb's `isort()` (deterministic sort) — the aggregator reuses these
for the ≤256-byte cap, slug validation, and sorted comma-join. No new
primitives needed.

**Bash conventions (CLAUDE.md → Bash scripts):** POSIX + bash only, no `jq`;
never source/eval user data; `BASH_SOURCE`-relative inter-script paths.

## Security & Performance

- **Trust boundary is unchanged and, if anything, tightened.** Face `text`/
  `params` remain untrusted data; the aggregator only ever *counts rows* and
  *emits already-validated group slugs* — it never carries face prose into a
  counter. Moving the sort/join/cap into the script removes an LLM string-
  assembly step over shape-validated, security-relevant values (the issue's
  core motivation). `san()` + `is_slug()` gate every emitted cell, so a crafted
  group name or face entry can neither shift TSV columns nor smuggle a path
  (same guarantees `cmd_edges`/`cmd_health` already rely on).
- **No secret surface.** The counters are integers and group slugs only; no
  face content reaches the ledger, so the "never persist a secret" rule is
  satisfied by construction.
- **Performance:** the aggregator re-runs the `cmd_faces` awk pass once per
  blueprint-bearing group — the same per-group read `cmd_contracts_check`
  already does, bounded by group count (single digits in practice). Negligible.

## Recommendations

**1. The event contract is unchanged, so the blast radius is small and every
downstream consumer is insulated.** All consumers read the four counters from
the *ledger event payload* Step 2a writes — never from the aggregator directly:
- `skills/review/scripts/jimledger.sh` 603–616 whitelist + `last-reconcile` /
  `reconcile-series` validators (695, 720);
- `skills/partition/scripts/jimpartition.sh` `cmd_health_eval` 1099–1181 reads
  the latest event's `faces_max` for the `health_threshold_faces_max` predicate;
- `skills/conf/scripts/jimconf.sh` 42/97 (`health_threshold_faces_max` knob);
- `skills/partition/references/partition-methodology.md` (trend reads).

Because the emitted key set, shapes, and emit-only-when-`>0` rule are preserved,
**none of these change.** The refactor touches exactly three artifacts:
`jimverify.sh` (+ its tests), `blueprint/SKILL.md` Step 2a, and the methodology
contract text. This confirms the spec's Out-of-Scope boundary (extraction-side
validation untouched).

**2. Value-parity is the acceptance backstop.** `tests/jimledger.sh` 1319–1362
already fixes the payload shapes the counters must produce (multi-slug accept,
bad-value excluded, `na` handling). New `jimverify.sh` cases should assert the
aggregator emits exactly those shapes — sum, max, ties→all sorted join,
all-zero → no attribution, ≤256-byte cap, slug-validated cells — so the
mechanical output is provably interchangeable with what Step 2a produced by hand.

**3. Aggregator home/signature (architect's call — spec Insight 1).** Two viable
shapes, both satisfying the ACs:
- *(a) one verb emits all four* — a `faces-aggregate <map> <specs_root>` that
  also parses/re-emits the graph's fan-in holders (broadens a faces-named verb
  to carry a graph value);
- *(b) faces-only aggregator + mechanical fan-in join* — the verb emits the
  three face values; `fanin_group` is joined from `cmd_health`'s existing
  `FANIN_GROUP` rows in the same call site.

Option (a) gives Step 2a a single copy-source; (b) keeps each verb cohesive to
its data source. The `fanin=` *value* stays out of scope either way (already
mechanical — spec Insight 1). Recommend the architect decide against the
`cmd_contracts_check` two-arg precedent.

## Peer Feedback

None. Research confirms the spec is well-bounded: the type is genuinely a
refactor (event contract preserved), the four-counter scope is correct, and no
finding invalidates an AC or a locked constraint. **Alignment:** ARCHITECTURE.md
(53) names `jimverify.sh` the *"deterministic core"* carrying the
`faces`/`edges`/`contracts-check`/`health` verbs — moving the counter arithmetic
into a sibling verb is precisely the prescribed home, not a divergence. Also
squares with VISION's convention-over-configuration/transparency posture and the
project's mechanical-over-judgment principle (deterministic script over LLM
arithmetic). No `plan.md` exists yet, so no plan-invalidation check applies.
