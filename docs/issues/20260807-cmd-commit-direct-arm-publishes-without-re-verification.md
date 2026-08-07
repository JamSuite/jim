---
id: 20260807-cmd-commit-direct-arm-publishes-without-re-verification
num: 264
title: "cmd_commit direct arm publishes without re-verification"
status: closed
priority: critical
labels: [issue, placement, security]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:22Z
updated: 2026-08-07T20:27:17Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`cmd_commit`'s `direct` arm re-resolves configuration and verifies nothing about
the state `begin` established. `direct` is a fixed literal token, not an
unguessable handle, so it is callable at any time with no proof a `begin`
happened.

**A read handle publishes.** Reproduced:

```
$ place.sh begin --read                 ->  direct	docs/issues
$ place.sh commit direct --verb close   ->  rc 0
  HEAD now: HALF-FINISHED PRIVATE NOTE
  last subject: docs(issues): close
```

`begin --read` skips the dirty guard (correctly — it is a read) and then returns
the same token a write `begin` returns. The read-only refusal in `cmd_commit`
reads handle *state*, so it covers plumbing handles only. The result is that the
insights flow's own token is a publish capability that stages whatever
uncommitted edits are sitting in the collection.

`skills/issue/SKILL.md` states "A read handle cannot publish: `commit` refuses
it." That is false in direct mode. This is the exact harm the dirty guard exists
to prevent, reached through the path documented as safe.

**No HEAD re-check.** `begin` emits `direct` only because HEAD was the
destination at that instant. Switch branches before `commit` and the collection
is committed onto the *feature* branch, then `git push HEAD:refs/heads/main`
publishes the entire feature branch to the shared issues branch — succeeding
silently whenever the feature descends from main.

**No sentinel guard.** If `issue_placement` is absent at commit time,
`place_destination` returns the literal string `branch`, and the arm pushes to
`refs/heads/branch`, creating a junk remote branch.

The handle arm is drift-immune by design — it reads recorded state. Only the two
sentinel arms re-resolve, and that asymmetry is undocumented and untested.

## Proposed action

In the `direct` arm: refuse when `place_destination` returns the `branch`
sentinel; re-assert `git symbolic-ref --short HEAD == dest` and refuse on
mismatch; and give the sentinel a read flag so a `--read` handle cannot reach
`place_direct_publish`. The last is the security-relevant one.

No test exercises `begin`/`commit`/`abort` in direct mode at all.
