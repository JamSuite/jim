---
title: "ID coordination allocator (foundation)"
spec: "docs/specs/platform/007-id-coordination-allocator/spec.md"
type: feature
status: approved
---

# ID coordination allocator (foundation) — Plan

## Overview

A new deterministic platform CLI, `skills/file/scripts/jimalloc.sh`, allocates
jim's IDs by appending compare-and-swap (CAS)-guarded records to a per-kind,
append-only registry on a dedicated coordination branch — using git plumbing
(`hash-object`/`mktree`/`commit-tree` + `push` / `update-ref`) so it never
disturbs the developer's working tree, and reusing `jimfile.sh`'s existing
validators as the single security boundary.

## Design Decisions

### 1. New `jimalloc.sh` script, not an extension of `jimfile.sh`

- **Chosen:** A new single-responsibility script `skills/file/scripts/jimalloc.sh`, composing `jimfile.sh` (id/slug/timestamp validators) and `jimconf.sh` (config) via `BASH_SOURCE`-relative subprocess calls, exactly as `jimfile.sh` chains to `jimconf.sh`.
- **Why:** The allocator is jim's first *network + shared-ref-write* git surface; `jimfile.sh` (916 lines) is deliberately local-only file/path/id logic. Keeping them separate preserves each platform CLI's single responsibility (the `jimconf`/`jimfile`/`jimledger` pattern) and lets the allocator be tested in isolation with fixture git repos.
- **Rejected:** Extending `jimfile.sh` — bloats it, fuses local-only ops with CAS/network machinery, and complicates isolation testing.

### 2. Pure git plumbing for the CAS, not a temp worktree

- **Chosen:** Build the registry commit with plumbing (`git cat-file` to read, `git hash-object -w` for the new blob, `git ls-tree` + `git mktree` for the tree, `git commit-tree` for the commit), then land it via the CAS primitive per tier: origin tier `git push <remote> <sha>:refs/heads/<branch>` (non-fast-forward rejection *is* the CAS), local tier `git update-ref refs/heads/<branch> <newsha> <expected-oldsha>` (old-value CAS).
- **Why:** The developer is on a feature branch mid-`/jim:spec`; plumbing never checks out the coordination branch or touches the working tree. The registry-only branch holds ≤2 tiny files, so plumbing tree-building is trivial. Confirmed against git docs (research → Prior Art): `update-ref` old-oid and push non-fast-forward are the two atomic CAS primitives.
- **Rejected:** Temp worktree on the coordination branch — churns disk and is invasive to check out mid-interview; heavier moving parts for a 2-file tree.

### 3. Dedicated, registry-only orphan coordination branch as default

- **Chosen:** Default `id_coordination_branch = jim/registry`; the branch carries only the per-kind registry logs and shares no history with `main` (orphan). Configurable; `main` is opt-in.
- **Why:** Minimizes contention (races only other allocations, not every PR merge — spec Finding 6), minimizes the untrusted surface (no content, only append-only registry lines — spec Finding 1/F4), and makes the "direct-push-yes / force-push-no" protection profile govern only coordination data.
- **Rejected:** Default to `main` — merge queues / required checks commonly make `main` non-pushable, and it maximizes both contention and the untrusted-content surface.

### 4. Per-kind append-only logs; group records ride the spec log

- **Chosen:** `specs.log` and `issues.log`. `specs.log` also carries `group allocate` / `group rename` records, so resolving a spec id replays one file. Space-separated, greppable, file-order authoritative, never sourced.
- **Why:** Group identity is the addressing namespace for spec ids, so co-locating group records keeps per-kind resolution a single forward scan (spec AC 5/7/8). One file per kind is the confirmed granularity; per-group sharding is premature.
- **Rejected:** A separate `groups.log` — forces resolution to join two files with no benefit at jim scale.

### 5. Full record grammar defined and resolved now; only `allocate` emitted

- **Chosen:** Parse and forward-replay `allocate`, `rename`, and `group rename` record shapes (replay-from-allocate, cycle-safe), but this build emits only `allocate` records.
- **Why:** Spec AC 6/7 — freeze the format and resolution so the blueprint follow-on can emit rename/group-rename records without a format migration. G1 correctness (replay-from-allocate + allocate-once groups) is implemented and fixture-tested now.
- **Rejected:** Emit-and-parse only `allocate` — would force a format/resolution rev in the follow-on and defer the load-bearing resolution invariant.

