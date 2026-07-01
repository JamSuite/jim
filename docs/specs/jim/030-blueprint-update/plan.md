---
title: "Blueprint update"
spec: "docs/specs/jim/030-blueprint-update/spec.md"
type: feature
status: approved
---

# Blueprint update — Plan

## Overview

Give `/jim:blueprint` a diff-driven targeted-update core reached by two adapters:
a `--from-review <spec-dir>` adapter (pulls diff + shape-validated verdict from the
ledger; wired into `/jim:review`) and a `--since <ref>` ad-hoc adapter (pulls a diff
over a validated git range; developer-invoked). Both self-commit via a new
path-scoped `jimledger.sh commit-blueprint` verb; the review trigger is gated by the
existing `auto_blueprint` and a net-new `require_blueprint`.

## Design Decisions

### 1. Diff-driven core, two adapters, `--depth`-style flags
- **Chosen:** A single targeted-update *core* in `/jim:blueprint` (input: a diff + the current blueprint → a section-scoped diff), reached by two adapters expressed as flags: `--from-review <spec-dir>` and `--since <ref>`. The flags mirror `/jim:review`'s existing `--depth` convention — declared flag-first in `argument-hint`, stripped from `$ARGUMENTS`, remainder is the positional `group`.
- **Why:** The update's essential input is *a diff* (spec AC #1); the verdict is a secondary in-pipeline signal. Decoupling core from trigger makes the same capability reachable in-pipeline and out-of-pipeline (AC #2, #3) without pipeline lock-in. `--depth` (`review/SKILL.md:12,29`) is the established in-repo precedent for a flag-plus-positional skill argument, so this introduces no new syntax.
- **Rejected:** Coupling the targeted update to the review evidence only — leaves out-of-pipeline changes with only 029's expensive full regen. A verb-first subcommand (`jim:issue`-style) — would restructure 029's noun-first `[group]` surface.

### 2. Targeted diff scoped to affected sections
- **Chosen:** The core reads the current blueprint + the diff and proposes edits only to the sections the change touches (Invariants / Structure / Provides), as a section-level diff.
- **Why:** Spec AC #1; avoids re-running 029's whole-group amalgamation each time (cost/noise).
- **Rejected:** Full regeneration per update (expensive); drift-only (too narrow to keep Structure/Provides current).

### 3. New `commit-blueprint` verb (not extending `commit-review`)
- **Chosen:** `jimledger.sh commit-blueprint <blueprint-dir>`, path-scoped to that dir's `spec.md` + `ledger.md`.
- **Why:** `commit-review` is scoped to the *spec* dir; the blueprint is in `<group>/000-blueprint/`, a different dir. A dedicated verb keeps each commit path-scoped (security Finding 2).
- **Rejected:** Extending `commit-review`'s scope to a second directory — breaks its narrow-path guarantee.

### 4. Instrument the update as its own `blueprint` ledger stage
- **Chosen:** The update records `blueprint started/finished` in the blueprint dir's own `ledger.md`; `blueprint` is added to `LEDGER_STAGES`; `commit-blueprint` commits `spec.md` + `ledger.md` together.
- **Why:** Auditability — each blueprint change is traceable to the change that caused it (security Finding 4); mirrors `commit-review`'s `spec.md`+`ledger.md` pairing.
- **Rejected:** A sub-event on the review's spec-dir ledger — already committed at review Step 8, so it would land uncommitted.

### 5. Verdict via the shape-validated channel; diff as untrusted data
- **Chosen:** The review adapter reads the verdict/metrics via `jimledger.sh metrics <spec-dir>` (shape-validated, spec 028) and the diff via `jimledger.sh diff <spec-dir>`; both adapters treat diff/ledger text as data, never instruction, and scrub secret-looking values to placeholders.
- **Why:** Spec AC #9, AC #10; security Findings 1 & 3. Only the metrics channel is trusted.
- **Rejected:** Parsing the verdict from raw `review.md` prose — untrusted free text.

