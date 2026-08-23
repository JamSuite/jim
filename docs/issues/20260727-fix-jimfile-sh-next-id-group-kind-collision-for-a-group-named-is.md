---
id: 20260727-fix-jimfile-sh-next-id-group-kind-collision-for-a-group-named-is
num: 123
title: "Fix jimfile.sh next-id group/kind collision for a group named issue"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [platform, id-coordination, partition]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-27T07:20:53Z
updated: 2026-08-03T05:46:40Z
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

## Narrowed, not closed (2026-07-31)

`sdlc/017` retired the `/jim:spec` caller — spec creation binds through
`jimalloc.sh allocate spec`, whose group is positional *after* the `spec` kind
and therefore unambiguous. That removes the encounter described above, and this
issue was provisionally dispositioned "moot" on that basis. It is not moot.

**`jimfile.sh next-id` kept its `/jim:partition` caller, and jim's own repo is
the collision case.** Verified today:

```
$ bash skills/file/scripts/jimfile.sh next-id issue
error: 'next-id issue' requires <subject>        ← wanted: 011
$ bash skills/file/scripts/jimfile.sh next-id sdlc
018
```

`docs/specs/issue/` holds 000–010, so the `issue` spec group cannot be asked for
its next ordinal at all. `/jim:partition merge … into issue` passes
`jimfile.sh next-id <target>` stdout **verbatim** as `merge-map`'s `<start>`
(`jimpartition.sh:1409`), so the collision reaches a live consumer. It fails
loudly rather than mis-assigning an ordinal, which is why it has stayed
invisible — and why the failure would surface first as a confusing merge error
rather than as this bug.

Narrower than filed: one caller instead of two, and jim has not yet merged into
`issue`. Still real, and it now sits with the partition surface rather than with
the spec surface. The fixes named above stand; an explicit `next-id spec <group>`
form is cleanest, since it makes the kind always explicit rather than inferring
it from a name a spec group may legitimately hold.

## Resolution (2026-08-03)

Dead structurally, not patched. `blueprint/025` retired the tree-scan
spec-ordinal path: `jimfile.sh next-id` answers for issues only and refuses a
group argument outright, so a kind can no longer be inferred from a name that a
spec group may legitimately hold. The explicit `next-id spec <group>` form this
issue recommended is moot — there is no spec arm to disambiguate.

The live consumer converged rather than being taught the collision.
`/jim:partition merge` now takes `<start>` from `jimalloc.sh peek spec <target>`
(`skills/partition/SKILL.md:426`), which is group-explicit by construction.

Two stale references survive in prose only, neither reachable as behavior:
`jimpartition.sh:1461`'s `merge-map` docstring and `skills/partition/SKILL.md:366`.
Both are enumerated in [[20260802-retire-the-stale-documentation-the-emission-build-left-behind]].
