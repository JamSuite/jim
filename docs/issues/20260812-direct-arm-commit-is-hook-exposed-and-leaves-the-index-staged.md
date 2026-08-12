---
id: 20260812-direct-arm-commit-is-hook-exposed-and-leaves-the-index-staged
num: P-20260812-direct-arm-commit-is-hook-exposed-and-leaves-the-index-staged
title: "Direct-arm commit is hook-exposed and leaves the index staged"
status: open
priority: medium
labels: [issue, placement, git]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:47Z
updated: 2026-08-12T21:53:47Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

Two defects in `place_direct_publish`'s commit path, both about the difference
between the plumbing arm's guarantees and the checked-out arm's.

## 1. The commit is hook-exposed

`skills/issue/scripts/place.sh:752`:

    git --literal-pathspecs commit -q -m "$(place_message "$verb" "$id")" -- "$prefix" || return 1

No `--no-verify`, no `-c core.hooksPath=…`. So on this arm:

- a project `commit-msg` hook can rewrite the subject that the plumbing arm
  guarantees is fixed (`commit-tree`, `place.sh:1405`);
- a `pre-commit` hook can fail the publish or alter tracked content;
- a hook reading stdin can stall — `GIT_TERMINAL_PROMPT=0` covers git's own
  credential prompt only, so AC 4's "no confirm prompt beyond the filing
  confirmation" is not actually guaranteed here.

The whole point of DD 11's trusted verb enum is that raw text never reaches a
commit subject; a hook reintroduces exactly that on one arm.

Note `--no-verify` alone is an **incomplete** fix: per git's documented behaviour
it bypasses `pre-commit` and `commit-msg` only, leaving `prepare-commit-msg` free
to rewrite the message.

No test installs a local commit hook, so nothing pins the subject against one.

Judged drift in the third review and then dropped — none of that round's 24
follow-ons is this finding.

## 2. A failed commit leaves the developer's index staged

`place.sh:751-752` stages the collection into the real index and, on `git commit`
failure (defect 1's likeliest trigger — a failing project `pre-commit`), returns 1
with no unstage. The arm's contract elsewhere is that the checkout is left exactly
as it is (`place.sh:789-790`); here it is not.

## Action

1. Scope hooks off for that one invocation — `git -c core.hooksPath=<nonexistent> …
   commit` — or build the direct commit with plumbing as the routed arm does.
   Add a case that installs a `commit-msg` hook rewriting the subject and asserts
   `docs(issues): close <id>` survives.
2. On the `git commit` failure branch, reset the staged paths
   (`git reset -q -- "$prefix"`) before returning 1, or say in the error that the
   collection is left staged.

Related, same arm, worth folding into the same pass: `place_direct_publish` stages
with `git add -- "$prefix"` and applies no dotfile exclusion, unlike
`place_snapshot` (`place.sh:1388`, `! -name '.*'`). `.gitignore` carries no entry
for `.INDEX.md.tmp.*` / `.backfill.tmp.*` / `.normalize.tmp.*` / `.migrate.tmp.*`,
so a temp stranded mid-run is publishable to the shared branch on this arm — and a
temp stranded across runs instead trips `place_dirty_guard` and blocks every later
placed write until someone finds a hidden file. `tests/place.sh:516` covers the
plumbing arm only.
