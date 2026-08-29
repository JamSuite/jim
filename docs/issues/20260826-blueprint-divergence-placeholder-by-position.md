---
id: 20260826-blueprint-divergence-placeholder-by-position
num: 386
title: "Blueprint divergence: placeholder-by-position"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, drift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:44:32Z
updated: 2026-08-26T08:51:40Z
origin: "docs/specs/issue/014-read-view-filter-composition"
---

## Description

resolved: fix the code

## The invariant

> The placement wrapper substitutes only the placeholders a caller positioned —
> a flag's operand, or the trailing argument it appended — never an argument
> matching a placeholder's text elsewhere in the argv. Forwarded caller text can
> look exactly like one, and rewriting it puts a run-local path into a durable
> identity.

## What diverges

`place_substitute` recognizes `{}` as a placeholder when the preceding argv
element is literally `--dir`, or when it is the trailing argument. It has no way
to know which script's grammar produced that adjacent `--dir` — the check is
textual adjacency, and the function's interface carries nothing else to key on.

The read views' composed filter grammar made that adjacency reachable from
caller text. Two properties combine:

- a filter flag's operand may be any string, and the operand guard refuses only
  this file's own option names — `--dir` is not one of them, so it is carried
  through as an ordinary value;
- a single trailing unclassified word becomes the residue slot, so a bare `{}`
  survives classification.

## Reproduced

In a repository configured with a branch placement:

```
$ render.sh list --label --dir '{}'
error: unrecognized filter token: /tmp/<run>/collection
       ...
       a collection is named as the trailing argument
```

The path in that message is the run's real materialized collection directory.
The caller's own `{}` — filter residue, never a positioned placeholder — was
rewritten with it, because it happened to sit after a filter value that read
`--dir`. The wrapper's own trailing `{}` was substituted too, so the re-executed
command received two unclassified trailing tokens and refused.

## Reach

On this read path the harm is a spurious refusal plus a run-local temp path on
stderr. It is not the durable-identity corruption the invariant's own text warns
about — that scenario needs a write verb whose grammar accepts a value equal to
`--dir` alongside a bare `{}`, which the emitter's parser does not.

But `place_substitute` is shared verbatim by every entry script, so the class is
wider than the one route. What the read views did was make the first reachable
instance of it.

## Where

- `skills/issue/scripts/place.sh:253` — the adjacency test
- `skills/issue/scripts/render.sh:182-195` — the operand guard, which refuses
  only this file's own option names
- `skills/issue/scripts/render.sh:292-296` — the residue slot

## Fix shape

The substitution's weakness is that it infers intent from adjacency. Options, in
increasing strength:

1. **Mark the placeholders positionally at construction.** The caller already
   knows which argv slots it put placeholders in; passing those indices, rather
   than re-deriving them from text, removes the inference entirely.
2. **Substitute only the trailing argument and a placeholder whose flag the
   wrapper itself emitted**, tracking the latter as it builds the command rather
   than scanning for it afterward.
3. **Refuse a caller-supplied argument that is exactly a placeholder token**
   before the wrapper runs, in each entry script's own parser. Cheapest, and it
   pushes the rule onto every caller — which is what the current design already
   does implicitly and is why this was reachable.

No test in either suite exercises a caller-supplied value equal to `--dir`; the
existing coverage tests the wrapper's own hardcoded `--dir` and a directory
named like a filter value.

## Resolution

Fixed in `9cc6185`, taking the first of the three fix shapes above.

`place.sh run` gains `--dir-at` and `--token-at` — offsets into the wrapped
command, negative counting from the end. `place_substitute` substitutes at
those offsets and examines nothing else, and refuses at rc 2 when a declared
offset is out of range or holds something other than the marker it names. Both
halves of the old inference are gone: the `--dir` adjacency test and the
trailing-argument rule.

All six entry scripts declare their own positions. Five append the collection
last and carry the token fourth (`--token-at 3 --dir-at -1`); `new.sh` appends
`--dir {} --place-token {token}`, so its markers sit third from the end and
last (`--dir-at -3 --token-at -1`).

Confirmed by probing the wrapper before and after rather than by reading. The
argv `… list --label --dir '{}' '{}'` previously came back with both `{}`
rewritten to the run's collection path; it now returns the caller's own `{}`
verbatim and fills only the declared trailing slot.

Pinned by `case_place_substitutes_only_at_declared_positions`,
`case_place_declared_position_must_hold_a_placeholder` and
`case_place_undeclared_placeholders_are_left_verbatim` in `tests/place.sh`. The
end-to-end route also carries `case_issues_placement_marker_shaped_argv_reaches_the_parser`
in `tests/issues.sh`, which pins the composed boundary rather than the wrapper —
its own comment says so, because it does not go red against a wrapper that
still infers.

The blueprint invariant was updated to record the stronger rule: the code no
longer implements the "flag's operand or trailing argument" mechanism the
invariant described, it implements a strictly narrower one.
