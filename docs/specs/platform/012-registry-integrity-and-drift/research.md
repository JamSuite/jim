---
spec: "docs/specs/platform/012-registry-integrity-and-drift/spec.md"
status: Active
date: "2026-08-01"
---

# Research: Registry integrity and drift

## Anchors

All in `skills/file/scripts/jimalloc.sh` unless noted; verified 2026-08-01.

**Read path and enumeration**

- `alloc_read_log` (`:97-111`) — the only registry read path; its first branch
  is the `JIMALLOC_REGISTRY_DIR` test seam the sweep must preserve.
- `alloc_seed_derive_specs` / `alloc_seed_derive_issues` (`:792-854`,
  `:859-912`) — the tree enumerators both verbs reuse: they already skip the
  reserved `000` slot and pending `P-` dirs, and halt-and-name on conflicts.
- `alloc_canon_specid` + `ALLOC_MAX_ORD_DIGITS` (`:183-189`, `:326`) — the
  canonical ordinal spelling; both sides of every sweep comparison must cross
  it or a hand-authored `007` reads as drift.

**Publish path (catch-up)**

- `alloc_publish` (`:1615-1687`) — the shared batch-publish: in-loop erosion
  re-check on both logs, tier CAS, bounded retry, baseline arming. Catch-up
  is a new builder on this path.
- `alloc_seed_publish_builder` (`:1695-1712`) — the empty-log precondition
  catch-up bypasses; `alloc_seed_land` (`:1717`) and the preview renderers
  (`:1480-1502`) are the shapes to mirror.

**Hardening riders**

- `alloc_origin_tip` (`:1012-1026`) — AC 12's single locus; both consumers
  call it (`:1189`, `:1634`) and their *local*-tier arms already use
  `git rev-parse --verify --end-of-options` (`:1191`, `:1636`). The
  discipline to mirror is `resolve_head`
  (`skills/ledger/scripts/jimledger.sh:95-107`): git output re-crosses
  `jimfile.sh valid-id`.
- The three last-wins sites for AC 11: `alloc_resolve_issue` (`:288-295`),
  `alloc_resolve_spec`'s anchor loop (`:244-251`),
  `alloc_reconcile_realize`'s `existing[]` map (`:612-618`).

**Verify wiring (AC 13)**

- `skills/verify/SKILL.md:212-225` — the operator-check contract: the model
  resolves `verify_command_<name>` and runs it via Bash under
  `verify_registry_timeout` (default 120s); outcome mapping at `:224` (exit 0
  → holds, clean non-zero → violated, failure-to-execute → failed); registry
  violations are `unlocalized` (`:76`).
- `skills/blueprint/references/check-authoring.md:43`, `:95-104` — the
  `registry:<name>` check grammar; a named check is inert until an operator
  configures the command. The live `jimconf.toml` configures **no**
  `verify_command_*` today (its only dynamic key is `deps_command_refs:9`);
  the slug-gated resolver is `jimconf.sh:116-177`.

**Blast radius**

- No consumer reads `specs.log`/`issues.log` or `alloc_read_log` outside
  `skills/file/` — the registry is reached only through this CLI. Callers of
  `jimalloc.sh`: `skills/issue/scripts/new.sh:99`,
  `skills/issue/scripts/reconcile.sh:134-136`,
  `skills/spec/scripts/reconcile.sh:170-172`, plus `peek`/`allocate` in the
  two SKILL bodies. New verbs break no caller.
- `skills/issue/SKILL.md:6` grants `jimalloc.sh *` (wildcard — new verbs
  auto-permitted there); `skills/spec/SKILL.md:10` grants only
  `peek spec` / `allocate spec`. `skills/file/SKILL.md` (`:10-11`) does not
  mention jimalloc at all — the spec's doc-surface open question is real.
- Registry live state (verified this date): 63 spec + 4 group + 196 issue
  records; tree and registry agree everywhere except the recordless retired
  `jim` group. `jimledger.sh vacated-max` (`:651-694`) parses the split's
  `moved=` pairs — Spec B's raw material, out of scope here.

## Local Patterns

