# Spec B handoff — rename/redirect record emission

**Written:** 2026-08-02, at the end of the session that cleared B's runway.
Purpose: let a fresh session start `/jim:spec` for B without rebuilding two
days of context. Read this, then the two authoritative artifacts below —
everything else here is the code-level map that is expensive to re-derive.

Line anchors are exact at `c0590e1` (branch `feat/id-coordination`).
`jimalloc.sh` is 2952 lines and moves under every build — re-verify anchors
before planning against them.

## Start here

1. `docs/notes/20260728-id-coordination-issue-grouping.md` — the cluster
   note, ninth revision. Read **§ Spec B** (charter + inherited constraints +
   the *Pre-spec analysis* block: the forks, the scope adds/moves, the
   one-spec-not-two decision) and **§ Sequence**. The runway is clear: the
   pre-B build, the bookkeeping closures, and the #189/#110 territory map
   pass all landed 2026-08-02 (commits `670a3a9..c0590e1`).
2. Issue **#113** (`20260726-emit-rename-split-redirect-records-…`) — B's
   charter, with the two resolver decisions pre-framed as *Inherited
   constraints*, the joint-width-gate section, the retired-`jim` live
   demonstration, and the backfill source. The freshest thinking about B
   lives on this issue, not in any spec.
3. Riders: #143 (realize-lift grammar), #152/#154 (provisional under a
   moving group — settle together, split and merge must agree), #202
   (classifier rename-replay defects — fixture with the emitter, decide
   rename-onto-occupied semantics once for emitter and classifier). Scoping
   riders: #84 + #123 (both die or fall back on the two-next-id-surfaces
   decision). Consult-only: #200 (do not foreclose a precedence/tombstone
   record kind). Fork-dependent: #155 (rides B only if a `P-`-bearing record
   kind enters the registry grammar).

## Ground truth (verified 2026-08-02)

- Registry: local branch `jim/registry`; `specs.log` holds 64 `spec
  allocate` + 4 `group allocate` records (newest `platform/012`),
  `issues.log` through 203. **Zero rename records in both logs** — every
  part of B is still a pre-emission change, which is the property the whole
  sequencing protects.
- This sandbox has no push credentials (`id_coordination_unreachable =
  "provisional"` in jimconf.toml); `git ls-remote` fails. Offline filings
  realize later via the reconcile paths.
- Suite: 1055/1055 (`bash skills/meta-test/scripts/run.sh`). The sweep runs
  clean: `bash skills/file/scripts/jimalloc.sh sweep` → 64v64 specs,
  204v204 issues, `jim` named uncovered, `duplicate-realize-keys 0`, rc 0.
- Cluster accounting: 55 of 83 closed; the enumeration in the note's
  disposition table closes exactly.

## The code map (the expensive part)

### Allocator — `skills/file/scripts/jimalloc.sh` (2952 lines)

- **Frozen grammar** (header `:80-88`): `spec rename <group>/<NNN>
  <newgroup>/<newNNN> <date>` · `group rename <old> <new> <date>` · `issue
  rename <NNN> <newNNN> <date>`. Parsed by every reader, **emitted by
  nothing**: `alloc_encode_allocate_{spec,group,issue}` (`:238-246`) are the
  only encoders. **Rename records have no `<who>` slot** — allocates end
  `<date> <who>` (where `jim-seed`/`jim-catchup` provenance lives), renames
  end at `<date>`. Extending the shape is a grammar change every parser
  rides; not extending it ships anonymous renames — a fork no artifact had
  named before this pass; take it to the interview.
