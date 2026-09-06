---
id: 20260807-push-failures-are-reported-as-contention
num: 274
title: "Push failures are reported as contention"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, diagnostics]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-07T11:43:53Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

`place_land` maps *every* origin-tier push failure to rc 3, which the retry loop
reads as contention.

A developer with read access but no push rights — the exact case the spec's
third user story anticipates — gets five attempts with backoff and then:

```
place.sh: 'jim/issues' kept moving; the mutation was not published after
5 attempts. It is unpublished, not lost — re-run to apply it.
```

The diagnosis is false, the advice will fail identically forever, and on the
`cmd_run` path the temp state was already removed by the cleanup trap, so
"not lost" is also wrong there. The same conflation covers a pre-receive hook
rejection, a protected branch, and a network drop mid-push.

Direct mode has its own version: `place_direct_publish` reports "'<dest>' has
diverged from '<remote>'" for any push failure, including an unreachable network
or an auth failure, and its "pull and push again" guidance is inapplicable to
either.

A related silent case: if the remote drops *between* retry attempts, the tier
flips to local with no stderr at all, and `cmd_run`'s deferral message is keyed
on a variable computed before the loop — so the run exits 0 having committed
locally and never pushed, saying nothing.

## Proposed action

The loop already re-reads the tip one line after the failure. Compare it against
the old tip: unchanged means the push failed for a reason that is not
contention, which deserves a different message and no further retries. Capture
git's stderr rather than discarding it, and give `place_commit_changes` a way to
report a mid-loop tier degradation back to its caller.

## Resolution (2026-08-11)

Fixed in `867ec04`. A rejection from a destination that has not moved is named
as something retrying cannot fix, and no further attempts are made against it. A
remote lost mid-publish is disclosed rather than degrading to the local tier in
silence — the deferral notices before the loop key on state fixed before it, so
that path said nothing. Covered by a pre-receive-hook case and a mid-run
remote-drop case.
