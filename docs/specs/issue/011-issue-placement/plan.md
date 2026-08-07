---
title: "Issue placement — configurable issue content location"
spec: "docs/specs/issue/011-issue-placement/spec.md"
type: feature
status: approved
---

# Issue placement — configurable issue content location — Plan

## Overview

A new `skills/issue/scripts/place.sh` primitive materializes the destination branch's collection into a temp dir, runs the existing issue scripts against it unchanged, and commits the result back via git plumbing with CAS-and-graft retry — no `git worktree`, no checkout. Placement awareness lives *inside* the entry scripts (self-routing), so every existing caller — including all eight candidate-batch surfaces — inherits it without modification.

## Design Decisions

### 1. Write mechanism — materialize-and-plumb, not `git worktree`

- **Chosen:** `place.sh` extracts the destination tip's collection into a `mktemp -d` dir, runs the wrapped command against it (scripts already accept a dir argument / `--dir`), then builds the commit with plumbing — `hash-object` → `mktree` → `commit-tree` → ref CAS → push — the exact discipline of `alloc_build_commit`/`alloc_cas_append` (`jimalloc.sh:2136-2270`).
- **Why:** Zero worktree lifecycle (no subshell-`cd` deaths, no stale `worktree` metadata, no orphan-checkout weirdness — sec Finding 5 shrinks to one temp-dir trap); the working tree is never disturbed (the registry's stated intent, proven by `tests/jimalloc.sh:1421-1429`); and the wrapped command runs with **CWD = primary checkout**, so jimconf/jimalloc resolve the project's real config (sec Finding 6 solved structurally, not by convention).
- **Rejected:** *Temp `git worktree`* (#96's manual flow) — proven by hand but zero code precedent, imports the lifecycle hazards #96 hit three times, and an orphan destination checkout carries no `jimconf.toml`. *Pure in-place plumbing without materialization* — `index.sh`/`new.sh` operate on real directories; rewriting them to read via `cat-file` is far more invasive than materializing.
- **Containment (security Finding 7 — Critical):** destination-branch content is untrusted, so extraction is gated per entry, never bulk. Enumerate with `git ls-tree -r --name-only -z` and, for each path, require `jimfile.sh valid-relpath` to pass **and** a `realpath -m` resolution to stay under the temp root (the `alloc_write_contained` / `commit-map` precedent) before the entry's blob is written. The first non-conforming entry aborts the whole materialization at rc 2 with the path named — no partial tree is left behind and no wrapped command runs. Never `git archive | tar -x` or any bulk extractor that honors tree-supplied paths directly.

### 2. Self-routing entry scripts, not caller-side wrapping

- **Chosen:** Each entry script (`new.sh`, `index.sh`, `render.sh`, `reconcile.sh`, `backfill.sh`, `migrate.sh`) resolves `issue_placement` early; under a branch-name placement (and no valid run token, and no explicit `--dir`/dir-arg override), it re-execs itself through `place.sh`, which re-invokes it with the token set and the materialized dir.
- **Sentinel shape (security Finding 10):** the suppression signal is **run-scoped, not boolean**. `place.sh` generates a per-run token (the temp-dir basename), exports it as `JIM_PLACE_TOKEN`, and passes the same value to the re-exec'd script as `--place-token <tok>`; routing is suppressed only when the environment value and the passed value match. A stale or hand-exported variable therefore matches nothing, is ignored, and is disclosed on stderr — an inherited env var can never silently disable centralization and land writes on the working branch at rc 0.
- **Why:** AC #3's "every surfacing skill's candidate batch alike" holds structurally: the emitter is the single write door (blueprint invariant), so making the door placement-aware means zero edits to the eight surfacing skills' batch blocks and no §7a contract change for callers. Caller stdout contracts keep their shape.
- **Rejected:** Skill-level routing (each SKILL.md invokes `place.sh run -- new.sh …`) — cross-group edits to eight SKILL.md files, and any future ninth caller silently misses placement.

### 3. Retry = per-file graft + INDEX regeneration — never re-run, never re-push

- **Chosen:** `place.sh` records the base tip and the wrapped command's changed-file set — **additions, modifications, and deletions** (a rename is a delete + create pair; security Finding 8). On a lost CAS/push race: re-fetch, then replay each changed path against the fresh tip under one rule — if the destination's copy is unchanged since base, apply ours (write for add/modify, remove for delete); if it also changed, **refuse** (rc 3, path named, guidance to re-run). `INDEX.md` is never grafted: it is derived, so it is regenerated fresh (`index.sh`) on the merged tree every attempt.
- **Why:** Satisfies sec Finding 3 exactly (the mutation is reapplied onto the winner's state; a stale tree is never re-pushed) and AC #7 ("never silently lost" — a refusal is not a loss; the local commit and temp state survive). Crucially it never re-runs the wrapped command, so a filing's `allocate issue` call cannot double-allocate an ordinal on retry. Carrying deletions is what keeps a renaming mutation (`migrate.sh prefix`) from resurrecting its old filename on a graft — two files for one issue, duplicate ordinals in the regenerated INDEX, at rc 0.
- **Rejected:** *Re-run the command per attempt* (the registry's builder contract, literally) — re-running `new.sh` re-allocates, burning an ordinal per lost race. *File-level last-writer-wins* — erases the concurrent edit at rc 0; the defect sec Finding 3 names.

### 4. Config keys and the validation gate

- **Chosen:** Two bare-name keys in `jimconf.sh` — `issue_placement` (default `"branch"`) and `issue_placement_ack` (default `"false"`) — added to `KEYS` (`:46`), `default_for` (`:52-109`), and the `:182` bare-name arm (without which `issue_placement` silently reads TOML `issue_placement_path`). Validation lives in `place.sh`, before any git interpolation: empty / leading `-` / `git check-ref-format refs/heads/<v>` (mirroring `alloc_valid_branch`, `jimalloc.sh:1979-1984`), plus refusal when the value equals the resolved coordination branch (`jimconf get id_coordination_branch`, default `jim/registry`). Any failure → rc 2 with the value named; reads and writes both refuse (AC #9/#10). `--literal-pathspecs` / `--end-of-options` discipline on every git call that takes a derived argument.
- **Why:** `jimconf` stays a dumb resolver (its house shape); the refuse-on-junk stance matches the allocator's precedent (`alloc_preflight`, `jimalloc.sh:1954-1961`) — the one of jim's three junk-config postures where silent fallback would misplace a team's data.
- **Rejected:** Extracting a shared `valid-branch` verb into `jimfile.sh` — an additive platform-face change with cross-group blast radius for three lines that both sites already delegate to the same `git check-ref-format`; deferred as a follow-on (the filed `fixture-the-invalid-id-coordination-branch-refusal` issue stands on its own either way).

### 5. Freshness and rewrite detection — a local bookmark ref

- **Chosen:** `place.sh` keeps the last-seen destination tip in a local ref, `refs/jim/issue-placement/<branch>`, updated after every successful read fetch and publish. Reads fetch best-effort (`git fetch … || degrade`, the `alloc_peek_refresh` pattern) and disclose "serving last-seen state" on failure; writes attempt the fetch and build on the freshest local knowledge. After any fetch, if the bookmark is not an ancestor of the new tip (`git merge-base --is-ancestor`), the run discloses the rewrite loudly — both SHAs named — then advances (AC #12: detect and disclose, not block).
- **Why:** Render's mtime staleness gate is a single-checkout artifact that cannot survive placement; a recorded tip is the only honest freshness fact. Because every mutation regenerates `INDEX.md` at the destination (DD 3), **the destination's index is always current — reads never regenerate**, which answers the research Peer Feedback (read cost = one best-effort fetch + one materialization; no read-path commit, ever).
- **Rejected:** Committing regen from the read path — turns reads into writes (the Peer Feedback's worry). A shared/state file instead of a ref — worse hygiene than the plumbing jim already trusts for exactly this.

### 6. Checked-out destination — direct mode

- **Chosen:** When the destination *is* the currently checked-out branch, plumbing ref updates would desync the working tree; `place.sh` instead writes in-tree and commits path-scoped (`git add -- <paths>` / `commit -- <paths>`, the `jimledger.sh commit-*` shape), then pushes; a rejected push discloses divergence with resolution guidance (pull, then re-push) rather than auto-rebasing the user's checkout.
- **Dirty-path guard (security Finding 9):** before staging, check the target paths for uncommitted changes (`git status --porcelain -- <paths>`, the `migrate.sh:151-157` precedent). Pre-existing modifications at those paths are disclosed and the run refuses (rc 2, paths named) rather than absorbing a developer's half-finished manual edits into the mutation's commit and publishing them.
- **Why:** Auto-rebasing a checked-out branch under the developer is invasive and failure-prone. The mutation is committed locally — nothing is lost (AC #7's substance); full automatic graft-retry applies on the plumbing path, which is the actual team scenario (working on a feature branch, destination not checked out).
- **Rejected:** Plumbing ref-update on the checked-out branch — leaves the index/working-tree stale (appears as phantom staged changes). Refusing the case — filing from `main` with `issue_placement = main` must work.

### 7. Orphan bootstrap and tree layout

- **Chosen:** A destination that exists neither locally nor at the remote is created on first write as a parentless `commit-tree` (empty `$parent` — the registry-branch birth, `jimalloc.sh:2146-2148`) whose tree holds the collection at the project's configured `issues_path`, mirroring the repo layout.
- **Why:** Registry precedent as decided in the interview; mirroring `issues_path` keeps a checkout of the branch self-describing ("not a black box").
- **Rejected:** A fixed `docs/issues/` regardless of config — diverges from what every script would resolve; a full-tree fork of the default branch — drags the whole repo into every materialization.

### 8. Ad-hoc edits — two-phase `begin`/`commit`

- **Chosen:** For agent-interactive mutations with no single wrapped command ("close issue #5" — §6a's direct-Edit convention), `place.sh begin` materializes and prints `<token>\t<dir>`; the agent Edits files there; `place.sh commit <token> --msg <verb> [--msg-id <slug>]` publishes through the same graft engine (per-file replay against the recorded base; conflict → rc 3, temp state preserved for retry); `place.sh abort <token>` discards. The `/jim:issue` `insights` verb reuses `begin --read`/`abort` to hand the analyst a materialized collection.
- **Why:** Keeps untrusted content out of shell composition (no `bash -c` gymnastics — security 025 F5) while giving every §6a mutation a placement door. A crash between begin and commit strands only a temp dir — disclosed by `commit`'s token validation, cleaned by `abort`.
- **Rejected:** Scripted micro-verbs for every mutation kind (set-status, edit-body, …) — new surface area jim doesn't need; the Edit-in-materialized-dir flow is the existing convention relocated.

### 9. AC #13 enforcement point — §7a plus one key

- **Chosen:** The auto-file scrub rule lands in `skills/issue/SKILL.md` §7a — the single canonical batch contract all eight surfacing skills cite: under a non-`branch` placement, `auto_issue_file = "true"` degrades to the interactive batch with a one-line disclosure unless `issue_placement_ack = "true"`.
- **Why:** §7a's own edit-here rule exists for exactly this — one edit, eight inheritors; no cross-group SKILL.md changes.
- **Rejected:** A third `auto_issue_file` value (`"publish"`) — overloads an existing enum every surfacing skill string-compares against `"true"`.

### 10. Network posture

- **Chosen:** `place.sh` exports `GIT_TERMINAL_PROMPT=0` (today only `jimalloc.sh:51` does); write publishes retry at most 5 attempts with the allocator's jittered sub-second backoff; unreachable remote → local commit stands, push deferred, degradation disclosed (AC #7). No `timeout(1)` dependency is added — hang-vs-unreachable stays at parity with the allocator, and the suite-wide timeout question rides #139.
- **Why:** Sec Finding 4's posture at allocator parity without importing a new dependency mid-plan.
- **Rejected:** Explicit `timeout` wrappers — adopts the exact dependency #139 exists to decide.

### 11. Commit messages

- **Chosen:** Composed in-script from a trusted verb enum (`file`, `edit`, `close`, `rename`, `realize`, `reindex`, `backfill`, `migrate`) plus an optional slug that must pass the id validator: `docs(issues): <verb> <slug>`. Raw titles never reach a commit message.
- **Why:** The `commit-review` trusted-enum precedent (`jimledger.sh:177-179`); slugs are charset-gated, titles are not.
- **Rejected:** Free-text `--msg` — an injection-shaped surface for zero benefit.

## Constitution Check

**ARCHITECTURE.md status:** Present — constraints noted below.

| Constraint from ARCHITECTURE.md / blueprints | Honored? | Notes |
| :--- | :--- | :--- |
| `single-emitter` — issue files written only through `new.sh` | Yes | Placement wraps the emitter; `place.sh` moves bytes the emitter produced, it never composes an issue file |
| `untrusted-body-never-shell` | Yes | Bodies stay `--body-file` file→file; `place.sh` substitutes only a temp-dir path token, never content; commit messages from a trusted enum (DD 11) |
| `id-gate-before-path` | Yes | Unchanged in the issue scripts; `place.sh` adds the branch-name gate before any git interpolation (DD 4) |
| `atomic-index-write` | Yes | tmp+mv semantics preserved inside the materialized dir; publication is a single atomic ref CAS |
| `staleness-gated-reads` | Yes | Under placement the gate is the bookmark ref + always-current destination INDEX (DD 5); default mode untouched |
| `insights-capability-boundary` | Yes | Main agent materializes via `begin --read` (no body reads); the analyst reads inside its write-free context as today |
| Never `source`/`eval` user data; bash + POSIX only; `set -uo pipefail` | Yes | `place.sh` follows the house preamble; parses with grep/sed; no new dependencies |
| Inter-script composition via BASH_SOURCE-relative paths | Yes | `place.sh` → `jimconf.sh` resolution follows `reconcile.sh`'s existing pattern |
| Permission conventions — exact `allowed-tools` clauses | Yes | One new clause for the skill-body `place.sh` calls (begin/commit/abort); self-routed internal calls ride the parent grant |
| Provenance discipline — no artifact IDs in script comments | Yes | `place.sh` comments state behavior only |
| Coordination branch holds registry logs only (`platform/007`) | Yes | Guarded by the DD 4 refusal (spec AC #9) |
| No writes to `.git/` internals by hand | Yes | All ref writes go through `git update-ref`/`push` plumbing, never file pokes |

## File Manifest

| Component | File Path | Action | Notes |
| :--- | :--- | :--- | :--- |
| Placement primitive | `skills/issue/scripts/place.sh` | Create | Config gate, materialize/publish engine, run + begin/commit/abort verbs |
| Config resolver | `skills/conf/scripts/jimconf.sh` | Update | `issue_placement`, `issue_placement_ack`: KEYS, defaults, `:182` bare-name arm |
| Emitter | `skills/issue/scripts/new.sh` | Update | Self-route re-exec; destination-relative stdout path under placement |
| Index | `skills/issue/scripts/index.sh` | Update | Self-route re-exec |
| Read views | `skills/issue/scripts/render.sh` | Update | Self-route reads; degrade note pass-through |
| Realizer | `skills/issue/scripts/reconcile.sh` | Update | Self-route re-exec |
| Migrations | `skills/issue/scripts/backfill.sh`, `skills/issue/scripts/migrate.sh` | Update | Self-route re-exec |
| Skill flow | `skills/issue/SKILL.md` | Update | §6a placement arm, §7a ack rule, insights materialization, `allowed-tools` clause, flip-migration manual-move note |
| Example config | `jimconf.toml.example` | Update | `issue_placement` / `issue_placement_ack` documented block |
| Issue tests | `tests/issues.sh` | Update | Placement cases (details per task) |
| Config tests | `tests/jimconf.sh` | Update | Key cases + ordered-KEYS assertion |
| User docs | `README.md`, `WORKFLOW.md` | Update | Issue-collection placement mention (post-ship doc sweep, in-plan) |

## Interface Contracts

```text
jimconf keys
  issue_placement      default "branch"   sentinel `branch` = current working branch;
                                          any other value = destination branch name
  issue_placement_ack  default "false"    "true" = auto-filed batches may publish
                                          without the interactive scrub moment

place.sh CLI (skills/issue/scripts/place.sh)
  place.sh run [--read] --verb <enum> [--id <slug>] -- CMD [ARGS…]
      `{}` tokens in ARGS replaced by the collection dir (materialized under
      placement; the configured issues dir in passthrough). Wrapped command runs
      with CWD = primary checkout and JIM_PLACE_ACTIVE=1.
      --read: materialize, run, discard (no commit; render verbs).
  place.sh begin [--read]        → stdout "<token>\t<dir>"
  place.sh commit <token> --verb <enum> [--id <slug>]
  place.sh abort <token>

  exit codes: 0 ok (stderr may carry degradation notes: fetch failed /
              push deferred / rewrite detected / ignored stale token);
              2 config or validation refusal (junk branch name, coordination
              branch, bad verb, uncontained tree entry, dirty target paths);
              3 concurrent-conflict refusal (path named; temp state kept)

  verb enum: file | edit | close | rename | realize | reindex | backfill | migrate
  commit message: "docs(issues): <verb>[ <slug>]"  (slug must pass valid-id)

self-route token:    JIM_PLACE_TOKEN=<tok> in the environment suppresses re-exec
                     only when it equals the --place-token <tok> value passed by
                     place.sh on the same invocation; any other value is ignored
                     and disclosed (never a boolean opt-out)
bookmark ref:        refs/jim/issue-placement/<branch>
changed set:         additions + modifications + deletions (rename = del + add)
new.sh stdout under placement: "<slug>\t<repo-relative destination path>"
```

## Data Flow

```mermaid
flowchart TD
    C[caller: skill flow or candidate batch] --> E[entry script e.g. new.sh]
    E -->|placement = branch or JIM_PLACE_ACTIVE| W[write into working tree - today's path]
    E -->|branch-name placement| P[place.sh run]
    P --> V{validate: ref format,<br/>not coordination branch}
    V -->|fail| R2[rc 2 refusal]
    V --> F[fetch destination best-effort]
    F --> N{bookmark ancestor of tip?}
    N -->|no| D[disclose rewrite, advance bookmark]
    N -->|yes| M[materialize tip collection into mktemp dir]
    D --> M
    M --> X[re-exec entry script with JIM_PLACE_ACTIVE=1, dir = {}]
    X --> B[diff vs baseline -> changed set]
    B --> T[hash-object / mktree / commit-tree on tip]
    T --> A{ref CAS + push}
    A -->|ok| K[advance bookmark, cleanup, rc 0]
    A -->|remote moved| G[refetch; per-file graft:<br/>ours if upstream unchanged, else rc 3;<br/>regenerate INDEX.md; rebuild commit]
    G --> A
    A -->|unreachable| L[local commit stands, push deferred, disclose, rc 0]
```

## Task Breakdown

1. [x] Add `issue_placement` + `issue_placement_ack` to `jimconf.sh` (KEYS array, `default_for`, the `:182` bare-name arm) with cases in `tests/jimconf.sh` (get/default/list, the ordered-KEYS assertion, and a case proving `issue_placement` does **not** read `issue_placement_path`).
   **Verify:** `bash tests/jimconf.sh`

2. [x] Create `place.sh` skeleton: verb dispatch, config resolution from the primary CWD, the validation gate (empty / leading-`-` / `check-ref-format` / coordination-branch refusal → rc 2, value named), the trusted verb enum, the per-run token generator, and passthrough mode (`issue_placement = branch` → exec CMD with the configured dir, zero git choreography). Tests: each refusal, passthrough transparency, and a stale `JIM_PLACE_TOKEN` in the environment being ignored + disclosed rather than suppressing routing (security Finding 10).
   **Verify:** `bash skills/meta-test/scripts/run.sh place`

3. [x] Local engine in `place.sh`: **contained** materialization of the destination tip's collection — `git ls-tree -r --name-only -z` enumeration with per-entry `valid-relpath` + `realpath -m` temp-root containment before any blob write, aborting at rc 2 on the first violation (security Finding 7, Critical) — empty tree on absent destination, `{}` substitution + token export, changed-set diff (adds/mods/**deletes**), plumbing commit with orphan bootstrap (parentless commit, tree at configured `issues_path`), local ref CAS, bookmark ref update, cleanup traps on EXIT/INT/TERM. Tests: mutation lands on a local destination branch (`cat-file` assertions, `case_jimalloc_custom_branch_from_config` shape), orphan birth, working tree untouched, **and a crafted destination tree bearing a traversal path (planted via the `tests/issues.sh:2478-2481` plumbing seam) refuses at rc 2 with nothing written outside the temp root**.
   **Verify:** `bash skills/meta-test/scripts/run.sh place`

4. [x] Remote sync in `place.sh`: `GIT_TERMINAL_PROMPT=0`, fetch-before (best-effort on `--read` with degrade note; attempted on writes), push-after-commit, deferred-push disclosure on unreachable, 5-attempt bounded retry with jittered backoff. Tests: bare-remote publish, unreachable-remote defer + disclosure, retry after the remote advances.
   **Verify:** `bash skills/meta-test/scripts/run.sh place`

5. [x] Graft retry + conflict refusal: per-path replay against the recorded base for adds, modifications **and deletions** (ours when upstream unchanged; rc 3 with the path named otherwise), `INDEX.md` always regenerated on the merged tree, wrapped command never re-run. Tests: two disjoint concurrent mutations both survive with a correct merged INDEX; same-file concurrency refuses; a filing race does not double-allocate; **a deletion replays as a deletion — the removed path does not reappear on the merged tree** (security Finding 8).
   **Verify:** `bash skills/meta-test/scripts/run.sh place`

6. [x] Rewrite detection: bookmark ancestry check after every fetch; non-fast-forward tip → loud disclosure naming both SHAs, then advance. Tests: force-pushed fixture remote produces the disclosure on the next read and the next write.
   **Verify:** `bash skills/meta-test/scripts/run.sh place`

6a. [x] Direct mode (destination == checked-out branch): in-tree write + path-scoped `add`/`commit` + push, divergence disclosed rather than auto-rebased, preceded by the dirty-path guard (`git status --porcelain -- <paths>` → rc 2 naming the paths; security Finding 9). Tests: filing with `issue_placement = <current branch>` lands one path-scoped commit and leaves unrelated working-tree changes untouched; a pre-existing uncommitted edit at a collection path refuses instead of being absorbed into the commit.
    **Verify:** `bash skills/meta-test/scripts/run.sh place`

7. [x] Self-route `new.sh` and `index.sh` (re-exec through `place.sh` unless `branch` placement, `JIM_PLACE_ACTIVE`, or explicit dir override; verbs `file`/`reindex`; destination-relative stdout path). Tests: end-to-end filing under placement lands file + regenerated INDEX as one commit on the destination, working branch untouched; a branch-only `origin:` files fine and indexes at rc 0 (dangling tolerated); default placement leaves every pre-existing case green unmodified.
   **Verify:** `bash tests/issues.sh`

8. [x] Self-route `render.sh` (all read verbs + `insights-graph`): materialize `--read` from the destination, no regen commit from reads, fetch-degrade note surfaced. Tests: `list`/`show` serve the destination collection from a checkout whose working tree has no issues; unreachable remote yields last-seen + note.
   **Verify:** `bash skills/meta-test/scripts/run.sh issues`

9. [x] Self-route `reconcile.sh`, `backfill.sh`, `migrate.sh` (verbs `realize`/`backfill`/`migrate`). Tests: realize under placement rewrites `num:` at the destination and reindexes there; migrate's rename flow lands renames + INDEX as one destination commit; **a rename that loses a push race grafts as delete + create — the old filename is gone from the merged tree and the regenerated INDEX holds one entry, not two** (security Finding 8, the mutation-level case for task 5's engine-level fixture).
   **Verify:** `bash tests/issues.sh`

10. [x] `begin`/`commit`/`abort` two-phase in `place.sh`: token bookkeeping, per-file replay on commit, rc 3 conflict refusal preserving the temp dir, abort cleanup, `--read` variant for insights. Tests: edit-close flow publishes; concurrent same-file edit refuses and preserves state; abort leaves nothing.
    **Verify:** `bash skills/meta-test/scripts/run.sh place`

11. [x] `skills/issue/SKILL.md`: §6a placement arm (begin/Edit/commit flow), §7a auto-file rule (`auto_issue_file` degrades to interactive with a one-line disclosure unless `issue_placement_ack`), insights step materialization via `begin --read`, the new `allowed-tools` clause for `place.sh`, and the flip-migration manual-move note (one-time move, no scaffolding).
    **Verify:** `grep -q 'place.sh' skills/issue/SKILL.md && grep -q 'issue_placement_ack' skills/issue/SKILL.md && grep -c 'issue_placement' skills/issue/SKILL.md`

12. [x] Docs: `jimconf.toml.example` gains the documented `issue_placement` / `issue_placement_ack` block; `README.md` and `WORKFLOW.md` swept for issue-collection location statements and updated where they assert on-branch behavior.
    **Verify:** `grep -q 'issue_placement' jimconf.toml.example && grep -q 'issue_placement' README.md`

13. [x] Full-suite green with zero pre-existing fixtures modified (AC #2's evidence): the diff over `tests/` shows additions only.

    **Comparison base.** This build runs on `feat/id-coordination`, which carries the whole ID-coordination cluster; `main` lags it by every spec from `platform/008` onward, so diffing against `main` would attribute the cluster's test history to this build and drown the signal. The base is **this build's own starting commit** — capture it before task 1:

    ```
    git rev-parse HEAD > .git/jim-build-base-011    # pre-build tip of feat/id-coordination
    ```

    The verify asserts the property directly (no `tests/` line is ever deleted) rather than leaving a stat line to be read by eye — a modified fixture shows up as a deletion in `--numstat`'s second column.

    **Verify:** `bash skills/meta-test/scripts/run.sh && git diff --numstat "$(cat .git/jim-build-base-011)" -- tests/ | awk -F'\t' '$2 != 0 { print "deletion in " $3; found=1 } END { exit found }'`

## Requirements Coverage Summary

| Spec Acceptance Criterion | Addressed In Task(s) |
| :--- | :--- |
| AC 1 — one key, `branch` sentinel or branch name | 1, 2 |
| AC 2 — default behavior unchanged, existing tests pass unmodified | 2 (passthrough), 7, 13 |
| AC 3 — every write lands at the destination, working branch untouched | 3, 6a, 7, 9, 10 |
| AC 4 — one auto-commit per mutation, fixed conventional message | 3 (engine), 6a (direct mode), 7 (file+reindex as one commit), DD 11 |
| AC 5 — reads serve the destination collection | 8 |
| AC 6 — fetch-first freshness, loud last-seen degrade | 4, 8 |
| AC 7 — writes never block; retried, deferred loudly, never silently lost | 4, 5 |
| AC 8 — missing destination auto-created as orphan carrying only the collection | 3 |
| AC 9 — coordination branch refused | 2 |
| AC 10 — junk value refused loudly, no silent fallback | 1 (key plumbing), 2 (gate) |
| AC 11 — dangling `origin:` tolerated as informational | 7 |
| AC 12 — non-fast-forward rewrite detected and disclosed | 6 |
| AC 13 — auto-filing keeps a scrub moment unless acknowledged | 1 (ack key), 11 |

No `[NEEDS CLARIFICATION]` markers — every AC has an unambiguous mechanical reading under the design above.

## Out of Scope

- **Flip-migration automation** — the SKILL.md note (task 11) documents the one-time manual move; no transition code (spec Out of Scope).
- **Unifying branch validation with `jimalloc.sh`** — a shared `jimfile.sh valid-branch` verb is a platform-face follow-on (DD 4); the filed `fixture-the-invalid-id-coordination-branch-refusal` issue is independent of this plan.
- **Explicit network timeouts** — parity with the allocator's posture for now; the suite-wide `timeout(1)` decision rides #139.
- **Branch-protection / team-setup documentation** — #118's charter (spec AC #12 covers detection; prevention docs live there).
- **`ARCHITECTURE.md` and blueprint refresh** — pipeline-owned: the `/jim:build` completion gate runs `/jim:arch`, and the post-review blueprint fold updates the issue group's faces (the new key contract, the placement surface). Not a deferral.

## Open Questions

- [ ] Whether placement git calls eventually get explicit timeouts — deliberately coupled to #139's suite-wide `timeout` decision rather than settled here.
- [x] ~~Worktree vs plumbing~~ → materialize-and-plumb (DD 1).
- [x] ~~Retry semantics~~ → per-file graft + INDEX regen; never re-run, never re-push (DD 3).
- [x] ~~Checked-out destination~~ → direct mode, disclose-don't-rebase (DD 6).
- [x] ~~Where AC #13 is enforced~~ → §7a + `issue_placement_ack` (DD 9).
