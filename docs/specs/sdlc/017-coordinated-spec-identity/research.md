---
spec: "docs/specs/sdlc/017-coordinated-spec-identity/spec.md"
status: Active
date: "2026-07-30"
---

# Research: Coordinated spec identity

## Anchors

**The consumer flow being rewired**

- `skills/spec/SKILL.md:10` — the `allowed-tools` grant; `jimalloc.sh` is
  absent today (repo-wide, only `skills/issue/SKILL.md:6` grants it), so the
  wiring adds a grant.
- `skills/spec/SKILL.md:89-103` — Step 3's ledger-open: the bind-at-open
  `next-id <group>` call the advisory peek replaces.
- `skills/spec/SKILL.md:175-210` — Step 8's assign/rename/write sequence: the
  bind-at-write landing zone; `:196` states the "no transient path leaks
  downstream" ordering doctrine a provisional identity extends (a `P-` dir
  path captured as a candidate-batch `origin` goes stale at realization).

**The allocator (platform substrate, already built or stubbed)**

- `skills/file/scripts/jimalloc.sh:1149-1164` — `alloc_provisional_spec`:
  provisional issuance is already shipped; its docstring records "spec-side
  reconcile (a directory rename) is deferred" — the half this spec adds.
- `jimalloc.sh:1606-1608` — the `reconcile spec` refusal this spec replaces
  with a realizer.
- `jimalloc.sh:1407-1479` + `:1529-1550` — `alloc_publish` and the issue
  reconcile builder: the erosion-guarded, one-CAS batch landing a spec
  realizer must ride (the durability AC forbids a second, weaker write path).
- `jimalloc.sh:397-453` — `alloc_next_id_spec`: peek's engine; its docstring
  enumerates the two refusal modes (retryable redirect vs terminal
  exhaustion) the consumer must classify.
- `jimalloc.sh:1168-1192` — `alloc_allocate_spec`: the provisional branch
  (`:1187-1190`) and CAS path the interview calls.

**The paths being stranded or extended**

- `skills/file/scripts/jimfile.sh:295-360` — `cmd_next_id`'s spec branch (tree
  scan + `vacated-max` floor): what `/jim:spec` stops calling.
- `jimfile.sh:362-424` — `cmd_mv_spec`: **same-id renames only** — the single
  `<id>` argument drives both source glob and target name and must match
  `^[0-9]{3}$` (`:381-384`, `:398`), so neither the realization rename
  (`P-…` → `NNN`) nor a peek-shift rename is expressible; a new verb or a
  widened grammar is needed. `jimfile.sh` references `jimalloc.sh` nowhere
  (verified, 0 hits).
- Legacy call-site census (exhaustive over `skills/` + `agents/`): spec-group
  `next-id` invocations exist only at `skills/spec/SKILL.md:92`, `:180`, and
  the partition merge-seed instruction (`skills/partition/SKILL.md:413`,
  `references/partition-methodology.md:642`). The partition caller stays
  (retired by the rename-emitting follow-on); `agents/` has zero hits.

**The consumer precedent (issue side, shipped by `issue/010`)**

- `skills/issue/scripts/new.sh:93-160` — one `allocate issue` call, tab-split
  return (`:101-102`), the two-grammar `num` guard (`:114-122`), provisional
  filename-collision suffixing with `num` re-mirror (`:135-152`), and the
  registry-drift hard error (`:153-156`).
- `skills/issue/scripts/reconcile.sh:84-107` (`scan_pending`), `:110-124`
  (`realize_mapping`), `:168-205` (`cmd_reconcile`) — the realizer control
  skeleton to mirror; `:127-136` (`rewrite_num`) is the issue-specific part a
  directory rename replaces. It records no ledger event — the realization
  redirect record has no precedent here (see Ledger below).

**Ledger and citation machinery**

- `skills/ledger/scripts/jimledger.sh:665-678` + `:76-88` — `event` validates
  no phase allowlist (any token appends verbatim), so the realization event
  needs zero write-side script change; `:804` (`LEDGER_STAGES`) — `metrics`
  iterates a fixed 8-stage allowlist, so an unknown phase is silently
  invisible to metrics (extend only if realization should be measured);
  `:653-654` — `vacated-max` filters to `op=split`/`op=merge`, so a
  realization event is provably inert to the `next-id` floor.
- `skills/partition/scripts/jimpartition.sh:1782-1802` — `cmd_rewrite_refs`:
  whole-token, remap-as-whitelist citation rewriting that matches dir-path
  prefixes as well as typed refs — the right sweep precedent for realization
  (contrast `skills/issue/scripts/migrate.sh:274-296`, which deliberately
  excludes `origin:` paths — correct for issue ids, wrong for spec dirs whose
  *path* is the citation).