### 6. Reuse `jimfile.sh`'s validators as the single security boundary

- **Chosen:** Every value read from the registry or config (id, slug, group name, `id_coordination_branch`) is revalidated via `jimfile.sh valid-id` / `is_valid_slug` and a git-ref-name check *before* it reaches any git command or path; git invocations use `--end-of-options` (refs/SHAs), `--` (pathspecs), `--literal-pathspecs` (paths), never `git add -A`; write targets are contained under `git rev-parse --show-toplevel` with symlink-escape refused.
- **Why:** Spec AC 13 + Findings 1/F5 — the coordination branch is writable by anyone who can push it, so replayed content is untrusted. This mirrors the exact discipline `jimledger.sh` / `jimpartition.sh` already establish (research anchors).
- **Rejected:** Parse-as-data alone — prevents execution but not git option-injection or path traversal (the precise gap the security review flagged).

### 7. Encode-on-write, validate-on-read (bidirectional record boundary)

- **Chosen:** The record layer sanitizes every field *before* appending it to a log — free-text values (`<who>` from `git config user.name`, any un-normalized subject) have newlines and the field delimiter stripped, or the write is rejected — complementing the read-side revalidation of DD 6.
- **Why:** The log is newline-delimited and space-separated; an unsanitized field (e.g. a `user.name` containing a newline) could inject a forged `allocate` record and mislead a plain `grep`/replay (security Finding 8). Mirrors the field sanitization `jimverify.sh` / `index.sh` already apply.
- **Rejected:** Read-side validation only — degrades a forged line on read but leaves the log corrupted and non-greppable.

### 8. Erosion-guard baseline is local-only

