---
id: 20260727-fix-jimfile-sh-next-id-group-kind-collision-for-a-group-named-is
num: 123
title: "Fix jimfile.sh next-id group/kind collision for a group named issue"
status: open
priority: medium
labels: [platform, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-27T07:20:53Z
updated: 2026-07-27T07:20:53Z
origin: docs/specs/platform/009-provisional-reconcile/spec.md
---

## Description

`jimfile.sh cmd_next_id` dispatches on its first argument: `issue` is treated as
the issue *kind* (returns a date-prefixed slug via `next-id issue <subject>`);
every other value is treated as a spec *group* name (returns the next `NNN`).
Because the `issue` spec group's name collides with the `issue` kind keyword,
`jimfile.sh next-id issue` cannot return the next spec ordinal for the `issue`
group — it falls into the kind branch and errors on the missing subject (or,
with a subject, returns a date-slug rather than an ordinal).

Impact: `/jim:spec`'s ledger-open step (`jimfile.sh next-id <group>`) misfires
for the `issue` group. Encountered while opening the ledger for `issue/010` (the
#111 wire) — had to compute the ordinal by hand.

Scope note: the coordinated `jimalloc.sh allocate spec <group> <subject>` path
(issue #112) takes the group positionally after the `spec` kind, so it is
unambiguous; this bug is confined to the legacy `jimfile.sh next-id` path and
persists until that path is retired or the spec consumer is wired onto the
allocator.

Possible fixes: disambiguate kind vs. group (e.g. an explicit `next-id spec
<group>` form, or a `--group` flag), or reserve/reject spec-group names that
collide with a kind keyword.