## Local Patterns

**Test template** (framework: hand-rolled bash, `testlib.sh` asserts/fixtures,
`case_*` discovery): `tests/jimalloc.sh` is the primary template, with three
invoker shapes a spec realizer needs — the `JIMALLOC_REGISTRY_DIR` fixture-log
seam (`:62-68`), function-level piping for the pure realize layer
(`run_realize`, `:1472-1479`), and real-repo invocation (`:652-658`,
`alloc_new_repo` `:662-669`). The unreachable-origin fixture is
`alloc_provisional_repo` (`:949-955`): a remote pointing at a nonexistent path
plus a provisional-mode `jimconf.toml`. Representative cases:
`case_jimalloc_provisional_spec_offline` (`:981-996` — the case this spec
extends; its comment defers reconcile to #112/#113),
`case_jimalloc_reconcile_realize_mapping` (`:1484-1496`),
`_high_water_parity` (`:1531-1545`), `case_jimalloc_peek_spec_no_mutation`
(`:1064-1075`). Consumer-side: `tests/issues.sh` `run_issue_reconcile_in`
(`:78-85`) and the reconcile cases (`:2384-2500`) — note they fixture pending
state via hand-written frontmatter; only the filing side fixtures an
unreachable remote (`:2280-2297`).

**Conventions to follow:** the preview-then-apply one-shot family
(`reconcile.sh`, `migrate.sh`, `seed`) for the realizer; `new.sh`'s
provisional disambiguation (suffix + re-mirror) as the spec-side analog for
same-day-same-slug offline collisions; `set -uo pipefail`, `LC_ALL=C`,
BASH_SOURCE-relative composition, parse-never-source throughout.

## Security & Performance

- **Push-writable registry, dir-names-as-identity:** the realizer reads
  provisional identity from directory names and registry-returned tokens —
  every token passes `jimfile.sh valid-id` before reaching a path, a git
  argument, or the allocator (`scan_pending`'s revalidation precedent; the
  spec's External Constraint AC).
- **Realization breaks path citations if the sweep is too narrow:** issue
  `origin:` fields cite the spec *path*; `index.sh` flags broken origins as
  integrity warnings. The sweep must cover path-shaped sites (partition
  precedent), not just typed refs.
- **Refusal classification hazard:** the allocate-path refusal emits two
  stderr lines (`platform/011` review Finding 6); classifying by last line
  misreads a retryable redirect as generic failure.
- **Mid-interview network risk:** bind-at-write keeps an unreachable-point
  failure from destroying the interview (G7); `GIT_TERMINAL_PROMPT=0` already
  forecloses credential hangs.
- **Cost:** one fetch+push round-trip per spec creation — the same class
  `issue/010` accepted per filing; `peek` refresh is best-effort and
  non-fatal offline.

## Recommendations

1. **Realizer shape:** implement `reconcile spec` in the allocator (replacing
   the `:1606` refusal) with a pure realize function mirroring
   `alloc_reconcile_realize`'s find-or-allocate + `alloc_publish` landing;
   drive it from a consumer skeleton mirroring `reconcile.sh:168-205`. The
   idempotency key needs care: specs have no registry-side durable id — the
   provisional token (date-slug) + group is natural, but slug uniqueness
   within a group is unenforced (spec Handoff Insight 2).
2. **Directory rename:** extend `jimfile.sh` with a cross-id rename (new verb
   or widened `mv-spec` grammar) rather than raw `mv` in a skill — keeps the
   single path/id boundary. Needed twice: peek-shift at bind, `P-`→`NNN` at
   realize.
3. **Citation sweep:** follow `jimpartition.sh rewrite-refs` (whole-token,
   remap-as-whitelist, dir-path prefixes included), not `migrate.sh`'s
   structured-sites-only scope.
4. **Ledger redirect record:** any phase token appends without script change;
   keep it out of `LEDGER_STAGES` (realization is not a stage) unless metrics
   visibility is wanted; `vacated-max` inertness is already structural.
5. **Interview wiring:** Step 3 uses the existing `peek spec` (redirect
   refusal surfaces there → present the consent question conversationally,
   pass `--follow-redirect` only after the developer agrees); Step 8 binds
   via `allocate spec`; add the `jimalloc.sh` grant to `allowed-tools`.

**Alignment:** this approach aligns with VISION's "not a black box" and
human-in-the-loop pillars (visible preview-then-apply realization, explicit
redirect consent) and follows ARCHITECTURE's Scripting Layer constraints
(bash+POSIX only, single `is_valid_id` boundary, BASH_SOURCE composition,
registry parsed as data) and the Bash-vs-Prompt rule (deterministic realize
logic in scripts; interview judgment in the skill). No divergence from locked
constraints found.