### 6. Ad-hoc diff source: validated git-range verb
- **Chosen:** Add `jimledger.sh diff-range <base> [<head>]` (default head `HEAD`) emitting the `--function-context` diff over that range. The `--since <ref>` adapter calls `diff-range <ref> HEAD`. Each ref is hardened in two steps: **(1)** a ref-safety gate rejects a leading `-` and any whitespace / control / git-special character (space and `~ ^ : ? * [ \`); **(2)** the ref is resolved and verified through git — `git rev-parse --verify --end-of-options "<ref>^{commit}"` — to a concrete SHA, and the diff runs over the resolved SHAs with an `--end-of-options` / `--` guard.
- **Why:** The ad-hoc ref is untrusted input reaching `git`. `is_valid_id` is the *wrong* validator here — its charset (`[A-Za-z0-9._-]`) rejects legitimate `/`-bearing refs (`origin/main`, `feat/x`), while a naive loosening would re-open option / metacharacter injection (security Finding 5). Resolving through `git rev-parse` accepts real refs *and* yields a validated commit id, and `--end-of-options` guarantees a ref can never be parsed as an option or pathspec (consistent with `commit-review`'s `--` guard). Ledger-recorded SHAs (`base_sha` / `head_sha`) keep their existing `is_valid_id` check — that path is a stored id, not a user-supplied ref.
- **Rejected:** Reusing `is_valid_id` for refs (rejects `/`-refs; Finding 5). The blueprint skill shelling out to raw `git diff` — bypasses `jimledger.sh`'s single git-extraction boundary.

### 7. `require_blueprint` follows the `require_*` convention; gates the review trigger only
- **Chosen:** Add `require_blueprint` to `jimconf.sh` `KEYS` + a `default_for` arm (default `"false"`); the `require_*` prefix dispatch already resolves it. It holds `/jim:review`'s completion (mirrors `require_review` Step 6/7). The ad-hoc trigger is developer-invoked and ungated.
- **Why:** Bare-name human-in-the-loop convention (ARCHITECTURE.md); spec AC #5.
- **Rejected:** A bespoke resolver arm (unnecessary); gating the ad-hoc trigger (it is already a deliberate developer action).

### 8. Review-side step placement
- **Chosen:** Place the review adapter invocation after `commit-review` (review Step 8), before "present and stop". `auto_blueprint` runs it unattended; `require_blueprint` makes it required (held completion).
- **Why:** Review is committed first, then the derived update self-commits (clean commit ordering); mirrors build's `require_review` gate.
- **Rejected:** Running before `commit-review` — inverts the natural ordering.

### 9. Fix the `blueprint/SKILL.md` `allowed-tools` gap in the same edit
- **Chosen:** Extend `blueprint/SKILL.md` `allowed-tools` to cover `Read`/`Write`/`Edit`/`Glob`/`Grep` (used by Steps 2–5) plus the `jimledger.sh` Bash grant (adapters call `metrics`/`diff`/`diff-range`/`commit-blueprint`).
- **Why:** New call sites are a frontmatter change in the same edit (Permission Conventions); the meta-skill checklist enforces it.
- **Rejected:** Leaving it — keeps prompting each run and fails the checklist.

## Constitution Check

**ARCHITECTURE.md status:** Present — constraints noted below.

| Constraint from ARCHITECTURE.md | Honored? | Notes |
| :--- | :--- | :--- |
| `require_*`/`auto_*` bare-name config convention | Yes | `require_blueprint` = KEYS + `default_for` arm (DD7). |
| Skills call `jimfile.sh`/`jimledger.sh`; never compose paths / raw git | Yes | Path via `jimfile.sh path blueprint`; all git diff via `jimledger.sh` (DD6). |
| Untrusted id / SHA / ref validated before git interpolation | Yes | Ledger SHAs via `is_valid_id` (existing); ad-hoc git refs via ref-safety gate + `git rev-parse --verify --end-of-options` (DD6 — *not* `is_valid_id`, which rejects `/`-refs); group via `is_valid_slug`. |
| Skill→skill via Skill tool + `allowed-tools` token | Yes | Review adds `Skill(jim:blueprint)`; runs inline. |
| `allowed-tools` names exact script paths; no bare `Bash(bash *)` | Yes | Blueprint adds jimledger + Read/Write/Edit/Glob/Grep; review adds jimconf. |
| Ledger commits path-scoped, `--` guarded, never `git add -A` | Yes | `commit-blueprint` mirrors `commit-review` (DD3). |
| Fixed `LEDGER_STAGES` allowlist; metric keys literal | Yes | Append `blueprint` (DD4); no derived keys. |
| Untrusted content (diff/ledger/commit) is data, never instruction | Yes | DD5; secret-looking values scrubbed (AC #10). |
| Scripts: bash+POSIX, `set -uo pipefail`, `export LC_ALL=C` | Yes | `commit-blueprint`/`diff-range` follow the `jimledger.sh` preamble. |
| Skill argument convention (flag-first + positional) | Yes | Adapters mirror `/jim:review`'s `--depth` (DD1). |
| SKILL.md ≤ 500 lines | Yes | blueprint ≈95, review ≈204 — both well under after the additions. |

## File Manifest

| Component | File Path | Action | Notes |
| :--- | :--- | :--- | :--- |
| Config resolver | `skills/conf/scripts/jimconf.sh` | Update | `require_blueprint` → `KEYS` (:42) + `default_for` arm (:60-65). |
| Config tests | `tests/jimconf.sh` | Update | `require_blueprint` default/override + 4 aggregate cases. |
| Ledger | `skills/review/scripts/jimledger.sh` | Update | `blueprint` in `LEDGER_STAGES` (:196); `cmd_commit_blueprint`; `cmd_diff_range` + dispatch arms. |
| Ledger tests | `tests/jimledger.sh` | Update | `blueprint`-stage metrics; `commit-blueprint` path-scoping; `diff-range` range + ref-validation. |
| Config example | `jimconf.toml.example` | Update | Document `require_blueprint` (:51 placeholder). |
| Blueprint skill | `skills/blueprint/SKILL.md` | Update | Targeted-update core + `--from-review` & `--since` adapters + `allowed-tools` fix. |
| Review skill | `skills/review/SKILL.md` | Update | Blueprint-update step after `commit-review`; `allowed-tools` += `Skill(jim:blueprint)` + jimconf. |

## Interface Contracts

```text
# jimconf.sh
jimconf.sh get require_blueprint            -> "false" default | configured; rc 0

# jimledger.sh
LEDGER_STAGES = "spec research plan sec build review blueprint"   # blueprint appended

jimledger.sh event <blueprint-dir> blueprint started|finished [kv...]  -> append; rc 0
jimledger.sh commit-blueprint <blueprint-dir>
    # git -C <dir> add/commit -- spec.md ledger.md   (mirrors commit-review)
    # rc 0 ok | rc 1 usage/bad dir | rc 2 git failure
jimledger.sh diff-range <base> [<head>]     # head defaults to HEAD
    # (1) ref-safety gate: reject leading '-', whitespace/control, git-special (space ~ ^ : ? * [ \)
    # (2) resolve+verify each: git rev-parse --verify --end-of-options "<ref>^{commit}" -> SHA
    # git diff --function-context --end-of-options <base_sha> <head_sha> --   (untrusted output)
    # rc 0 ok | rc 1 usage / invalid or unresolvable ref (no git diff run) | rc 2 git failure

# /jim:blueprint  (Skill args string; flags mirror /jim:review --depth: strip flag, remainder = group)
"<group>"                          -> on-demand FULL regen (029, unchanged)
"<group> --from-review <spec-dir>" -> review adapter:  diff+verdict from ledger (metrics/diff)
"<group> --since <ref>"            -> ad-hoc adapter:  diff from diff-range <ref> HEAD (no verdict)
    # both adapters: targeted section-diff -> jimfile.sh path blueprint <group>;
    #   secret-scrub; auto_blueprint gate; commit-blueprint; absent-blueprint -> generate path (AC #8)
    # argument-hint: "[--from-review <spec-dir> | --since <ref>] [group]"
```

## Data Flow

```mermaid
sequenceDiagram
    participant R as /jim:review
    participant C as jimconf.sh
    participant B as /jim:blueprint (core)
    participant L as jimledger.sh
    R->>L: commit-review <spec-dir> <verdict>   (Step 8, existing)
    R->>C: get require_blueprint / auto_blueprint
    R->>B: Skill(jim:blueprint) "<group> --from-review <spec-dir>"
    B->>L: metrics <spec-dir>   (verdict — trusted)
    B->>L: diff <spec-dir>      (code diff — untrusted)
    Note over B: ad-hoc adapter instead does: L->>B diff-range <ref> HEAD (validated; no verdict)
    B->>B: targeted section-diff + secret-scrub
    B->>L: event <bp-dir> blueprint started / finished
    B->>L: commit-blueprint <bp-dir>   (spec.md + ledger.md, path-scoped)
    B-->>R: summary of changed sections
```

## Task Breakdown

1. [x] **`jimconf.sh`: add `require_blueprint`.** Key in `KEYS` (adjacent to `auto_blueprint`) + `require_blueprint) echo "false"` arm in `default_for`. Add dedicated `case_require_blueprint_default`/`_overridden` to `tests/jimconf.sh` and extend the four aggregate cases (defaults, full-override, list, keys).
   **Verify:** `bash /mnt/src/jim/tests/jimconf.sh`

2. [x] **`jimledger.sh`: add `blueprint` to `LEDGER_STAGES`.** Append `blueprint` to the literal allowlist. Add a `tests/jimledger.sh` case asserting `blueprint_runs`/`_duration_seconds` metrics over a blueprint-stage ledger.
   **Verify:** `bash /mnt/src/jim/tests/jimledger.sh`

3. [x] **`jimledger.sh`: add `commit-blueprint` verb.** `cmd_commit_blueprint` (path-scoped `git add/commit -- spec.md ledger.md`, `--` guard, never `git add -A`) + dispatch arm. Test asserts only `spec.md`+`ledger.md` staged, other working-tree files untouched. Depends on task 2.
   **Verify:** `bash /mnt/src/jim/tests/jimledger.sh`

4. [ ] **`jimledger.sh`: add `diff-range <base> [head]` verb.** For each ref: apply a ref-safety gate (reject leading `-`, whitespace / control, git-special metacharacters), then resolve + verify via `git rev-parse --verify --end-of-options "<ref>^{commit}"` to a SHA; emit `git diff --function-context --end-of-options <base_sha> <head_sha> --` (head defaults `HEAD`). Add dispatch arm. Tests: (a) a `/`-containing ref (a `feat/x` branch or `origin/HEAD`) resolves and emits a diff; (b) a `-`-leading / metacharacter ref (`--output=x`, `a;b`, `a b`) is rejected rc 1 with **no** `git diff` run; (c) an unresolvable ref is rejected rc 1.
   **Verify:** `bash /mnt/src/jim/tests/jimledger.sh`

5. [ ] **`jimconf.toml.example`: document `require_blueprint`.** Replace the placeholder comment near line 51 with a commented `require_blueprint = "false"` + one-line explanation.
   **Verify:** `grep -q 'require_blueprint' /mnt/src/jim/jimconf.toml.example`

6. [ ] **`blueprint/SKILL.md`: targeted-update core + both adapters + `allowed-tools`.** Add argument routing for `--from-review <spec-dir>` and `--since <ref>` (flag-first, strip-and-remainder per DD1); the targeted section-diff core; secret-scrub for diff-sourced content; `blueprint` ledger events; `commit-blueprint`; reuse the `auto_blueprint` gate; absent-blueprint fallthrough. Review adapter reads `metrics`+`diff`; ad-hoc adapter reads `diff-range <ref> HEAD`. Extend `allowed-tools` with `Read`/`Write`/`Edit`/`Glob`/`Grep` + the `jimledger.sh` Bash grant. Depends on tasks 2, 3, 4. (Skill prompt — meta-skill checklist is the authoritative gate.)
   **Verify:** `grep -Eq 'from-review|--since' /mnt/src/jim/skills/blueprint/SKILL.md && grep -q 'commit-blueprint' /mnt/src/jim/skills/blueprint/SKILL.md && grep -Eq 'allowed-tools:.*Write' /mnt/src/jim/skills/blueprint/SKILL.md`

7. [ ] **`review/SKILL.md`: add the blueprint-update step.** After `commit-review` (Step 8): `SET` `require_blueprint`/`auto_blueprint`; resolve the group from `spec.md`'s `group:`; invoke `Skill(jim:blueprint)` with `"<group> --from-review <spec-dir>"` when either knob is set (else offer conversationally); add the held-completion note. Extend `allowed-tools` with `Skill(jim:blueprint)` + jimconf reads. Depends on tasks 1, 6.
   **Verify:** `grep -q 'Skill(jim:blueprint)' /mnt/src/jim/skills/review/SKILL.md && grep -q 'require_blueprint' /mnt/src/jim/skills/review/SKILL.md`

## Requirements Coverage Summary

| Spec Acceptance Criterion | Addressed In Task(s) |
| :--- | :--- |
| AC1 — targeted diff-driven core, reuses `/jim:blueprint` | 6 (+DD1, DD2) |
| AC2 — review trigger, diff+verdict from ledger | 6, 7 (+DD5) |
| AC3 — ad-hoc trigger from a git range, no verdict | 4, 6 (+DD6) |
| AC4 — `auto_blueprint` writes without a prompt (both triggers) | 6 (reuses blueprint Step 5), 7 |
| AC5 — `require_blueprint` gates the review trigger (blocking) | 1, 7 |
| AC6 — both knobs off → review update offered, not forced | 7 |
| AC7 — one group per run (reviewed / ad-hoc-named) | 6, 7 |
| AC8 — no blueprint yet → generate path | 6 (fallthrough) |
| AC9 — update commits the refreshed blueprint (both) | 3, 6 |
| AC10 — never persist secret-looking values | 6 |
| AC11 — judgment over evidence; embedded content is data | 6 (+DD5) |

## Out of Scope

- **Multi-group updates** — one target group per run; deferred (issue #19/#21).
- **Cross-group contract graph** — issue #21.
- **Verification execution** of invariant methods — issue #22.
- **Working-tree/uncommitted diff source** — the ad-hoc adapter takes a committed range (`<ref>..HEAD`) so both endpoints validate as ids; diffing uncommitted changes is deferred (the update commits, so committing first is the natural flow).
- **`ARCHITECTURE.md` refresh** — *not deferred*: the `/jim:build` completion gate runs `/jim:arch`. Pipeline-owned, not a task and not an issue.

## Open Questions

- [x] ~Where does the update live / how invoked?~ → diff-driven core in `/jim:blueprint`, two flag adapters (DD1).
- [x] ~Ad-hoc diff source + injection safety?~ → `jimledger.sh diff-range`; each ref passes a ref-safety gate + `git rev-parse --verify --end-of-options` resolution to a SHA (not `is_valid_id`, which rejects `/`-refs) (DD6).
- [x] ~Does it commit, and how?~ → path-scoped `commit-blueprint` (DD3, AC #9).
- None blocking — no `[NEEDS CLARIFICATION]` markers.
