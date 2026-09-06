---
id: 20260826-unrecognized-flag-is-accepted-as-a-flag-s-value
num: 397
title: "Unrecognized flag is accepted as a flag's value"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, read-views, filters]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:34:18Z
updated: 2026-08-26T08:55:15Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## What

`need_operand` refuses an operand that is one of *this file's own* option names,
so `--label --priority` is caught. It does not refuse an operand that is
flag-shaped but unrecognized, so:

```
$ render.sh list --label --nosuchflag <dir>
rc 0 — `--nosuchflag` is bound as a label alternative
```

Standing alone, the same token is recognized as a flag and refused with
`unknown filter flag: --nosuchflag`. The parser therefore holds two opinions
about the same text depending on where it sits.

## The gap between the criterion and the decision

The acceptance criterion reads: *"A flag given with no value, or with a value
that is another flag, is refused rather than treated as absent."* The plan's
design decision narrowed this to "a flag whose operand is another **known**
flag", and the implementation follows the decision.

The narrowing has a stated rationale, and it is a good one: the recordable
identity set admits a leading hyphen deliberately, so `--claimed-by
-dev@example.test` must keep working. But that rationale concerns *single*-hyphen
values. The carve-out as written also swallows double-hyphen tokens, which no
address wears.

## Fix shape

Refuse a `--`-prefixed operand; carry a single-hyphen one through. That matches
the stated rationale exactly and closes the gap against the criterion, without
breaking the leading-hyphen address case the decision was protecting.

## Resolution

Fixed in `95d56cc`, in the same diff as
[[20260826-empty-shaped-filter-operand-silently-matches-everything]].

`need_operand` refuses any double-hyphen operand rather than only the option
names this file declares. The rule is about a flag arriving where a value
belongs, and a flag the file does not accept is still a flag; enumerating the
file's own options was the wrong set for the rule, which ranges over any flag.

One hyphen is still carried through. That is the design decision's own stated
rationale intact — the recordable-identity set admits a leading hyphen
deliberately and a real address can wear one — and the boundary now sits
between one hyphen and two rather than between known and unknown.

**The same widening landed on `migrate.sh`'s sibling guard**, which a SYNC
marker binds to the shared rule, and it closed a live defect there rather than
a latent one: `migrate identity --from --nosuchflag --to <addr>` ran the remap
at rc 0 with an unrecognized flag bound as the from-address. Its boundary case
moved with it. The marker's text was rewritten to describe the asymmetry that
remains, and a judge confirmed the description still matches both post-change
bodies.

Pinned by `case_issues_render_flag_shaped_operand_refuses` (looping
`RENDER_OPTIONS`), `case_migrate_identity_usage_refuses_an_unknown_flag_where_a_value_belongs`,
and `case_migrate_identity_hyphen_values_accepted_but_flags_are_not`, which
pins the one-versus-two-hyphen boundary and says in its own comment that it
pins the boundary rather than the guard.