- **Test template: `tests/jimalloc.sh`** (151 cases, testlib framework,
  `case_*` discovery, `OUT`/`ERR`/`RC` capture). Five invoker shapes:
  `run_jimalloc` (`:32`, no repo), `run_jimalloc_reg` (`:62`, the
  `JIMALLOC_REGISTRY_DIR` fixture-log seam — right for pure sweep
  classification), `run_jimalloc_in` (`:765`, real git), `run_seed_fn`
  (`:1414`, sourced pure functions), `run_reconcile_in` (`:1992`, stdin
  batch). Fixture helpers: `alloc_new_repo:775`, `alloc_new_bare:886`,
  `alloc_new_clone:893`, `alloc_provisional_repo:1124` (unreachable origin +
  provisional config — the offline-sweep case's template), `seed_repo:1504`,
  `alloc_append_record:1015` (hand-append a crafted record — the drift
  fixtures' primitive). Representative cases: fold `:457`, local-tier
  allocate `:814`, origin race `:943`, seed apply `:1545`, reconcile `:2003`.
- **Mutation-testing pattern (AC 14)**: `tests/specreconcile.sh:799-812`
  (a fixture extended until it discriminates), PATH-shimmed `awk`
  (`:1087`), shimmed read-only `mktemp` (`tests/issues.sh:726`), plain
  read-only target (`tests/specreconcile.sh:1174`).
- **Degradation naming precedent** for AC 3/4: `jimverify.sh`'s sentinel
  rows — `UNSCOPED`, `COVERAGE`, and especially `UNCOVERED na` +
  `UNCOVERED_NA_REASON` (`:1078-1089`): a count, a distinct `na`, and a
  machine-readable reason why. The sweep's non-coverage classes should take
  this shape, not prose.
- House invariants that bind the new code: `set -uo pipefail` + `LC_ALL=C`,
  parse-never-source, the single id boundary (`jimfile.sh valid-id`),
  `BASH_SOURCE`-relative composition, preview-then-apply for anything that
  writes, sanitized TSV output (verify's `tr`/`cut` pattern) so a crafted
  record cannot shift report columns.

## Security & Performance

- **The sweep consumes attacker-influenceable input twice**: the
  push-writable registry and the working tree. Every token it echoes into a
  report must be revalidated or sanitized — a crafted record must not be able
  to inject report rows or shift columns (verify Finding-7 discipline).
- **Exit-code collision is the sharpest design constraint**: under verify's
  mapping a *clean non-zero* reads `violated`, so a sweep that exits non-zero
  for "could not refresh / could not check" would report drift that isn't
  there. The three outcomes (AC 5) must be assigned with that consumer in
  mind (Insight 3 in the spec).
- **Read-path cost**: the id-boundary fork costs ~56 ms/record measured
  (#142, open), and log length is attacker-influenceable. A CI sweep pays
  this per run over 263 records today; the architect should prefer batch
  validation inside one awk/bash pass over per-record `valid-id` forks.
- **Catch-up shares allocation's accepted residual**: the erosion guard
  detects truncation, not a well-formed append. A catch-up append is exactly
  a well-formed append — its provenance marker (AC 10) is the only forensic
  distinguisher, which is an argument for a distinct marker.
- **Partial-write shape** (#190–#192 class, all fixed 2026-08-01): any file
  or report the new verbs write must check its write status — the three
  recent fixes are the pattern.

## Recommendations

**Alignment:** this approach aligns with VISION.md's executable
institutional-memory pillar (a *verifiable* architectural record) and its
human-in-the-loop doctrine (preview-then-apply on every write), and follows
ARCHITECTURE.md's Bash-vs-Prompt rule — deterministic detection and repair
live in the script; the only judgment surface is the operator's decision at
the apply gate. No divergence from either locked constraint found.

- **Verb naming/placement**: both verbs belong in `jimalloc.sh`'s dispatch
  (`:1959-1970`). Catch-up as `seed --catch-up` (issue #130's sketch) reuses
  the derive+land path but muddies seed's crisp bootstrap-only contract; a
  distinct verb sharing the same builders keeps both contracts clean. Avoid
  "registry" and "verify" in names — both are taken vocabulary in the verify
  skill. Architect's call.
- **Single-sourced classification**: platform/011's lesson (one fold, not
  three copies that agree by convention) applies — compute the per-identity
  classification (present / missing / mismatch / info / uncovered) in one
  pure function that the sweep report, the catch-up preview, and the
  catch-up builder all consume, so detect and repair can never disagree
  about what is missing.
- **Machine-readable output**: the sweep's primary consumers are CI and
  verify (exit code only, unlocalized). Sanitized TSV facts + a human
  summary line, per `jimverify.sh`'s house shape, beats bespoke prose.
- **Verify wiring**: AC 13 needs only a blueprint invariant naming a
  `registry:<slug>` check; whether this repo's `jimconf.toml` gains the
  `verify_command_*` entry at build time is an operator step worth doing as
  the dogfood proof (none exists today, so the rung has never actually run
  here).

## Peer Feedback

None — no plan exists yet, and nothing found invalidates a spec requirement.
The two spec Open Questions (the #121 ordering, the doc-surface home) are
confirmed real by the scan: the seed's `"000"` literal is live at `:817`, and
no jim surface documents the allocator verbs today.
