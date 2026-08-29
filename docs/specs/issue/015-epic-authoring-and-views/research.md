---
spec: "docs/specs/issue/015-epic-authoring-and-views/spec.md"
status: Needs PM Review
date: "2026-08-27"
---

# Research: Epic authoring and views

Two of the spec's Handoff insights describe the code as it was before the
preceding increment's remediation, not as it is. Both are corrected under
Peer Feedback. The substrate is in better shape than the spec assumes; the
counting change is harder than it assumes.

*Scope: Phase 0 only. External research was not run — the increment adds no
dependency and references no external API, format or example, so there is
nothing for Phase 1 to ground. Local scanning was delegated to four parallel
read-only agents; every claim either carries a file:line anchor or was
re-derived directly, and the two agent claims this document relies on most
were verified by hand before being written down.*

## Anchors

**The index's section assembly**

- `skills/issue/scripts/index.sh:800-828` — the four section emitters
  (`## Summary`, `## Issues`, `## Graph`, `## Integrity Warnings`), each
  printing a header then a conditional accumulator. A `## Epics` section slots
  between `:815` and `:816`; its accumulator joins the others declared at
  `:400`.
- `skills/issue/scripts/index.sh:836-843` — composition into a tmp file and the
  atomic `mv`. Nothing new is needed here.
- `skills/issue/scripts/index.sh:173-207` — `parse_relations`, which is
  type-agnostic and already yields `part-of` pairs. The umbrella roster is
  derivable from data the index already holds.
- `skills/issue/scripts/index.sh:744-751` — the existing umbrella-resolves
  check. The nesting and non-epic-umbrella warnings the spec adds belong beside
  it, iterating the same `outgoing_fm` edges.
- `skills/issue/scripts/index.sh:410` — `outgoing_fm` (frontmatter only, drives
  integrity checks) and `outgoing_all` (union with wikilinks, drives the Graph
  render at `:777-785`). Membership checks must read `outgoing_fm`: a wikilink
  must not create a membership.

**The graph read seam**

- `skills/issue/scripts/render.sh:484-502` — `read_graph_edges <index> <type>`,
  the single reader of `## Graph`. Its slug class matches `is_valid_id`'s, with
  the rationale written at `:468-483`.
- Five call sites, all through the helper: `:732` (stats blocking), `:934`
  (`depends-on`), `:937` (`part-of`), `:1450` and `:1454` (insights). The
  roster and progress derivations become sites six and seven.

**The counting surface**

- `skills/issue/scripts/render.sh:617-756` — `cmd_stats`.
- `:655-681` — the one loop carrying every per-record accumulation:
  `seen_rows` (`:658`), `saw_type` (`:659`), `matching` (`:661`), open/closed
  (`:662-666`), origin (`:668`), priority (`:670`), labels (`:674-680`).
- `:727-732` — the blocking loop, a *second* record set: graph edges, gated on
  `matching`.
- `:688-719` — the render order; a per-epic rollup slots after labels (`:719`)
  and before `== Blocking ==` (`:722`).
- `skills/issue/scripts/render.sh:423-466` — `read_issue_rows`, the 12-field
  TSV both loops feed from.

**The write path**

- `skills/issue/scripts/transition.sh:49` — `TRANSITION_VERBS`; `:353-389` —
  `apply_verb`'s dispatch; `:204-213` — the argument loop. **No verb takes a
  second positional operand**; `--as` is a flag. `join <id> <umbrella>` is a
  new argument shape for this script, not just a new case arm.
- `skills/issue/scripts/place.sh:105-106` — `PLACE_VERBS`; `:220-229` —
  `place_valid_verb`; consumed at `:1156` and `:1772`; `:1674-1681` —
  `place_message`, which composes `docs(issues): <verb> <id>`. A new verb
  reaches published history through that one function.
- `skills/issue/scripts/new.sh:219` — `allocate issue`. Refusals above it are
  free; refusals below it spend an ordinal permanently.
- `skills/issue/scripts/new.sh:246-252` — the issues-directory resolution,
  which depends on nothing the allocation produces.

**Tests**

- `tests/issues.sh:8639-8680` — `derived_fixture`, which **already builds an
  epic with `part-of` members** and completed dependencies. The epic fixture
  the increment needs largely exists.
- `tests/issues.sh:135-143` — `write_issue`; `:8278-8280` —
  `render_vocabulary`, which reads a `readonly` constant out of `render.sh`.
- `tests/issues.sh:5310`, `:5324`, `:5343` — existing cases for an epic kind,
  an unresolvable umbrella, and single-sided membership.
- 402 cases, 9,294 lines.

## Local Patterns

**The test framework is narrower than it looks.** Only four assertion helpers
exist: `assert_eq`, `assert_match` (ERE), `assert_exit`, `assert_nonempty`.
There is no `assert_ne` and no `assert_contains`; absence is asserted as
`assert_eq "label" "0" "$(… | grep -c …)"`. Cases are discovered by the
`case_` name prefix, and each builds its own sandbox via `empty_dir`.

