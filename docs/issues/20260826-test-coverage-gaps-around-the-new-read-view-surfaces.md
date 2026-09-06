---
id: 20260826-test-coverage-gaps-around-the-new-read-view-surfaces
num: 396
title: "Test-coverage gaps around the new read-view surfaces"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, tests, read-views]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-26T02:35:25Z
updated: 2026-08-27T09:00:28Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## What

Six behaviors of the new read-view surfaces are correct by code trace but pinned
by no test case. Each was confirmed during the post-build review; none is a
defect. They are listed together because they are one class — the edges the
build's own cases did not reach.

## The gaps

1. **`stats` with a filter that matches nothing.** The list view's
   empty-match case is covered; the census view's is not. Its exit status
   depends on the trailing `if` with no `else`, which is correct but unasserted.
2. **`--cols` as the only argument.** The closed-hidden disclosure correctly
   does *not* fire, because `--cols` is a display option rather than a filter
   axis. Nothing asserts that it stays that way.
3. **`stats --filed-by me`.** The scope line reports the *resolved* identity
   rather than the literal `me`, because `resolve_person_axes` rewrites the axis
   before `scope_line` reads it. That is the more precise disclosure and almost
   certainly right — but no case exercises `stats` with a person filter at all.
4. **A `depends-on` target absent from the collection.** Reads as unblocked.
   Tracked separately as its own issue; noted here because the *test* gap is
   part of this class.
5. **`insights-graph` excluding a `depends-on`-only node from `BLOCKING`.** The
   existing case asserts the node is not isolated but never asserts it is absent
   from the blocking rollup, so the type gating is unpinned.
6. **`type: ""` and `filed-by: ""`.** The omission case exercises empty
   `claimed-by` and `outcome` only. The code path is shared across all four, so
   this is asymmetry rather than risk.

## Why file it rather than let it ride

Each is cheap to close and the fixtures already exist — most need one extra
assertion against a fixture the suite builds anyway. Left unlisted, they are the
gaps a later change walks into: items 1 and 3 sit exactly where the census view
would next be extended.

## Fix shape

Add them as the surrounding code is next touched, rather than as a batch. Item 5
is the one worth doing on its own, since it pins a type-gating property that a
future edge-reader refactor could silently drop.

## Resolution

Closed by five cases. The sixth item was already closed before this: `52d071e`
shipped `case_issues_render_blocked_by_a_dependency_outside_the_collection`,
which is exactly the assertion item 4 asks for, so this record's own list was
one shorter than it reads.

**Every behaviour was probed before it was asserted.** These are
characterization tests, and a characterization test written from a code trace
pins whatever the trace got wrong. Two of the six items in this record are
stated slightly off, and running them is what showed it:

- **Item 3 understates what the census discloses.** The scope line does not
  merely resolve `me` to an address — it reports the identity in the
  collection's own recorded form. Querying as
  `1234+alice@users.noreply.github.com` prints `scope: filed-by=alice`, the
  account name the configured form extracts, which is also the form the
  comparison ran under. So the line and the count agree by construction rather
  than by coincidence, and the pinned property is the stronger one.
- **Item 1's "trailing `if` with no `else`" has two branches, not one.** The
  verb's status comes from the integrity-warnings block either way, so the case
  runs an empty match over a sound collection *and* over one carrying a
  warning. Only the first exercises the branch this record names.

**Item 6 was widened from the two fields it names to the rule underneath
them.** The row emitter guards nine optional fields, not four, and a case
enumerating its own subset agrees with the rule by coincidence — the shape this
increment's retrospective is about. The case reads the field list out of the
emitter itself, so a field added to the row cannot skip the guard, and it also
asserts the whole row by equality, which catches a leaked key whether the
extraction named it or not.

**Each case was mutation-tested rather than trusted for passing.** All five
were green on first run, which is also what a test that asserts nothing looks
like. Each was confirmed to fail against a deliberate break of the exact
behaviour it claims to pin: the scope line removed, the closed-hidden
disclosure freed from its axis guard, `me` left unresolved, a `depends-on` edge
given a blocking out-degree, and the `type` key emitted unconditionally. One
mutation silently failed to apply and the case passed for the wrong reason —
which is the whole argument for doing this.

**A question probed and settled as not a defect.** `labels: []` — the spelling
the capture checklist tells authors to use, and the one `new.sh` emits for a
record with no labels — does reach the row as a literal `labels: []` pair,
unlike every other empty scalar. It is not a defect: `read_issue_rows` strips
the brackets, so an empty list reads back as empty, the census clusters nothing
under it, and the list view renders it as absent. The emitter and the reader
invert each other exactly. Recorded because reading the emitter alone suggests
otherwise.

**Pinned by** `case_issues_render_stats_empty_match_succeeds` (item 1),
`case_issues_render_cols_alone_is_not_a_filter` (item 2),
`case_issues_render_stats_person_axis_reports_the_resolved_identity` (item 3),
`case_issues_render_insights_graph_depends_on_is_not_a_blocking_edge` (item 5),
and `case_issues_index_row_omits_every_empty_field` (item 6).

**Not closed by this, and found while running it.** The suite carries one case
that passes for the wrong reason:
`case_issues_index_wikilink_in_inline_backticks_ignored` builds its fixture
body in double quotes, so the wikilink it exists to test is consumed as command
substitution before the file is written. The body reaches disk reading
"Authors who write  in prose…" — the wikilink gone — and the case then asserts
that no edge was produced, which is true of a body containing no wikilink at
all. The shell reports it on every run. It is the same class as this record —
a behaviour pinned by a case that does not reach it — but a different defect
from the six listed, so it is left for its own decision rather than folded in
here.

**That decision was taken: fixed in `21eec13`.** It was two defects, and the
quoting was the smaller one. Even spelled correctly the fixture's token was
`[[B]]`, on which neither assertion could fail — the edge assertion looks for
an edge to `20260530-b`, which a differently-named target never makes, and the
warning assertion needs a target that fails `is_valid_id`, which guards
containment rather than slug shape, so a bare name passes it and yields an edge
to an unvalidated target with no warning at all. The fixture now spans a
resolvable slug and a traversal shape, and disabling the inline-span strip
fails both assertions where the half-fixed version failed one.
