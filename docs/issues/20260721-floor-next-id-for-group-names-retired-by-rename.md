---
id: 20260721-floor-next-id-for-group-names-retired-by-rename
num: 84
title: "Floor next-id for group names retired by rename"
status: open
priority: medium
labels: [partition, rename, ledger]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-21T18:50:19Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/019-partition-split/spec.md
---

## Description

Spec 047's vacated-id floor (`jimledger.sh vacated-max` consumed by
`jimfile.sh next-id`) derives floors from `op=split` events' `moved=` remap
entries — which also covers re-minting a group name retired by a *symmetric
split*. But a group retired by **rename** (spec 043) has no remap: the
`op=rename` ledger event records `old=`/`new=` and no id information, so
re-minting the old name later restarts numbering at `001` and re-mints ids
the ledger bridge already maps (historical `cart/001` = today's
`checkout/001` after `cart → checkout`) — the same two-referents ambiguity
spec 047 AC 11 closes for split, surviving on the rename path.

Surfaced by the 047 dual-lens security review (Finding 11). Unfixable from
split's data — the floor needs id information the rename event does not
carry.

**Proposed action:** extend the `op=rename` finished event to record the
renamed group's max spec id at rename time (e.g. a bounded `maxid=<NNN>`
key, display-data-shaped but consumable by `vacated-max`), and teach
`vacated-max` an `op=rename` arm keyed on `old=` + `maxid=`. Until then the
ambiguity is bridged only by event timestamps.

Relates to spec 047 (`docs/specs/blueprint/019-partition-split/`) AC 11 and the
043 `op=rename` event shape.