**Vocabulary-iterating tests already exist**, which is the preceding
retrospective's recommendation (2) already implemented rather than pending:
`tests/issues.sh:8371-8400` loops `COL_TOKENS`, and `:8337`, `:8359`, `:8448`
loop `SCHEMA_GATED_FIELDS`, `AXIS_FIELDS` and `RENDER_OPTIONS`. A new
vocabulary added for this increment inherits that pattern for free — and the
`declared-vocabularies` invariant makes it obligatory rather than optional.

**`derived_fixture` is the template.** It is the corpus-shaped helper the
group converged on, and it already carries the epic-and-members shape. Prefer
extending it over writing epic frontmatter inline in new cases.

## Security & Performance

**`matching` carries two meanings, and the counting change collides with
that.** At `:661` `matching[$slug]=1` records "this row passed the filter". At
`:729` the blocking loop reads the same array to mean "this record is in
scope". The spec requires epics to be excluded from every count — but they
must *not* be excluded from `matching`, because `stats --type epic` is a legal
query whose blocking rollup should still work. So the exclusion cannot be one
`continue` in the main loop: the set of records that matched and the set that
counts as work are different sets, and today they are one variable. Deciding
this in the plan is cheaper than discovering it in the build, and it is the
same one-set-two-roles shape the preceding retrospective identifies as its
root cause.

**`saw_type` and `seen_rows` are computed before `row_matches`** (`:658-659`),
so the schema-staleness gate is unaffected by any exclusion applied later in
the loop. Worth preserving deliberately — moving an exclusion above them would
silently disarm the staleness refusal.

**Hoisting the directory resolution is safe; hoisting the collision handling is
not.** `new.sh:246-252` depends on nothing the allocation returns, so it can
move above `:219` to let an umbrella-existence check refuse before an ordinal
is spent. The local-collision logic at `:270-287` genuinely depends on the
allocated slug and must stay below. The two should not move together.

**Index growth is unmeasured.** The preceding increment measured its index cost
before committing to it (+11.8% predicted, +12.0% actual). A `## Epics` section
listing every member is unbounded — one spec in this collection's own history
generated 88 issues. Measure before choosing between a full roster and a capped
one; the spec's second open question is exactly this, and it is answerable with
a fixture rather than an argument.

## Alignment

`ARCHITECTURE.md:2027` already states that "`blocked` and `epic` are derived
from the index's `## Graph` rather than stored, so no record can contradict
them" — the spec extends an existing architectural commitment rather than
introducing one. `VISION.md` § Non-Goals was amended this session (`ac8da2d`)
so that recording, querying and **rolling up** who holds a discovery is in
scope; the umbrella progress rollups fall inside that boundary deliberately.
The `issue` group blueprint's `declared-vocabularies` and
`placeholder-by-position` invariants both bear on this increment and are
satisfiable as written.

## Recommendations

1. **Treat "matched the filter" and "counts as work" as two sets.** Options:
   a second array populated alongside `matching`; or a per-accumulator guard.
   The first is one declaration and reads honestly at the blocking loop; the
   second repeats a condition at six sites, which is the shape the
   `declared-vocabularies` invariant exists to prevent.
2. **Add the join/leave argument shape before the verb.** `transition.sh` has
   no second-positional infrastructure, so that is the real work; the case arm
   is trivial.
3. **Reconcile the `PLACE_VERBS` face rather than only extending the array.**
   Two groups declare a dependency on the placement door.
4. **Measure the index cost with a fixture before settling the roster
   question.**

## Peer Feedback

**For the PM — two Handoff insights are factually wrong and should be
rewritten before approval.** Both describe pre-remediation code.

- **Insight 1** states that two graph readers "still carry their own narrower
  pattern" and recommends migrating them first. They were migrated during the
  014 remediation. No narrow `[a-z0-9-]` pattern remains anywhere in
  `render.sh`; the lines `#381` names now hold unrelated code; all five graph
  reads go through `read_graph_edges`. **`#381` is already fixed and should be
  verified and closed**, not sequenced ahead of this increment. The corrected
  point is stronger: a uniform seam exists at five sites, and the risk is
  adding a sixth that bypasses it.
- **Insight 2** states that new emitter flags widen argv into the placement
  wrapper and reopen the `#386` blast radius. They do not. `new.sh:175-176`
  appends the markers **last** and declares their positions as negative
  offsets (`--dir-at -3 --token-at -1`), with the comment at `:172-174` stating
  that forwarded argv ahead of them is never examined. New flags land in
  `original_argv`, ahead of the markers, so the offsets are unaffected. The
  inference-by-adjacency mechanism that caused `#386` is gone; the invariant
  records the fix, not a live hazard.

Both errors have one shape: a mechanism described from an issue record and a
retrospective written before the fix, rather than from the current code. That
is the failure mode the retrospective names as travelling furthest, reproduced
inside the spec that cites it.
