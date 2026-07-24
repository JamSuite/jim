---
id: 20260724-jim-issue-on-main-via-git-worktree
num: 19
title: "jim:issue files and indexes issues on main via git worktree"
status: open
priority: medium
labels: [issue, worktree, workflow]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-24T10:58:09Z
updated: 2026-07-24T11:12:52Z
origin: docs/issues/20260724-add-plugin-json-agents-key-guard-to-meta-validation-checklists.md
---

## Description

**Feature.** The `jim:issue` skill should know how to use git worktrees so that every issue-collection write — new issue files, edits, status changes, and INDEX.md regeneration — happens on `main`, regardless of what branch the developer's checkout is on. `main` becomes the single source of truth for the issue collection; branch-local filing strands issues until merge and produces INDEX.md conflicts across branches and concurrent sessions.

**Proposed mechanics** (proven manually 2026-07-24 while filing `20260724-add-plugin-json-agents-key-guard-to-meta-validation-checklists.md`):

1. `git worktree add <tmp> main`
2. `cd` into the worktree — **required, not optional**: jim scripts resolve artifact paths from `$PWD` (project-root-as-CWD invariant, documented in `skills/conf/scripts/jimconf.sh`), so invoking the worktree's script copy from the primary checkout silently writes into the invoking repo.
3. Run `new.sh` / `index.sh` there.
4. Commit on `main`, `git worktree remove <tmp>`.

The primary checkout never switches branches — dirty files and concurrent sessions in the same cwd are undisturbed.

**Branch-local visibility** (proven 2026-07-24): filing on `main` costs the current branch nothing. As long as the branch hasn't diverged, `git merge main` fast-forwards and pulls the collection into view — no merge commit, only `docs/issues/` touched. The skill can offer this as a follow-up step after each filing ("merge main to see the issue locally?").

**Scope: every mutation, not just filing.** Renames, body edits, and status changes go through the same worktree-on-main flow — demonstrated by this issue's own rename (`20260724-jim-issue-files-and-indexes-issues-on-main-via-git-worktree` → `20260724-jim-issue-on-main-via-git-worktree`), which itself had to happen on `main` and re-index there.

**Design questions for the spec:**

- Surface: a wrapper script (e.g. `skills/issue/scripts/on-main.sh`) so the candidate-batch emitters in other skills (research, spec — spec 018 § 7a callers) get the behavior too, not just `/jim:issue add`.
- Skip the worktree when `main` is already checked out clean.
- Fallback when no `main` exists (detached HEAD, differently-named default branch — resolve via jimconf key?).
- Auto-commit vs confirm-before-commit; commit message convention.
- Opt-out config for teams that want issues to ride feature branches through PR review.
