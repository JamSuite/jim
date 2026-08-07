---
spec: "docs/specs/issue/011-issue-placement/spec.md"
status: Active
date: "2026-08-06"
---

# Research: Issue placement — configurable issue content location

## Anchors

**Issue write paths (all must route through placement — AC #3):**

- `skills/issue/scripts/new.sh:126-132` — issues-dir resolution: `--dir` override, else `jimfile.sh path issue`; no `-c` config seam.
- `skills/issue/scripts/new.sh:141-154` — local-collision handling reads the destination directory to decide provisional suffixing; under placement it must read the *destination* collection, not the working branch.
- `skills/issue/scripts/new.sh:185-211` — atomic write: `mktemp` *inside the destination dir* → compose → `mv`; the destination must exist and be writable at write time.
- `skills/issue/scripts/index.sh:262-274, 497-559` — INDEX resolve + atomic write; final `touch` (`:559`) exists solely to feed render's mtime staleness gate.
- `skills/issue/scripts/reconcile.sh:60-62, 148-204` — the only issue script forwarding `-c` to the allocator; realize rewrites `num:` per file (tmp+mv), never renames files.
- `skills/issue/scripts/backfill.sh:125-195`, `migrate.sh:164-250` — the migration write loops; `migrate.sh:151-157` holds the issue scripts' only git call today (`git -C "$dir" status`), a natural placement hook.

**Issue read paths (AC #5/#6):**

- `skills/issue/scripts/render.sh:55-61` — collection resolve (no `-c` seam; tests drive it by `cd`-ing into a dir holding `jimconf.toml`).
- `skills/issue/scripts/render.sh:69-95` — mtime-based staleness gate + `ensure_index` regen: **the read path writes**; both the mtime mechanism and the write break naive centralization (mtimes don't survive fetches/worktrees).
- `skills/issue/scripts/render.sh:356-368` — the one-shot `jimconf list` config read where `issue_placement` joins `issue_list_*`.

**Config machinery (AC #1/#10):**

- `skills/conf/scripts/jimconf.sh:46` — the `KEYS` array; `tests/jimconf.sh:334,343` assert the exact list.
- `skills/conf/scripts/jimconf.sh:182` — the bare-name vs `_path`-suffix arm: unextended, a key named `issue_placement` would silently look up TOML `issue_placement_path`. Must be extended.
- `skills/conf/scripts/jimconf.sh:324-327` — the project-root-as-CWD invariant: config resolves from `$PWD` with no walk-up. A temp worktree used as `$PWD` reads *that tree's* `jimconf.toml` — and an orphan destination branch carries none.

**Registry-branch precedents (AC #7/#8/#9/#10):**

- `skills/file/scripts/jimalloc.sh:2136-2160` — orphan bootstrap by pure plumbing: `hash-object` → `mktree` → `commit-tree` (empty parent ⇒ root commit) → `update-ref` CAS with expected-empty. **No worktree, no checkout anywhere in jim** (`git worktree` appears in zero executable lines repo-wide).
- `skills/file/scripts/jimalloc.sh:2186-2270, 1968-1972` — the 5-attempt CAS loop: per-attempt tip re-read, builder re-invocation, push-as-CAS (`:2168-2176`), jittered backoff. The builder-recomputed-per-attempt contract (`:2644-2650`) is exactly AC #7's "reapplied and retried" shape.
- `skills/file/scripts/jimalloc.sh:2025-2043` — fetch-before-read discipline; best-effort advisory variant `:2450-2457` (`fetch … || true`) is AC #6's degrade precedent.
- `skills/file/scripts/jimalloc.sh:2325-2348` — reachability probe + defer-to-provisional wiring; `:1954-1961` hard-fails a junk enum value (the refuse-on-junk precedent AC #10 matches).
- `skills/file/scripts/jimalloc.sh:1979-1998` — `alloc_valid_branch` (empty / leading-`-` / `git check-ref-format` — the repo's **only** `check-ref-format` site) and `alloc_coord_branch` (resolves `id_coordination_branch`, default `jim/registry`; the value AC #9's refusal compares against).
- `skills/file/scripts/jimalloc.sh:51` — `GIT_TERMINAL_PROMPT=0`, the repo's only occurrence; any new network-touching git path needs the same posture.

**Commit choreography precedents:** `skills/ledger/scripts/jimledger.sh:172-182` (`commit-review` — literal-path stage+commit, trusted-enum message) and `:214-246` (`commit-map` — the fullest config-derived-path template: `valid-relpath` → toplevel containment → scoped add/commit). The placement auto-commit (AC #4) wants this shape.

**New files:** placement resolution + destination-write primitive (likely `skills/issue/scripts/` or a shared script), `jimconf.sh` key addition, test cases in `tests/issues.sh` + `tests/jimconf.sh`.

## Local Patterns

- **Non-checked-out branch writes are plumbing, not worktrees.** `jimalloc.sh`'s stated intent (`:8-11`): "the developer's working tree is never disturbed", proven by `tests/jimalloc.sh:1421-1429`. The #96 worktree flow is *manually* proven but has zero in-repo code precedent; the plumbing path has both precedent and tests.
- **Config seam inconsistency:** only `reconcile.sh` and `migrate.sh` forward `-c`; `new.sh`, `index.sh`, `render.sh`, `backfill.sh` resolve config from `$PWD`. Any worktree-as-`$PWD` design must first close this seam (or resolve everything in the caller before entering the worktree).
- **Junk-config handling has three precedents:** silent degrade (`render.sh:113-120`), warn-and-fallback (`jimfile.sh:744-770`), hard-fail (`jimalloc.sh:1954-1961`). The spec's refuse stance matches the third.
- **Test template:** `tests/jimalloc.sh:1713-1727` (`case_jimalloc_custom_branch_from_config`) — repo fixture → write `jimconf.toml` → `run_jimalloc_in` (subshell-`cd`, `testlib.sh:233-236`) → assert the effect on the *ref* via `git -C … cat-file -p refs/heads/<branch>:<file>`. Remote fixtures: `alloc_new_bare` (`tests/jimalloc.sh:1434-1438`), unreachable-remote (`:1702`). End-to-end filing analogue: `tests/issues.sh:2327-2342`. Planting content on a non-checked-out branch inside a test: `tests/issues.sh:2478-2481`.
- **Framework:** `testlib.sh` — `fixture`/`empty_dir`/asserts; `set -uo pipefail`, never `set -e`; temp dirs only.

## Security & Performance

- **Branch-name injection:** the config value reaches git argv (fetch/push refspecs, ref paths). Gate it through `alloc_valid_branch`'s shape (empty / leading-`-` / `check-ref-format`) *before any interpolation*; AC #9's coordination-branch refusal belongs at the same gate. Follow the existing `--literal-pathspecs` / `--end-of-options` discipline (`jimledger.sh:313-322`, `jimalloc.sh:2208`).
- **The registry's erosion guard does not transfer.** `specs.log` is append-only, so byte-prefix growth screams on force-push (`jimalloc.sh:2045-2115`); issue content is legitimately edited, so a placement branch has no equivalent tamper tell. A force-push there silently loses mutations — worth naming in the plan's threat notes (branch-protection docs are #118).
- **Staleness gate breaks:** `render.sh`'s mtime comparison (`:69-82`) is a single-checkout artifact; fetched refs and fresh worktrees carry no meaningful mtimes. Centralized reads need a different freshness fact (e.g. destination tip SHA recorded at regen).
- **Read-path cost:** AC #6 implies a network round-trip per read (fetch-before-read is ~1 `ls-remote`/`fetch`); the advisory best-effort pattern (`:2450-2457`) bounds it, but per-read latency is a real cost to weigh at plan time.
- **Read-path write:** `ensure_index` regenerates INDEX on stale reads — under placement, a *read verb* performs a destination write (commit). The plan must decide whether reads regenerate-and-commit, regenerate ephemerally, or refuse-stale.
- **Orphan branch carries no `jimconf.toml`** — script invocations with the worktree as `$PWD` resolve default config, not the project's (`jimconf.sh:324-327`). Sharp edge for a custom `issues_path`.

## Recommendations

1. **Write mechanism — three options for the architect:**
   (a) *Temp worktree* (#96's proven flow: subshell-`cd`, `git -C` commit, remove from primary checkout): maximally reuses existing scripts unchanged, but imports the lifecycle hazards #96 hit (bare-`cd` death ×3) and needs the `-c` seam closed. Orphan destinations keep checkouts tiny; `main` as destination checks out the whole tree.
   (b) *Pure plumbing* (jimalloc precedent): no worktree lifecycle at all, matches the never-disturb-the-working-tree intent, and `alloc_publish`'s builder-per-attempt contract *is* AC #7's retry loop — but `index.sh`/`new.sh` operate on real directories, so the collection must be materialized (e.g. `cat-file` reads) for regen.
   (c) *Hybrid:* materialize the collection into a temp dir for script reuse, commit via plumbing + CAS. Likely the leanest honest composition of both precedents.
2. **Config:** extend `jimconf.sh:182`'s suffix arm; add the key to `KEYS` (`:46`) with default `branch`; decide whether to close the `-c` seam in the four scripts lacking it or resolve placement entirely in a caller layer.
3. **Freshness:** replace the mtime gate under placement with a recorded destination-tip SHA; reads fetch best-effort (`|| true` pattern) and disclose degradation, mirroring `alloc_peek_refresh`.
4. **Validation:** the branch gate is one function today (`alloc_valid_branch`) inside jimalloc; placement needs the same check from issue scripts. Extracting a shared `valid-branch` verb into `jimfile.sh` is cross-group (platform) work — weigh against a SYNC'd copy (the `is_valid_id` three-copy precedent, fourth copy explicitly forbidden per `tests/jimfile.sh`).
5. **Orphan tree layout:** decide at plan time what path the collection occupies inside the destination branch (mirror the configured `issues_path` vs a fixed `docs/issues/`); the spec's observable is only "carries the collection alone".

## Peer Feedback

*For the architect (no spec-invalidation signals; no plan exists yet):* AC #6's fetch-per-read and `ensure_index`'s regenerate-on-read together put both a network hop and a potential destination *commit* inside every read verb — the cost model changes class. The recommendation-3 shape (best-effort fetch + SHA-based staleness) keeps reads cheap; flagging it here so the plan treats read-path cost as a design input, not a surprise.

**Alignment:** Centralizing content at a designated branch aligns with VISION's team-context audience while respecting its non-goal ("not a project-management tool" — the collection stays a discovery artifact; placement changes *where* it lives, not what it is). It follows ARCHITECTURE's registry-branch pattern (`platform/007`: coordination state on a dedicated, inspectable branch, plumbing-not-checkout) and preserves the issue group's blueprint invariants — `single-emitter` (placement wraps the emitter, never adds a second writer), `atomic-index-write`, and `untrusted-body-never-shell`. The coordination branch's registry-logs-only contract is explicitly guarded (spec AC #9).
