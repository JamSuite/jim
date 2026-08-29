---
id: 20260826-spec-prefix-matching-has-no-directory-boundary
num: 394
title: "Spec prefix matching has no directory boundary"
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
created: 2026-08-26T02:35:23Z
updated: 2026-08-27T10:35:11Z
origin: "docs/specs/issue/014-read-view-filter-composition/review.md"
---

## Description

## What

`prefix_axis` composes `<root>/<value>` and tests the origin against it with a
bare `[[ "$origin" == "$pfx"* ]]` — nothing requires the byte after the matched
prefix to be a separator. The compare runs over the **whole** composed string,
so both segments of a `--spec` operand match loosely: the group name and, when
one is given, the ordinal.

Those two halves have very different exposure, and only one of them is covered
by anything.

## The group segment — reachable, and it answers wrongly

Group names are free-form. Nothing constrains one from being a prefix of
another, so `--spec <group>` reaches every group whose name it prefixes:

```
origins:  docs/specs/issue/011-issue-placement/spec.md      (A)
          docs/specs/issues/011-something-else/spec.md      (B)
          docs/specs/issue-archive/011-x/spec.md            (C)

$ render.sh list --spec issue          →  A, B and C   (rc 0)
$ render.sh list --spec issue/011      →  A            (rc 0, correct)
```

The operator typed a narrowing filter and received a widening one, silently, at
status 0 — a *wrong* answer rather than a missing one, and the same failure
class as the empty-operand defect this increment already fixed.

## The ordinal segment — not reachable, and the reason holds

Two invariants make the sibling-ordinal collision impossible, and both were
re-checked rather than taken on trust:

1. The allocator refuses a duplicate spec ordinal within a group, so two spec
   directories can never share one.
2. Ordinals are formatted `%03d` — a *minimum*-width format. `printf '%03d'`
   gives `007`, `011`, `110`, `999`, `1000`, `1001`: values 0–999 print as
   exactly three digits and values ≥1000 are never zero-padded, so a
   three-digit ordinal is never a literal prefix of a longer one.

So `--spec issue/011` cannot reach `issue/0110-…`, because no ordinal prints as
`0110`. Both invariants live in `jimalloc.sh` and neither is referenced where
the comparison happens — a collection accumulating origins captured by hand
rather than through the allocator, or a group whose padding convention changes,
loses the guarantee silently.

## Where it bites

Not here: this project's groups are `blueprint`, `issue`, `jim`, `platform` and
`sdlc`, and none is a prefix of another. It bites a consumer project, which
chooses its own group names and can rename, split and merge them through
`/jim:partition`. `api` beside `api-v2`, `core` beside `core-utils`, `spec`
beside `specs` — ordinary naming, and the read view then answers for both.

## Why the obvious boundary check does not work

Requiring the byte after the prefix to be `/`, `-`, or end-of-string does not
close this. `-` **has** to be admitted for the ordinal case — `--spec
issue/011` must reach `011-issue-placement` — and admitting `-` is exactly what
lets `--spec issue` reach `issue-archive`. The boundary set cannot be uniform
across the operand, because the two segments end differently:

- after the **group** segment, only `/` or end-of-string;
- after the **ordinal** segment, `-`, `/`, or end-of-string.

Which means the fix is not one character class applied to a composed string. It
is a comparison that knows where the group ends — i.e. `--spec` parsing its
operand into its two parts rather than pasting it onto a root.

## Fix shape

Split the `--spec` operand at its first `/` and compare segment-wise: the group
must match a whole path segment; the ordinal, when given, must match up to a
`-`, a `/`, or the end. The acceptance criterion is preserved — naming a
group and ordinal still reaches the spec without naming the rest of its
directory — while both collisions close.

Scope it to `--spec`, not to `prefix_axis`. The `--origin` axis shares the
compare, and there the loose match is the stated intent: an origin match is
documented as a path prefix, so `--origin docs/specs/issue` reaching
`docs/specs/issues/…` is that axis working as specified.

State the two allocator invariants at the comparison either way. They stop
being load-bearing for the ordinal once it is bounded, but the origin-format
coupling they represent is still undeclared where it is relied on.

## Note on this record

Filed describing the ordinal collision only, priced as a latent dependency to
state rather than a defect. Running it corrected that: the ordinal analysis is
right and the collision it describes really is unreachable, but the same
unbounded compare applies to the group segment, where no allocator invariant
exists — and the boundary check originally proposed here would not have closed
it. Re-scoped and re-priced accordingly.

## Resolution

Fixed in `a01c038`, taking the second of the two shapes above — the boundary
rather than the stated coupling — because the group segment made it a defect
rather than a latent dependency.

**Both collisions close, and the criterion is untouched.** The operand is split
at its first `/`: the group must match a whole path segment, and only what
follows it may end at a `-`, a `/`, or the end of the string. `--spec issue`
reaches its own group and neither `issues` nor `issue-archive`; `--spec
issue/011` still reaches `011-issue-placement` without spelling the rest of the
directory, which is the whole reason the match was loose. Siblings stay
reachable by their own names.

**One character class over the composed path could not have done it**, which is
what the Description records and the fix bears out. `-` has to be admitted for
the ordinal to reach the directory carrying it, and admitting `-` is exactly
what lets a group reach a hyphenated sibling. The two halves end differently,
so they are compared separately rather than pasted together.

**A behaviour change worth stating:** `--spec iss` now matches nothing, where
before it reached every group beginning `iss`. A partial group name was never a
group, and the criterion promises a group and an ordinal — but an operator who
had been relying on the loose reading will see a query narrow.

**Pinned by** `case_issues_render_list_spec_group_is_a_whole_segment`, which
asserts the boundary in both directions — the sibling groups excluded, each
still reachable by its own name — that the ordinal case survives, that the
census reports a scope it actually has, and that `--origin` stays unbounded.
The case failed on exactly three assertions before the fix and none after; the
ordinal and `--origin` assertions passed throughout, which is what shows the
fix preserved them rather than happening to satisfy them.

**Checked past what the case asserts**, because a green test covers only what
it names: a trailing slash (`issue/`), a full directory name, an operand
reaching a file, comma-separated alternatives, a glob metacharacter (still
literal, still matching nothing), and `issue/0110` — the sibling-ordinal
collision this record originally described, which is now closed too even though
the allocator already made it unreachable.

**`prefix_axis` lost its root parameter.** `--origin` is its only caller and
always passed an empty one, so the parameter was a knob no caller turned. The
loose compare stays there deliberately: an origin match is specified as a path
prefix, so reaching partway into a segment is that axis working as written.

**Blast radius: none here.** This project's groups are `blueprint`, `issue`,
`jim`, `platform` and `sdlc`, no one a prefix of another, so no query over this
collection changes answer. It moves a consumer project that names its own
groups — and `/jim:partition` splitting a group while keeping the parent's name
for one child produces exactly the colliding shape.
