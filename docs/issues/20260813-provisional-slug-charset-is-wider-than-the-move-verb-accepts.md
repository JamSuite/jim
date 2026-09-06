---
id: 20260813-provisional-slug-charset-is-wider-than-the-move-verb-accepts
num: 348
title: "Provisional slug charset is wider than the move verb accepts"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [platform, allocator, grammar]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-13T10:59:41Z
updated: 2026-08-13T10:59:41Z
origin: "20260804-b-prime-completion-handoff.md (retired; see 5e712bf)"
---

## Description

## Description

`is_prov_token` accepts provisional tokens whose slug the ledger's move verb will
not accept, so a spec wearing one could be realized nowhere.

`is_prov_token` (`skills/file/scripts/jimalloc.sh:272`) carries both the
post-prefix body and the slug alone through `prov_id_boundary`, which is the id
boundary — `^[A-Za-z0-9][A-Za-z0-9._-]*$` (`skills/file/scripts/jimfile.sh:207`).
Uppercase and `.` are admitted deliberately; the boundary's own header says so.

`move-spec-dir`'s source shape (`skills/ledger/scripts/jimledger.sh:597`) is
narrower for the same token:

    ^([0-9]{3,15}(-[a-z0-9][a-z0-9-]*|-wip)|P-[0-9]{8}-[a-z0-9][a-z0-9-]*)$

Lowercase only, no dot, no underscore.

Demonstrated:

    $ jimfile.sh valid-id "P-20260801-Foo.bar"        # accepted
    $ printf '%s' "P-20260801-Foo.bar" | grep -E "$src_shape"   # no match

A directory named `P-20260801-Foo.bar` is therefore a well-formed provisional
identity by the allocator's own boundary and unmovable by the verb that realizes
it.

**Latent, not live.** The minting path composes the slug from a normalized
title, so it cannot produce one today — nothing legitimate is stranded. The
asymmetry is the defect: two validators for one grammar, disagreeing, with
nothing asserting they agree.

## Action

Decide which boundary is authoritative for a provisional ordinal slot and make
the other derive from it, rather than restating a charset. The three-copy
`is_prov_token` body already has a byte-identical test; the gap is that the
*consumer* on the ledger side was never brought into that arrangement.

Note this is not the same defect as the single-source issues for the provisional
grammar or the per-constant pinning issue — both concern duplicated validator
bodies. This one is a producer/consumer disagreement between two grammars that
were never intended to differ.
