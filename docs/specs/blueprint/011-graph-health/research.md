---
spec: "docs/specs/blueprint/011-graph-health/spec.md"
status: Active
date: "2026-07-07"
---

# Research: Graph-health metrics in the reconcile pass

## Anchors

- `skills/blueprint/SKILL.md:411-432` — the reconcile section: ledger-event
  emission with the seven counters (428-429) and the report/issue-offer
  flow; the health block and extended counters land here.
- `skills/blueprint/references/reconcile-methodology.md` § Outcome counters
  and § The report — the documented counter contract AC #4 extends, and the
  report shape the health block joins.
- `skills/review/scripts/jimledger.sh:24,62-74,240` — ledger line format
  (`epoch \t iso \t phase \t event \t kv`, kv pairs joined with `;`); the
  extended counters ride the kv field unchanged.
- `skills/review/scripts/jimledger.sh:444-463` — `updates-since`: the
  event-query precedent (filter `blueprint`/`finished` after a watermark)
  for locating the previous `op=reconcile` event for AC #2's delta.
- `skills/verify/scripts/jimverify.sh:634-657` — `edges` verb: parses the
  persisted `## Contract Graph` into `consumer \t relies-on \t provider`
  TSV (rc 2 when the section is absent; HYGIENE rows for invalid slugs);
  the deterministic input for density/cycles/fan-in.
- `skills/verify/scripts/jimverify.sh:197-241,446-477` — `territory` verb
  and the conformance set-difference mechanics (`git ls-files` + territory
  prefix match); coverage (AC #6) is the union-across-groups complement of
  this per-group logic.
- `tests/jimverify.sh:660-718` — edges-verb cases (present / no-section /
  empty-graph / crafted-cell hygiene); template for metric-verb tests.
- `tests/jimledger.sh:89-97,758-784` — event-append and updates-since
  cases; template for the previous-event query tests.
- **New files:** none required beyond edits — likely a new verb in an
  existing script (see Recommendations) plus test cases in the two files
  above; blueprint SKILL.md + reconcile-methodology.md carry the contract
  and report changes.

## Local Patterns

- **Counter-consumer census (AC #4 blast radius):** no code parses the
  reconcile counters today. The contract surfaces are documentation —
  `skills/blueprint/SKILL.md:428-429`, reconcile-methodology.md § Outcome
  counters, and ARCHITECTURE.md's spec-034 description — plus jim's own
  specs-root `ledger.md` example events. `jimledger.sh metrics` extracts
  git/stage/verdict metrics only; `skills/review/SKILL.md` reads no
  `tier=project` events. Extending the key set is a docs-contract change
  with zero code-consumer migration.
- **Bash conventions:** `set -uo pipefail`, POSIX-only, awk-based parsing
  (`CLAUDE.md → Bash scripts`; canonical header
  `skills/meta-test/scripts/testlib.sh`).
- **Test template:** `tests/jimverify.sh` (testlib framework, `OUT=$(...)`
  capture, temp-dir fixtures; scaffold via `/jim:meta-test`).
- **Validation precedent:** `jimledger.sh:361-392` validates extracted
  metric values (numeric / enum) before display — the shape-validation
  pattern the extended counter set inherits.

## Security & Performance

- **Counter integrity:** health counters must be script-computed integers,
  never values lifted from graph/face content — a crafted group name or
  face entry must not be able to inject `;`-separated kv text into the
  event line (the emitters sanitize, but the new verb must too; edges verb
  already sanitizes tabs/CRs and caps cell length at 512).
- **Not-computable encoding risk:** the 034 pattern is "fixed key set,
  non-negative integers, always emitted." AC #7's explicit not-computable
  coverage state needs a documented carve-out (sentinel value or
  documented-absent key) or shape-validating consumers will choke on it —
  the contract update in AC #4 must cover this explicitly.
- **Ordering risk:** the run must measure the graph it just persisted
  (write `## Contract Graph`, then compute from it) — measuring a
  conversation-held edge list would break AC #9's determinism and could
  diverge from the persisted truth.
- **Performance:** graphs are group-scale (tens of nodes), `git ls-files`
  is already used per-run by conformance; one extra whole-tree pass for
  coverage is negligible.

## Recommendations

1. **Computation home:** the graph-metric verb fits `jimverify.sh` (it
   already owns `edges`/`territory` parsing and the facts-not-verdicts
   doctrine); the previous-event lookup fits `jimledger.sh` (the
   `updates-since` filtering pattern, returning the prior `op=reconcile`
   kv field). Architect picks the exact verbs.
2. **Measure the persisted graph:** compute metrics by parsing the
   just-rewritten `## Contract Graph` via the `edges` verb — single source
   of truth, deterministic, and free test fixtures already exist.
3. **Cycle metric definition:** from the edge TSV, Kahn-style iterative
   peeling of zero-degree nodes leaves exactly the nodes on cycles —
   POSIX-awk-friendly, O(V+E), deterministic; report "groups on cycles"
   (0 when acyclic) rather than enumerating elementary cycles. SCC
   counting (Tarjan) is the heavier alternative if per-cycle membership
   naming in the report needs grouping.
4. **Integer encodings:** `groups=`, `cycles=`, `fanin_max=`, `uncovered=`
   as non-negative integers; density derived by consumers (and rendered in
   the report) from `edges=`/`groups=`; coverage's not-computable state as
   a documented sentinel distinct from `0`.
5. **Delta rendering:** baseline detection = no prior `op=reconcile`
   finished event on the specs-root ledger; render `(was N ↑/↓)` per
   metric only when a prior event exists.

This approach aligns with VISION.md (transparency over automation — a
standing, visible signal instead of a hidden diagnostic) and follows
ARCHITECTURE.md's established patterns: the spec-034 counter/ledger
doctrine, mechanical-content exemption (the health block carries no intent
authority), the Bash-vs-Prompt split, and content-free ledger events. No
divergence identified.
