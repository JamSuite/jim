---
spec: "docs/specs/blueprint/025-rename-redirect-record-emission/spec.md"
status: Active
date: "2026-08-02"
---

# Research: Rename/redirect record emission

## Anchors

Verified at HEAD (`feat/id-coordination`); file sizes: `jimalloc.sh` 2952,
`jimledger.sh` 1102, `jimpartition.sh` 2128, spec `reconcile.sh` 800,
`jimfile.sh` 1206 lines.

**Grammar and encoders (platform writes)**

- `skills/file/scripts/jimalloc.sh:80-88` — the frozen record grammar; rename
  shapes end at `<date>` (AC 1 extends them), and the header's own note says
  the format is frozen "so a later spec can begin emitting them unchanged."
- `jimalloc.sh:232-246` — the three allocate encoders; no rename encoder
  exists anywhere in the file, so AC 1's writers are net-new.
- Readers that ride the shape change (AC 1's blast radius, seven sites):
  resolver establishing-scan + replay (`alloc_resolve_spec` `:260-324`, rename
  arms `:292-304`/`:314-320`; issue twin `:341-411`, arms `:388-395`/`:405-407`),
  alias map (`alloc_group_alias_map` `:442-470`, collect `:449-451`), high-water
  folds (`:493-526` at `:509-510`; issue `:538-559` at `:546-547`), classifiers
  (`:1158-1251`, arms `:1184-1202` — #202's defects; issue `:1258-1338`, arms
  `:1290-1303`), group coverage (`alloc_group_has_records` `:2218-2231` —
  rename records count as coverage), sweep (`:2427`/`:2445`
  `rename-source-ids`), catch-up (`:2641-2690`, allocate-only today).
- `jimalloc.sh:212-218` (`alloc_canon_specid`) + `:419`
  (`ALLOC_MAX_ORD_DIGITS=15`) — the joint width gate AC 8 splits per side.
- Provisional-grammar copies AC 15 unifies: `jimalloc.sh:155-180`,
  `jimfile.sh:386-415`, spec `reconcile.sh:113-122`.

**Publish path (AC 4/5)**

- `jimalloc.sh:2070-2142` — `alloc_publish`, the one-commit CAS template
  (builder contract `:2063-2069`); four builders exist, the closest pattern
  for a partition batch is `alloc_reconcile_spec_publish_builder` `:2775-2806`.

**Emission surfaces (blueprint writes)**

- `skills/partition/SKILL.md:328-338` / `:377-380` / `:430-438` — the
  rename/split/merge Close steps; split/merge already hold map-verb stdout as
  `old→new` pairs, the rename Close holds `old=`/`new=` only and carries no
  `moved=` (group-rename lifting must derive, not copy).
- `jimpartition.sh:1365` (split source gate hard-fails a `P-` row) vs `:1453`
  (merge selector silently skips one) — the #154 asymmetry AC 10 replaces
  with symmetric preflight refusals.
- `jimpartition.sh:1437-1439` — merge `<start>` validated `^[0-9]{3}$`; the
  seed is model-copied from `jimfile.sh next-id` stdout (`SKILL.md:413`), not
  a script-level call.

**Realize path (sdlc writes)**

- Spec `reconcile.sh:653-678` — `record_realized`, the `spec realized moved=`
  writer (≤256-byte chunks); its header `:631-634` says it exists so this
  lift "never re-derives"; `:650-652` notes the events are inert to the
  vacated floor.
- `jimledger.sh:567-649` — `cmd_move_spec_dir`, the cross-parent primitive;
  source-basename gate `:579-582` refuses `P-` (AC 11 widens source side only).

**Lift inputs (AC 12/13/17)**

- `jimledger.sh:663-692` — `cmd_vacated_max`: the `moved=` parsing precedent;
  op gate `:681` consumes `op=split|merge` only, element gate `consider()`
  `:665-671` requires exactly-3-digit ordinals (`:667`) against the
  registry's 3–15 — AC 17's width mismatch, located.
- `docs/specs/ledger.md:52` — the 2026-07-25 `jim` split's complete `moved=`
  pair list (AC 13's backfill source); `:81` — the first `spec realized` event.

**Retirement target (AC 9)**

- `jimfile.sh:303-373` — `cmd_next_id`; spec-group branch `:325-372` with the
  vacated-max consult `:349-364`. Repo-wide grep: **no production script
  shells out to the spec-group form** — only tests and the model-copied
  partition instruction consume it.

**Tests**

- `tests/jimalloc.sh` — 226 cases; every rename fixture hand-writes records
  as printf strings (e.g. `:157-168`, `:495-500`, `:2099-2107`); zero
  encoder coverage exists — B's emission fixtures are the first.

## Local Patterns

- **Test template:** `tests/jimalloc.sh` on
  `skills/meta-test/scripts/testlib.sh` — `case_*` discovery, `run_jimalloc`
  invoker, OUT/ERR/RC capture under `set -uo pipefail` (never `set -e`),
  printf-composed fixture logs in per-runner mktemp sandboxes; scaffold new
  files with `/jim:meta-test scaffold`.
- **Builder pattern:** publishers compose record lines, `alloc_publish` CASes
  them atomically; copy the reconcile spec builder.
- **Untrusted-element gating:** `consider()` in `vacated-max` and
  `record_realized`'s element gates (`reconcile.sh:660-663`) are the
  charset-gate idiom the lift mirrors.
- **One-rule discipline:** `alloc_spec_claim_keys` (`jimalloc.sh:770-795`) is
  the extraction pattern for the new shared rename-parse rule (practice 9).
- **Marker precedent:** `jim-seed` / `jim-catchup` live in the `<who>` slot as
  single grep-able tokens.
- **Leniency finding:** today's readers tolerate trailing tokens — the fixture
  at `tests/jimalloc.sh:495-500` feeds a six-token rename record
  (`… 20260727 x`) and the fold accepts it. AC 1's one-shape strictness is
  therefore a *reader* behavior change too, not just new writers; fixture the
  5-token (missing `<who>`) and 7-token cases explicitly.

## Security & Performance

- **The lift crosses a trust boundary.** The specs-root ledger is
  push-writable branch content; a tampered `moved=` pair must never mint a
  registry redirect (AC 12; sdlc/017 security review Finding 5). Layered
  defense: element charset gates, registry corroboration, and the
  emitter/classifier occupied-destination refusal (AC 6).
- **Phantom resolution** (measured on #113): the source-known resolver gate
  makes a crafted rename source resolvable — the disclosure output is the
  mitigation, and the incoherent-log shape (same source renamed twice, no
  allocation) must stay loud, not resolve confidently.
- **Hard cutover risk:** a 5-token rename record post-extension must fall to
  the sweep's unreadable-record class, not half-parse. Zero rename records
  exist in both live logs (re-verified this session), so there is no
  migration exposure — but only a fixture proves the fall-through.
- **CAS contention:** `alloc_publish` bounds retries; a split's ~50-pair batch
  is one commit, so contention cost is per-batch, not per-pair.
- **Self-referential realization:** this spec's own provisional identity will
  realize through the machinery it builds; the realize path must stay green
  at every commit of the build (the suite is the guard).

## Recommendations

1. **Live-vs-lift** (Handoff Insight 5): realization already publishes an
   allocate batch at realize time — emitting the realization record in that
   same CAS leaves the lift purely backfill/repair, sharpening its
   idempotency contract. Trade-off: two writers of one record kind vs a
   stale window between realize and a later lift run.
2. **`vacated-max` orphaning:** retiring the tree-scan next-id path removes
   `vacated-max`'s only production consumer. Decide retire-with-it (lean;
   the registry fold subsumes the floor) vs keep as an operator verb; a
   half-retired verb with no caller is the worst outcome.
3. **Strict-shape parsing via one rule:** implement AC 1 by extracting a
   single rename-parse rule all seven readers call (the claim-keys pattern) —
   the trailing-token leniency then dies in one place instead of seven.
4. **Lift verb home:** the registry writer (`jimalloc.sh`) owns the verb and
   publish access; ledger parsing stays in the ledger CLI, composed via the
   `BASH_SOURCE`-relative convention (ARCHITECTURE.md → Scripting Layer).
5. **Group-rename lifting derives:** `op=rename` events carry no pair list —
   the lift needs the registry fold's own group inventory at lift time,
   corroborated rather than transcribed.

**Alignment:** this work serves VISION's executable-institutional-memory
pillar — commit trailers and citations stay dereferenceable, so the archive
remains navigable — and observes ARCHITECTURE's locked constraints: the
single `is_valid_id` boundary (AC 15 tightens the grammar wrapped around
it), untrusted git/ledger content discipline (Security Considerations), zero
third-party dependencies, and ordinals minted only through the coordination
allocator (AC 9 completes that rule for partition). No divergence found.
