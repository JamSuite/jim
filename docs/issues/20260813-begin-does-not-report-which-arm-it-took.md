---
id: 20260813-begin-does-not-report-which-arm-it-took
num: 345
title: "begin does not report which arm it took"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, placement, contracts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-13T09:40:47Z
updated: 2026-08-13T09:40:47Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`place.sh` has two verbs a caller uses to decide how to reach the collection, and
they answer different questions:

- `mode` answers *"should you re-exec through place.sh?"* — `route` or `direct`.
  Entry scripts gate their re-exec on it (`skills/issue/scripts/index.sh:314`).
- `begin` answers *"here is the collection"* — `<token>\t<dir>`, where the
  directory is a **materialized copy under the git dir** on one arm and the
  **working tree's own collection** on the other.

Which arm `begin` took is not reported anywhere. `mode` cannot report it: `mode`
prints `route` whenever the destination is not the sentinel `branch`, including
when the destination branch is the one checked out — and that is correct, because
the entry scripts must keep routing on that arm or they lose
`place_direct_publish`, the auto-commit that publishes a direct-arm mutation.

So a caller holding a handle knows only that placement is active. Any property it
wants to assume about the directory it was handed — that the entries were
materialized, that they cleared `place_materialize`'s mode / plain-name /
containment gates, that writes there are staged rather than live — holds on one
arm and not the other, with nothing in the interface to distinguish them.

This has already produced one `critical` containment defect in the one external
caller there is (`sweep_citations` in `skills/spec/scripts/reconcile.sh`, closed
by re-deriving containment from the enumeration instead of from the provider).
That fix is arm-agnostic and does not depend on this being resolved; it removes
the coupling at one call site rather than closing the class.

## Why it was not bundled

`begin`'s output is `<token>\t<dir>` and every consumer parses it as
`${out%%$'\t'*}` / `${out#*$'\t'}`. A third field is a breaking change to the
`place.sh` Provides face and to the contract-graph entries that back it, so it
does not belong inside a containment fix.

## Action

Decide how a handle holder learns which arm it holds. Candidates:

1. A third field on `begin` (`<token>\t<dir>\t<arm>`) — breaking; the Provides
   face and both placement contract edges move with it.
2. A separate verb (`place.sh arm <token>`) — additive, and readable only by
   someone already holding a handle, which is exactly the audience.
3. Leave the interface as it is and make "the caller establishes its own
   containment on whatever it was handed" the documented rule — cheapest, and
   what the containment fix already does, but it stays a convention rather than
   something the interface enforces.

Whichever is taken, `place.sh`'s Provides face should say plainly that the
directory `begin` hands back is not guaranteed to be a materialized copy.
