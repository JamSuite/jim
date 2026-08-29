---
id: 20260812-direct-arm-commit-is-hook-exposed-and-leaves-the-index-staged
num: 329
title: "Direct-arm commit is hook-exposed and leaves the index staged"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, git]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T21:53:47Z
updated: 2026-08-13T07:57:24Z
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

## Resolution

**2026-08-13.** Both defects and the related item are fixed in `19eb76e`.

**1. Hooks are scoped off** for that one invocation —
`git -c core.hooksPath=/dev/null commit`. The developer chose the first of the
two options this issue offers; building the commit with plumbing was declined
because it hand-rolls four calls to reach what one config flag already does,
and this arm exists precisely because plumbing leaves the index and working
tree behind.

The issue's warning about `--no-verify` was confirmed rather than taken on
trust: a `prepare-commit-msg` hook rewriting the message was observed replacing
the subject, and `core.hooksPath` was observed preserving it. That is why the
weaker flag is not used.

What this buys is that the two arms now agree. The routed arm builds its commit
with `commit-tree`, which no hook can reach, so the trusted verb enum is the
subject by construction there; leaving hooks live here made the same guarantee
hold on one arm and not the other. The cost is stated plainly: a project's
`pre-commit` hook no longer runs for issue commits specifically.

Pinned by `case_place_direct_commit_subject_survives_a_hook`, which installs a
`prepare-commit-msg` hook that rewrites the message and asserts
`docs(issues): close <id>` is what landed.

**2. A failed commit unstages what it staged**, so the checkout is left as the
arm's contract says. Pinned by
`case_place_direct_commit_failure_leaves_nothing_staged`, which fails the commit
by demanding a signature it cannot produce — a trigger that survives the hook
change, unlike this issue's suggested failing `pre-commit`, which the fix above
disables.

**3. The dotfile namespace is excluded from staging**, matching what
`place_snapshot` enforces by construction on the routed arm. `:(exclude)`
pathspec magic is unavailable here — `--literal-pathspecs` disables it, and the
whole `add` fails rather than the pathspec being ignored — so the exclusion is
applied by unstaging what the add picked up. Pinned by
`case_place_direct_publish_excludes_the_dotfile_namespace`.

Each of the three was proven by neutering its own guard and watching the case go
red, with the neuter diffed against a saved copy first.

**Not taken:** the `.gitignore` half. Adding entries for the tmp namespaces
would have to happen in the *consumer's* repository, which is not jim's to
write; and it would also hide a stranded temp from `place_dirty_guard`, which is
the one signal that something crashed mid-write. The staging exclusion closes
the publish route without touching either.
