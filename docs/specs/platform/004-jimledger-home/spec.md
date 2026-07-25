---
title: "Relocate jimledger.sh to a dedicated platform home"
type: refactor
group: "platform"
id: "004"
status: approved
origin:
  - "docs/issues/20260725-relocate-jimledger-sh-out-of-skills-review-into-platform-owned-h.md"
---

# 004 Relocate jimledger.sh to a dedicated platform home

## Overview

Move the platform-owned `jimledger.sh` out of its file-level carve-out in the
sdlc `review` skill into a dedicated `skills/ledger/` home, fronted by a
read-only `/jim:ledger` inspection skill symmetric with `/jim:conf` and
`/jim:file`.

## Refactor Rationale

- **Motivation:** `jimledger.sh` is platform-owned but physically resides at
  `skills/review/scripts/jimledger.sh` — inside the sdlc group's territory —
  held there only by a file-level territory carve-out declared in
  `BLUEPRINT.md`. Ownership and location permanently disagree; the carve-out is
  a standing partition wart, and the location is hard-encoded across the plugin.
- **Current State:** The `review` skill addresses the script with the own-skill
  `${CLAUDE_SKILL_DIR}` sigil while every other consumer uses the cross-skill
  `${CLAUDE_PLUGIN_ROOT}/skills/review/scripts/...` path; `jimfile.sh` and
  `jimpartition.sh` hard-code the location via `BASH_SOURCE`-relative resolvers,
  and the test harness hard-codes it too. The location lives in roughly ten
  `allowed-tools` declarations, review's own-skill call sites, three path
  resolvers, several reference docs, and the partition docs — so the mismatch is
  load-bearing and can only be resolved by moving the file.
- **Desired State:** `jimledger.sh` lives in its own platform-owned
  `skills/ledger/` directory. `skills/ledger/` is wholesale platform territory,
  so no carve-out remains. Every consumer resolves the file at its new home,
  `review` uses the same cross-skill path as everyone else, and the directory
  carries a well-formed `/jim:ledger` read-only inspection skill (the plugin
  registers skills by SKILL.md presence, and every skill directory carries one).
  The ledger CLI's behavior is unchanged.
- **Affected Systems:** `allowed-tools` across `spec`, `sec`, `partition`,
  `blueprint`, `research`, `plan`, `build`, `verify`, `review`, and
  `agents/reviewer.md`; review's own-skill call sites; the `BASH_SOURCE`
  resolvers in `jimfile.sh` and `jimpartition.sh` and the path constant in
  `tests/jimledger.sh`; ledger references in the blueprint / verify / partition
  reference docs and `review-template.md`; the platform-group territory and
  carve-out note in `BLUEPRINT.md`; the platform and sdlc group blueprints'
  Structure sections; and the new `skills/ledger/` skill.

## User Stories

- As a jim maintainer, I want `jimledger.sh` to live in a platform-owned
  directory that matches its ownership, so the partition needs no carve-out and
  the location stops being a standing exception.
- As a developer, I want a `/jim:ledger` inspection command — symmetric with
  `/jim:conf` and `/jim:file` — so I can read a spec or blueprint dir's ledger
  events, latest metrics, and reconcile trend without reading raw `ledger.md`.

## Acceptance Criteria

- [ ] `jimledger.sh` resides at `skills/ledger/scripts/jimledger.sh`, with its
      git history preserved (moved, not re-created).
- [ ] No file-level carve-out for `jimledger.sh` remains in `BLUEPRINT.md` or
      either group blueprint; `skills/ledger` is declared wholesale platform
      territory, and the platform partition no longer records a
      location/ownership mismatch.
- [ ] Every *live* consumer resolves the ledger CLI at its new home — all
      `allowed-tools` declarations, in-skill body call sites, the two
      `BASH_SOURCE` resolvers, the test path constant, the current
      `000-blueprint`s, `BLUEPRINT.md`, and user-facing docs — and the `review`
      skill addresses it by the same cross-skill path every other consumer uses.
      Frozen historical spec artifacts and the `/jim:arch`-owned
      `ARCHITECTURE.md` are outside this grep-clean guarantee (see Out of Scope).
- [ ] The ledger CLI's behavior is unchanged: every existing subcommand produces
      identical output for identical inputs.
- [ ] A read-only `/jim:ledger` inspection skill exists at
      `skills/ledger/SKILL.md`, symmetric with `/jim:conf` and `/jim:file`,
      surfacing read-only ledger views (a spec/blueprint dir's stage events, the
      latest review metrics, and the reconcile trend) and exposing none of the
      mutating verbs (`event`, the `commit-*` family, `rename-tracked`).
- [ ] The `/jim:ledger` read-only boundary is capability-enforced: its
      `allowed-tools` declares one grant per surfaced read verb (e.g.
      `Bash(bash ${CLAUDE_SKILL_DIR}/scripts/jimledger.sh metrics *)`,
      `... last-reconcile *`), never a blanket `jimledger.sh *` — so the
      mutating and raw-diff verbs are absent from the capability, not merely
      omitted from the prompt.
- [ ] `/jim:ledger` conforms to the plugin-wide authoring conventions
      documented in `ARCHITECTURE.md` → Plugin Conventions and enforced by the
      meta-skill authoring checklist (allowed-tools exactness, sentinel and
      sigil discipline, line budget) — the same bar every jim skill meets.
- [ ] Existing tests pass without modification — no test assertion or logic
      changes; only path constants that reference the relocated file are updated
      as part of the move (a location change, not a behavior change).

## UI Mockup

*Illustrative only — the final shape mirrors the `/jim:conf` and `/jim:file`
inspection output and is settled during planning.*

```
$ /jim:ledger show docs/specs/platform/004-jimledger-home

  ledger — docs/specs/platform/004-jimledger-home
  spec        started   2026-07-25T18:51:07Z
  spec        finished  2026-07-25T19:20:00Z
  (latest metrics / reconcile trend rendered where present)
```

## Out of Scope

- Any change to an *existing* `jimledger.sh` verb's behavior, output, or
  arguments — this is a relocation, not a rewrite. (A single additive,
  read-only `events` verb backing AC5's stage-events view is in scope; every
  pre-existing verb stays byte-identical, per AC4.)
- Exposing the mutating verbs (`event`, `commit-review` / `commit-blueprint` /
  `commit-map` / `commit-verify` / `commit-rename`, `rename-tracked`) through
  `/jim:ledger`; those stay script-only, invoked by the skills that own those
  writes.
- Renaming the `jimledger.sh` script or any of its subcommands.
- Adding new ledger capabilities beyond the read-only inspection views named
  above.
- Rewriting frozen historical spec artifacts (the `plan` / `research` /
  `review` / `security.md` records in other spec dirs) that mention the old
  path, and hand-editing `ARCHITECTURE.md`'s path mentions — the former are
  point-in-time build history (the precedent set by leaving genuine history
  frozen), and the latter is regenerated by `/jim:arch` at the build completion
  gate.

## Open Questions

- [ ] Does `/jim:ledger` warrant its own bash test file, or is it
      checklist-validated only like the `/jim:conf` and `/jim:file` inspection
      skills? (Leaning checklist-only, matching precedent — the underlying CLI
      keeps `tests/jimledger.sh`.)
- [ ] Is the blueprint / territory refresh (the `BLUEPRINT.md` territory line
      and the group blueprints' Structure sections) performed within the build,
      or as a follow-up `/jim:blueprint` pass? (A plan decision; the end state
      is the same.)
- [ ] Exact read-view set and output shape for `/jim:ledger` — finalized against
      the `/jim:conf` / `/jim:file` altitude during planning.
