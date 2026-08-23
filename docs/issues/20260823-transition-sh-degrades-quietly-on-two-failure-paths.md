---
id: 20260823-transition-sh-degrades-quietly-on-two-failure-paths
num: 371
title: "transition.sh degrades quietly on two failure paths"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [issue, cli, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:45:31Z
updated: 2026-08-23T23:45:31Z
origin: "docs/specs/issue/012-schema-and-state-model/spec.md"
---

## Description

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
