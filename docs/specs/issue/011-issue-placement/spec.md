---
title: "Issue placement — configurable issue content location"
type: feature
group: "issue"
id: "011"
status: approved
origin:
  - "docs/issues/20260728-spec-issue-placement-config-for-issue-content-location.md"
  - "docs/issues/20260724-jim-issue-on-main-via-git-worktree.md"
  - "docs/brainstorms/20260724-id-coordination.md"
---

# 011 Issue placement — configurable issue content location

## Overview

A single `issue_placement` config key lets a project choose where issue *content* lives — the current working branch (today's behavior, the default), or a designated branch such as `main` or a dedicated issues branch — so that a team's issue collection has one source of truth instead of forking across feature branches.

## Problem Statement

Issue files and `INDEX.md` ride whatever branch the developer happened to be on when filing. On a team, that means a discovery filed on a feature branch is invisible to everyone else until the branch merges, an issue closed on one branch stays open on every other, and concurrent sessions produce recurring `INDEX.md` merge conflicts. `issue/010` made issue *identity* centrally durable (the allocator reserves the ordinal and durable id on the coordination branch at filing time), but the *content* — the issue body, its status, and the index — still diverges per branch. The collection is a cross-branch discovery artifact being stored in per-branch fragments.

## User Stories

- As a developer on a team, I can file an issue from my feature branch and have it land on the team's designated issues branch, so that my teammates see the discovery without waiting for my branch to merge.
- As a developer on a team, I can close or edit an issue from any branch and have the change land at the designated destination, so that the collection never says both `open` and `closed` for the same issue.
- As a developer on a team whose `main` is push-protected, I can point issue content at a dedicated branch, so that centralized issues do not require push rights to `main`.
- As a solo developer, I can leave `issue_placement` unset and observe today's behavior unchanged, so that centralization costs me nothing I didn't opt into.
- As a developer reading the collection, I can run the read verbs from any branch and see the destination's current collection, so that I never act on a stale or partial view.

## Acceptance Criteria

- [ ] **Config contract.** One key, `issue_placement`: the reserved sentinel `branch` (or the key absent) means the current working branch — today's behavior; any other value is a git branch name naming the destination (e.g. `main`, `jim/issues`).
- [ ] **Default unchanged.** With the key absent or `branch`, all issue reads and writes behave exactly as today; the existing test suite passes without modification.
- [ ] **Writes land at the destination.** Under a branch-name placement, *every* collection write — filing (interactive `add` and every surfacing skill's candidate batch alike), body edits, status changes, renames, provisional realization, and `INDEX.md` regeneration — lands on the destination branch, leaving the working branch's tree untouched.
- [ ] **One commit per mutation.** Each mutation auto-commits on the destination as exactly one commit with a fixed, conventional message; no confirm prompt beyond the filing confirmation that already exists.
- [ ] **Reads follow placement.** Under a branch-name placement, the read verbs (`list` / `stats` / `show` / `insights`) serve the destination branch's collection, never a branch-local copy.
- [ ] **Freshness.** When a remote exists, reads consult the freshest reachable state of the destination branch before serving; when the remote is unreachable, they serve the last-seen state and say so.
- [ ] **Writes never block on the network.** A write commits on the local destination branch and propagates to the remote; when propagation is rejected because the remote moved, the write is reapplied and retried rather than lost; when the remote is unreachable, the local commit stands, propagation completes later, and the degradation is reported. No mutation is ever silently dropped.
- [ ] **Missing destination bootstrap.** A destination branch that does not exist yet is created on first write as an orphan branch carrying only the issue collection (the registry-branch precedent).
- [ ] **Coordination branch refused.** A placement value naming the configured coordination branch is refused with a clear error — that branch holds registry logs only.
- [ ] **Junk config refused.** A placement value that is not a valid git branch name causes reads and writes to refuse with a config error naming the value; placement never silently falls back to `branch`.
- [ ] **Dangling origins tolerated.** An issue whose `origin:` cites an artifact that exists only on the filing branch remains valid at the destination; the reference is informational and its absence is not an error.
- [ ] **Rewrite detection.** Under a branch-name placement, a destination tip that has moved non-fast-forward relative to the last-seen state is detected and disclosed by the read verbs — a rewritten collection is never served silently as current. *(security Finding 1; prevention rides #118's branch-protection docs)*
- [ ] **Auto-filing keeps a scrub moment.** Under a branch-name placement, the quiet auto-file path (`auto_issue_file = "true"`) degrades to the interactive batch confirm with a one-line disclosure, unless the configuration explicitly acknowledges that auto-filed content publishes immediately and irreversibly. *(security Finding 2)*

## Out of Scope

- **Automated migration on a placement flip.** Changing `issue_placement` mid-project requires a one-time manual move of the existing collection to the new destination (documented; no transition scaffolding).
- **Issue content on the coordination branch.** The coordination branch's registry-logs-only contract (`platform/007`) is untouched; this spec adds a refusal, not an exception.
- **A distinct "reservation" mode.** The brainstorm's reservation model — id central, body on branch — is the de-facto status quo since `issue/010` and is exactly what `branch` placement plus the allocator already provides; it is not a separate placement value.
- **Service-backed placement** (e.g. GitHub Issues as the destination) — future allocator-backend territory.
- **Per-issue or per-filing placement overrides.** One project-wide key.
- **Coordination-branch protection and team setup documentation** — tracked separately (#118).
- **Fork-workflow contributors.** A contributor without push rights to the shared repo gets local-only centralization (commits on their fork's destination branch; propagation fails loudly) — the same honest scope as the registry mechanism (brainstorm G5).

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive.*

### Insight 1: Proven worktree-on-destination mechanics

- **Relates to AC:** *"every collection write lands on the destination branch, leaving the working branch's tree untouched"* (AC #3)
- **Surfaced as:** Issue #96's manually-proven flow: `git worktree add <tmp> <dest>` → run `new.sh`/`index.sh` with the worktree as `$PWD` in a subshell (`(cd <tmp> && …)`, never a bare `cd` — a shell left standing in a removed worktree breaks every later git command) → commit via `git -C <tmp>` → `git worktree remove <tmp>` from the primary checkout. Required because jim scripts resolve artifact paths from `$PWD` (project-root-as-CWD invariant).
- **Levelled-up requirement (already in the ACs):** writes land at the destination without disturbing the working branch.
- **Deflection reason:** Delegation — mechanism, not outcome.
- **Architect note:** #96 hit the bare-`cd` failure three times during manual runs; the subshell discipline is load-bearing. A skip-the-worktree fast path when the current branch *is* the destination and clean is worth weighing. Consider a single run-at-destination primitive that all mutation paths (emitter, index, reconcile, ad-hoc edits) route through, rather than per-script worktree logic.
- **Routing hint:** Architect to decide.

### Insight 2: Push-retry loop mirrors the allocator's CAS discipline

- **Relates to AC:** *"when propagation is rejected because the remote moved, the write is reapplied and retried rather than lost"* (AC #7)
- **Surfaced as:** the interview's "commit locally then push, retry non-fast-forward like the registry does".
- **Levelled-up requirement (already in the ACs):** concurrent mutations are never silently lost.
- **Deflection reason:** Delegation.
- **Architect note:** unlike registry appends, content commits can genuinely conflict (two users editing the same issue file); the reapply step may need merge/rebase semantics, not just re-append. `jimalloc.sh`'s bounded-retry/backoff shape and its non-interactive-git posture (`GIT_TERMINAL_PROMPT=0`, brainstorm G7) are the precedents.
- **Routing hint:** Architect to decide.

### Insight 3: Orphan-branch bootstrap precedent

- **Relates to AC:** *"created on first write as an orphan branch carrying only the issue collection"* (AC #8)
- **Surfaced as:** "same as registry branch approach" (interview decision).
- **Levelled-up requirement (already in the ACs):** a missing dedicated destination self-bootstraps.
- **Deflection reason:** Constraint-Sourcing — the registry branch's bootstrap in `jimalloc.sh` is the in-repo precedent to mirror.
- **Architect note:** the worktree flow must handle checking out an orphan branch whose tree contains only `docs/issues/`.
- **Routing hint:** Architect to decide.

### Insight 4: Branch-name validation boundary

- **Relates to AC:** *"a placement value that is not a valid git branch name causes reads and writes to refuse"* (AC #10)
- **Surfaced as:** the junk-config discussion.
- **Levelled-up requirement (already in the ACs):** invalid placement refuses; no silent fallback.
- **Deflection reason:** Delegation.
- **Architect note:** the config value is interpolated into git commands (worktree add, fetch, push refspecs); it must pass a validation gate before any interpolation — `git check-ref-format`-shaped, plus the leading-`-` / pathspec-magic hygiene the ledger and partition scripts already practice. The coordination-branch refusal (AC #9) belongs at the same gate.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Is "reservation-only" a live placement mode?~ → No — de-facto shipped by `issue/010`; the placement axis is content location only.
- [x] ~Enum + second key vs single key?~ → Single key; `branch` is a reserved sentinel, everything else is a branch name.
- [x] ~Hard-fail on unreachable remote?~ → No — local commit stands, propagation deferred loudly; only invalid config refuses.
- [x] ~Auto-commit or confirm at the destination?~ → Auto-commit, one commit per mutation.
- [x] ~Missing dedicated branch?~ → Auto-create as orphan, registry-branch style.
- [x] ~Placement flip migration?~ → Manual, documented, out of scope.