- **Read path, all live and fixtured**: `alloc_resolve_spec` `:260` (anchor
  on allocate or rename-destination; the known-gate doctrine "a rename
  source is a vacating event, not an establishing one" at `:248-259`);
  `alloc_group_alias_map` `:442` (the only group-redirect resolver);
  `alloc_fold_max_spec` `:493` / issue twin (high-water counts rename
  sources — vacated ordinals permanently gapped); `alloc_next_id_spec`
  `:587` (two failure modes: redirect refusal **retryable** via
  `--follow-redirect`, exhaustion **terminal**; returned group is
  authoritative). Width: `ALLOC_MAX_ORD_DIGITS=15` `:419`,
  `alloc_canon_specid` `:212` — **jointly gated** on rename records in the
  resolver (an over-wide source drops its destination's establishing claim;
  per-side in the fold). #113 recommends per-side gating + source-known
  with disclosure, decided together.
- **Batch publish template**: `alloc_publish` `:2070` (one commit,
  all-or-none CAS, erosion re-check, baseline arming, 5 attempts; local
  tier when no remote). The builder pattern to copy for a partition batch:
  `alloc_reconcile_spec_publish_builder` `:2775`.
- **Realize (post pre-B-build contract)**: rows are
  `<pending>\t<id>\t<new|have|blocked>`; a registry-contradicted identity
  gets `<pending>\t-\tblocked` (claimants on stderr) while neighbours land;
  a blocked identity consumes no ordinal. `alloc_reconcile_realize` `:696`
  (issue), `alloc_reconcile_realize_spec` `:831` (spec, keyed on
  alias-resolved (group, slug, date)). **`alloc_spec_claim_keys` `:770`** is
  THE one rule for what claims a realize key — realize folds it, the sweep
  counts it; keep any new reader on it (practice 9).
- **Integrity (platform/012)**: classifier `alloc_classify_spec` `:1158`
  (rename replay carries #202's four defects — unreachable until emission);
  `cmd_sweep` `:2343` (drift exit 3, five non-coverage classes, and the new
  advisory `realize hazards: duplicate-realize-keys`, not drift);
  `cmd_catchup` `:2641` (appends MISSING only, blocks on contradictions,
  marker `jim-catchup`).
- **No rename verb exists on the CLI** — that surface is B's to add. `sweep`
  and `catch-up` have no skill wrapper (operator-run; the verify rung runs
  the sweep via `verify_command_id-sweep` in jimconf.toml).

### Emission surfaces

- **Partition** (`skills/partition/`, **blueprint** territory):
  `cmd_renumber_map` `jimpartition.sh:1331` (split; assign-row gate
  `^[0-9]{3}(-wip)?$` — a `P-` source fails the whole map) and
  `cmd_merge_map` `:1420` (selector `^[0-9]{3}(-.*)?$` — a `P-` dir is
  silently skipped): that asymmetry is #154. Emission hook: the **Close
  steps** in `skills/partition/SKILL.md` (~`:328` rename, `:377` split,
  `:433` merge) where the `moved=` ledger event is composed — the
  map-verb stdout is already `old → new` pairs in the record's shape. The
  merge `<start>` seed is the surviving `jimfile.sh next-id` caller (#123).
  `cmd_rewrite_refs` `:1819` is the partition-side citation rewriter.
- **Ledger** (`skills/ledger/`, **platform**): `move-spec-dir` (the
  cross-parent primitive; source-basename gate `shape=` at
  `jimledger.sh:579` refuses `P-` — widening it is #152's point 1);
  `rename-tracked` (sibling-only); `vacated-max` (dispatch `:1086`) parses
  `moved=` from `op=split|merge` events only — elements gated **exactly 3
  digits** vs the registry's 3–15 (**width mismatch to reconcile at lift
  time**), and `op=rename` events carry **no `moved=`** (group-rename
  records must derive from `old=`/`new=`; #84's `maxid=` proposal lives
  here).
- **Spec realize** (`skills/spec/scripts/reconcile.sh`, **sdlc**):
  `record_realized` `:653` appends `spec realized moved=<g>/P-<tok>:<g>/<NNN>`
  to the specs-root ledger, chunked at 256 bytes, **explicitly built for B
  to lift into registry redirects without re-deriving** (its header says
  so). `apply_pending` `:262` (per-identity halts incl. `blocked`; the
  renamed-group halt #152 fixes is at ~`:270`); `sweep_citations` `:400`
  (tracked + untracked enumeration, symlink discipline); `rewrite_id` `:222`
  (frontmatter + own-H1 self-identity sites).
- **Live lift sources in `docs/specs/ledger.md`**: line 52 — the 2026-07-25
  `jim` split's complete `moved=jim/NNN:<group>/NNN` pair list (~51 pairs,
  the retired-`jim` backfill's mechanical source); line 81 — the first
  `spec realized` event (`platform/P-20260801-…:platform/012`).

### Test landscape

Every rename fixture hand-writes records into fixture logs — **nothing
emits one, and no test covers a rename record's encoding**. The sweep's
`rename-source-ids` assertion asserts zero and cannot fail (noted in
platform/012's review). B's fresh code is exactly: encoders, the partition
batch builder, the lift — practices 5–8 target precisely that list
(fixture the wiring, not just functions; state each guard's premise as a
checkable claim; fan-out before the ledger closes and name it if
suppressed (#188); reproduce criticals before believing them).

## Decisions the interview must settle (with recommendations already argued)

Full argument in the note's *Pre-spec analysis*; one line each:

1. **`<who>`/provenance on rename records** — extend the frozen shape vs
   anonymous renames. Backfill provenance is where anonymity will hurt. No
   recommendation recorded; genuinely open.
2. **Resolver semantics** — source-known gate *with disclosure* + per-side
   width gating, taken together (#113 pre-frames both; recommended there).
3. **Realize-lift record kind** (#143) — `P-` is not a legal rename source;
   grammar-distinct is what keeps the fold safe. New kind vs rule-out. If a
   `P-`-bearing kind lands, #155 becomes load-bearing and rides B.
4. **Two next-id surfaces** (#113 constraint 2) — converge partition onto
   the allocator (kills #84 + #123) vs keep the tree-scan path (then #123
   needs `next-id spec <group>`, #84 needs the `maxid=` rename arm).
5. **Provisional under a moving group** (#152/#154) — refuse vs carry; split
   and merge must agree; `move-spec-dir` source-gate widening either way;
   `group:` frontmatter rewrite regardless.
6. **Backfill** — ship with the emitter vs one-time repair alongside; source
   is the ledger pair list; reconcile the 3-digit/3–15 widths; feeds fork 1.
7. **Home group** — one spec, not two (splitting emitter from
   grammar/readers recreates the three-readers failure platform/012 paid two
   criticals for). Home `blueprint` with platform writes declared; C′ is the
   precedent. Let `/jim:spec`'s assignment advisor confirm.
8. **#200 coordination** — record one DD that the grammar work does not
   foreclose a precedence/tombstone record kind.

Consumer obligations carried in from A: every new consumer distinguishes
the retryable redirect refusal from terminal exhaustion, and treats the
returned group as authoritative.

## Small observation parked for B's completion gate

The `sdlc` blueprint's Requires face declares no `platform.jimalloc` entry,
though `/jim:spec` consumes the allocator directly (the `issue` group does
declare it). Not a reconcile finding (detectors fire on declared data);
fold it when B's gate touches the faces anyway.

## Session provenance

2026-08-02, commits `670a3a9..c0590e1`: ninth revision; pre-B build (#203
per-identity `blocked` on both realize paths + shared claim-key reader +
sweep hazard class; #197 untracked citation sweep; #199 own-H1 rewrite;
#198 grant narrowed); seven issue closures + #189/#110 via the territory
map pass (`e2a5635`, reconcile clean at 22 edges). Working notes for the
build's review observations live in the note's Pre-B build section.

Delete this handoff once Spec B's spec.md exists and has absorbed what it
needs — it is a bridge, not a record.