- **Chosen:** The G3 byte-prefix baseline (the "last-seen" registry) is stored locally, outside the coordination branch (the clone's git dir or a local state file), never fetched from or committed to the registry.
- **Why:** If the baseline lived on the coordination branch, an attacker force-pushing a rewritten history would rewrite the baseline too and the guard would silently pass (security Finding 9), defeating AC 11. Only a trusted local baseline detects erosion.
- **Rejected:** Baseline on the coordination branch / derived from fetched content — self-defeating.

## Constitution Check

**ARCHITECTURE.md status:** Present — constraints noted below.

| Constraint from ARCHITECTURE.md | Honored? | Notes |
| :--- | :--- | :--- |
| Bash-vs-Prompt: deterministic logic lives in a bash script | Yes | The allocator is deterministic (same registry + kind → same next id, verifiable by exit code/string compare) → a bash CLI; the consuming `/jim:spec`, `/jim:issue` judgment stays in prompts. |
| Scripting Layer: `set -uo pipefail`, `export LC_ALL=C`, Bash+POSIX only, no third-party deps | Yes | `jimalloc.sh` and `tests/jimalloc.sh` carry the preamble; parsing is grep/sed/awk. |
| Never `source`/`eval` untrusted content | Yes | Registry parsed as data (AC 15); DD 6. |
| `BASH_SOURCE`-relative sibling composition | Yes | `jimalloc.sh` resolves `jimfile.sh` / `jimconf.sh` by `BASH_SOURCE`-relative path (like `jimfile.sh` → `jimconf.sh`). |
| Single id boundary (`is_valid_id`), no further copies | Yes | Revalidation calls `jimfile.sh valid-id`; no fourth `is_valid_id` copy is introduced. |
| Operational-git discipline (literal paths, `--` guard, valid-id option-injection foreclosure, never `git add -A`) | Yes | DD 6 mirrors `jimledger.sh`. |
| `jimconf.sh` `resolve()` bare-name arm for new config keys | Yes | Task 1 adds an `id_coordination_*` arm + `default_for` cases. |

**New capability note (not a violation):** the allocator is jim's first script to `push`/`fetch` and write a shared ref — a net-new git surface (research → Security §1). It is consistent with the architecture; `ARCHITECTURE.md`'s Scripting Layer entry for `jimalloc.sh` and the new config keys is refreshed by the `/jim:build` completion `/jim:arch` gate (see Out of Scope), not hand-edited here.

## File Manifest

| Component | File Path | Action | Notes |
| :--- | :--- | :--- | :--- |
| Allocator CLI | `skills/file/scripts/jimalloc.sh` | Create | `allocate` / `peek` / `resolve` verbs; registry replay; two-tier CAS; G3/G9 guards; security boundary. |
| Config keys | `skills/conf/scripts/jimconf.sh` | Update | Add `id_coordination_*` to the `resolve()` bare-name arm and `default_for` (mechanism/branch/unreachable). |
| Allocator tests | `tests/jimalloc.sh` | Create | Fixture-log replay, fixture-repo CAS race, guards, injection, peek, resolve. |
| Config tests | `tests/jimconf.sh` | Update | Cases for the three new keys (default + override). |

## Interface Contracts

```text
# ── CLI surface (skills/file/scripts/jimalloc.sh) ─────────────────────────────
jimalloc.sh allocate spec  <group> <subject>   # → "<group>/<NNN>"    (durable, post-CAS)
jimalloc.sh allocate issue <subject>           # → "<full-id>\t<num>" (durable, post-CAS)
jimalloc.sh peek     spec  <group>             # → likely "<group>/<NNN>"  (advisory; no commit)
jimalloc.sh peek     issue                     # → likely "<num>"          (advisory; no commit)
jimalloc.sh resolve  spec  <group>/<NNN>       # → current "<group>/<NNN>" (forward-replay)
jimalloc.sh resolve  issue <num|full-id>       # → current id
#
# Exit codes: 0 success · 1 hard-fail (unreachable / erosion / retries exhausted /
#             rejected token) · 2 usage error.  Errors → stderr; stdout stays clean.
#
# ── Registry record grammar (space-separated; file-order authoritative; date is
#    informational only, NEVER used for ordering) ──────────────────────────────
# Emitted by this build:
spec  allocate  <group>/<NNN> <slug> <date> <who>
group allocate  <group> <date> <who>
issue allocate  <NNN> <full-id> <date> <who>
# Parsed + resolved now, emitted by the blueprint follow-on (format frozen):
spec  rename    <group>/<NNN> <newgroup>/<newNNN> <date>
group rename    <old-group> <new-group> <date>
issue rename    <NNN> <newNNN> <date>
#
# ── Config keys (skills/conf/scripts/jimconf.sh) ──────────────────────────────
id_coordination_mechanism   = "git"          # default; "service" reserved (unimplemented)
id_coordination_branch      = "jim/registry" # default; the coordination point
id_coordination_unreachable = "fail"         # default; "provisional" reserved (deferred)
#
# ── Resolution algorithm (pure; no git) ───────────────────────────────────────
# forward-replay(log, kind, queried_id):
#   current = queried_id
#   scan lines in FILE ORDER, starting at current's `allocate` record:
#     on `<kind> rename  src dst`     where src == current → current = dst
#     on `group rename    g   h`      where current starts "g/"  → rewrite prefix g→h
#   each record applies at most once, in file order (cycle-safe by construction).
#   return current  (or rc 1 "not allocated" if no allocate record for queried_id).
# next-id(log, kind, group): max(NNN over allocate+rename dst in group) + 1, else 001.
# next-num(log): max(NNN over issue allocate+rename dst) + 1, else 1.
#
# encode(kind, fields…): build ONE record line; strip/reject newline + the field
#   delimiter in free-text values (<who>, subject) so a crafted field cannot
#   forge a second record (write-side complement to read-side validation).
# erosion baseline: the G3 last-seen registry is stored LOCALLY (clone git dir or
#   a local state file), never fetched from or committed to the coordination branch.
```

## Data Flow

```mermaid
sequenceDiagram
    participant C as consumer (e.g. /jim:spec)
    participant A as jimalloc.sh
    participant G as git (coordination branch)
    C->>A: allocate spec <group> <subject>
    loop bounded retries (backoff+jitter)
        A->>G: fetch coordination branch (GIT_TERMINAL_PROMPT=0)
        G-->>A: tip SHA + registry blob (or unreachable → hard-fail)
        A->>A: G3 byte-prefix erosion check vs locally-seen
        A->>A: forward-replay → next id; G9 durable-id uniqueness
        A->>A: revalidate every replayed/config token (F1)
        A->>A: plumbing: hash-object → mktree → commit-tree
        A->>G: CAS land (push non-ff / update-ref old-value)
        alt accepted
            G-->>A: ok → id is durable
        else rejected (ref moved)
            G-->>A: refetch, recompute, retry
        end
    end
    A-->>C: <id>   (only after durable CAS; else rc 1)
```

## Task Breakdown

1. [x] Add `id_coordination_mechanism` / `id_coordination_branch` / `id_coordination_unreachable` to `jimconf.sh` — an `id_coordination_*` prefix arm in `resolve()` and the three `default_for` cases (`git` / `jim/registry` / `fail`). Add `tests/jimconf.sh` cases for default + override of each.
   **Verify:** `bash tests/jimconf.sh`

2. [x] Scaffold `skills/file/scripts/jimalloc.sh`: preamble (`set -uo pipefail; export LC_ALL=C; export GIT_TERMINAL_PROMPT=0`), `BASH_SOURCE`-relative `JIMFILE`/`JIMCONF`, subcommand dispatch (`allocate`/`peek`/`resolve`), and usage (rc 2 on unknown/missing verb). Create `tests/jimalloc.sh` (via `/jim:meta-test scaffold jimalloc`) with a usage smoke case.
   **Verify:** `bash tests/jimalloc.sh`

3. [x] Implement the pure record layer over a log string/file: the grammar parser (per-field charset validation via `jimfile.sh valid-id`/`is_valid_slug`; a malformed record is degraded and skipped, never executed — AC 15, F1a), the emit-encoder (DD 7 — build a record line from fields, stripping/rejecting newlines and the field delimiter in free-text values so a crafted field cannot forge a second record — F8), and `resolve` forward-replay (multi-hop rename, group rename, reused-name safety via replay-from-allocate, cycle-safety). Fixture logs only, no git. Include adversarial cases (id `--upload-pack=x`, `..`-bearing slug, ref metacharacters, a newline-bearing `<who>`) asserting rejection/sanitization.
   **Verify:** `bash tests/jimalloc.sh`

4. [x] Implement `next-id`/`next-num` over the replay and the G9 durable-id guard: compute next spec `NNN` per group, next issue `num`, and the durable issue id (slug via `jimfile.sh`), suffixing (`-2`,`-3`) when the durable id already appears in the log. Depends on task 3.
   **Verify:** `bash tests/jimalloc.sh`

5. [x] Local-tier CAS: plumbing commit builder (`cat-file`→`hash-object`→`ls-tree`+`mktree`→`commit-tree`) and `git update-ref refs/heads/<branch> <new> <expected>` old-value CAS; bounded retry on mismatch, then hard-fail. Build the appended record via the task-3 encoder, taking a sanitized `<who>` from `git config user.name` (F8). Fixture: a temp no-remote repo — allocate twice yields distinct ids, the log grows append-only, an abandoned allocation leaves a permanent gap, and a newline-bearing `git config user.name` cannot forge a second record. Depends on task 4.
   **Verify:** `bash tests/jimalloc.sh`

6. [x] Origin-tier CAS: `git fetch` the coordination branch, build the commit with the fetched tip as parent, `git push <remote> <sha>:refs/heads/<branch>` (no force) with non-fast-forward rejection as the CAS; first-allocation branch-create case; bounded retry-on-reject then hard-fail. Fixture: two clones of a bare remote simulating the race (A pushes, B rejected → refetch → retry → distinct id). Depends on task 5.
   **Verify:** `bash tests/jimalloc.sh`

7. [x] G3 growth guard: cache the last-seen registry per kind **locally, outside the coordination branch** (DD 8 — the clone's git dir or a local state file, never fetched from or committed to the registry — F9); on each fetch/read assert the seen content is a byte-prefix of the current content, hard-failing on erosion (force-push/revert) rather than reissuing. Fixture: rewrite the coordination branch history — even with the attacker controlling branch content, the local baseline still detects the erosion and next allocate hard-fails. Depends on task 6.
   **Verify:** `bash tests/jimalloc.sh`

8. [x] Config wiring + tier selection + failure semantics: resolve `id_coordination_*`; select origin vs local tier by remote reachability (AC 9); `unreachable = fail` → bounded retry then loud hard-fail, no silent local fallback in origin tier (AC 10); retry backoff+jitter (F6); validate the config-supplied `id_coordination_branch` as a git ref name before use (F1b); confirm non-interactive git (F7). Fixture: a bad remote URL → rc 1 with a clear message. Depends on task 6.
   **Verify:** `bash tests/jimalloc.sh`

9. [x] Write-containment guard (F5): resolve the registry write path and any temp artifact inside `git rev-parse --show-toplevel`; refuse a symlinked or out-of-tree target before any object write or ref update. Fixture: a symlink-escaping coordination path → refused, rc 1, no side effect. Depends on task 5.
   **Verify:** `bash tests/jimalloc.sh`

10. [x] `peek`: reuse tasks 3–4 to compute the next id from the best-available registry state without committing; advisory and non-fatal on unreachable (never binds, never mutates). Fixture: `peek` prints the next id and leaves the registry byte-identical. Depends on task 4.
    **Verify:** `bash tests/jimalloc.sh`

11. [x] Full-suite green: run the aggregate test runner to confirm no regression across platform scripts.
    **Verify:** `bash skills/meta-test/scripts/run.sh`

## Requirements Coverage Summary

| Spec Acceptance Criterion | Addressed In Task(s) |
| :--- | :--- |
| At-most-once, durable-before-return allocation | 5, 6 |
| Racing allocations never both succeed; bounded retry then loud fail | 5, 6 |
| IDs never reused; gaps permanent | 4, 5 |
| Deterministic under contributor clock skew (order, not timestamps) | 3 |
| Renamed id (multi-hop, group rename) resolves to current; reused/reverted safe | 3 |
| Read-only `peek` preview; advisory, never binds | 10 |
| Full record grammar defined + resolved; emit `allocate` only | 3 |
| Group names allocate-once | 3, 4 |
| Guarantee tier follows reachability (remote → cross-clone; none → local) | 8 |
| Unreachable → bounded retry → hard-fail; no silent unpublished fallback | 8 |
| Registry-history erosion detected relative to locally-seen; no reissue | 7 |
| Durable-id collision disambiguated (ordinal + durable form) | 4 |
| Replayed/config tokens revalidated before git/ref/fs use | 3 (registry), 8 (config branch), 9 (write path) |
| Config governs mechanism/point/unreachable, per-branch | 1, 8 |
| Bash conventions; registry parsed as data, never sourced (read-validate + write-encode); no third-party deps | 2, 3, 5 (all tasks constitutionally) |

## Out of Scope

- **`ARCHITECTURE.md` Scripting-Layer entry for `jimalloc.sh` and the new config keys** — refreshed by the `/jim:build` completion `/jim:arch` gate (pipeline-owned; not a task, not a deferral).
- **Platform group blueprint (`docs/specs/platform/000-blueprint/`) refresh** — handled by the `/jim:blueprint` gate (pipeline-owned).
- Consumer wiring (`/jim:issue`, `/jim:spec`), rename/group-rename *emission* + `/jim:partition` batches, `provisional`+`reconcile`, `seed`/migration, the `service` backend, G2 only-door sweep, G8 relocation tombstone, `issue_placement` — all deferred by the spec's Out of Scope; follow-on issues #111–118 already track them.

## Open Questions

- [x] ~~`<who>` field source~~ → `git config user.name` (advisory provenance only per spec non-goal; a missing value degrades to empty, non-fatal).
- [x] ~~Does `peek` hit the network?~~ → best-effort fetch in origin tier, degrading to last-seen state on unreachable (advisory, non-fatal — never hard-fails).
- [x] ~~Per-task `Verify` granularity~~ → `bash tests/jimalloc.sh` runs the file's cases; in TDD order each task's newly-added cases plus all prior pass, so the whole-file run is a valid per-task gate.
