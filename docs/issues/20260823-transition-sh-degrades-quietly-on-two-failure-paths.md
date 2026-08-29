---
id: 20260823-transition-sh-degrades-quietly-on-two-failure-paths
num: 371
title: "transition.sh degrades quietly on two failure paths"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, cli, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:31Z
updated: 2026-08-25T06:59:49Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

Two failure paths in `transition.sh` degrade quietly where the rest of the file
reports.

## The timestamp

```
now="$(bash "$JIMFILE" now)" || now=""
[[ -n "$now" ]] && changes+=$'\n'"updated"$'\t'"$now"
```

When the timestamp resolver fails, `now` is emptied and the `updated` field is
simply not written. The transition otherwise succeeds and reports success, so
the record silently keeps whatever `updated` value it had — which, for a
transition, is the one field guaranteed to be wrong afterwards.

## The placement handle

```
if [[ -n "$token" ]]; then
  bash "$PLACE" commit "$token" --verb "$verb" --id "$slug" >/dev/null || return $?
fi
```

This is the only failure path in the function that returns without aborting the
handle. Every other one — a failed field write, a failed index regeneration —
calls `place.sh abort "$token"` before returning. Whether an abort is also
correct after a failed `commit` depends on whether the door consumed the token
before failing; that is worth determining rather than leaving to inference from
an inconsistency.

## Why it matters

Neither is a data-loss bug. Both are places where the script knows something
went wrong and the caller cannot tell, in a file whose other paths are careful
to say so.

## Resolution (2026-08-25)

Fixed in `13b35b5`. One path was a defect and the other turned out to be correct; both are now
explicit rather than inferred.

**The timestamp refuses.** `transition.sh` emptied `now` when the resolver
failed and went on to report success, leaving `updated` at whatever the record
already held — the one field a move guarantees is wrong afterwards. It now
refuses, naming the cause, before anything is written, so the issue is left as
it was rather than moved with a stale record.
`case_transition_refuses_when_the_timestamp_cannot_be_resolved` pins all three
halves of that: the exit code, the message, and the record being byte-unchanged.

**The publish path is right as it stands.** The question this issue asked —
whether the door consumes the handle before failing — is answered by
`place.sh`: `rm -rf -- "$handle"` runs only after a successful publish, on both
the direct and the plumbing arm, and every refusal returns with the handle and
its edits intact. `case_place_begin_commit_conflict_preserves_state` already
pins that. So aborting after a failed `commit` would discard the developer's
work to tidy up state the door is holding on purpose. The asymmetry is
deliberate, and both the guard's own comment and the "every exit unwinds the
door" note above it now say so — the inconsistency was in the record, not the
code.

**Census.** Three other sites in the group empty a value on failure and carry
on: the environment's `user.email`, a filer that will not normalize, and the
alias count's per-value lookup. Each resolves into something the run reports —
a refused filing, an unrecoverable-filer row, a count of zero — rather than
into a success that hides it. The transition stamp was the only one whose
failure reached the operator as `rc 0` and nothing else.
