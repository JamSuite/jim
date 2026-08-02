---
id: 20260802-single-source-the-ordinal-width-bound-across-jimalloc-and-jimfil
num: 212
title: "Single-source the ordinal width bound across jimalloc, jimfile and jimledger"
status: open
priority: medium
labels: [id-coordination, sync-discipline]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T20:57:29Z
updated: 2026-08-02T22:42:56Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission/plan.md
---

## Description

The ordinal width bound is decided in **three** places, in three different
spellings, agreeing only by convention. No test asserts any two of them agree.

| Site | Spelling | Bound |
| :--- | :--- | :--- |
| `jimalloc.sh:738` | named constant `ALLOC_MAX_ORD_DIGITS=15` | upper only |
| `jimfile.sh:371, 584, 900` | inline regex `{3,15}` (path / rename / occupancy) | 3–15 |
| `jimledger.sh:689` | awk `length(s) >= 3 && length(s) <= 15` in `isord` | 3–15 |

`ARCHITECTURE.md` already names this as the one place in the ordinal machinery
where a divergence would not be caught structurally.

**The third site is not merely a third copy — it disagrees.** The registry has
no *lower* bound at all: `alloc_valid_specid` is `^[0-9]+$` and
`alloc_canon_specid` prints `%03d`, so `old/01` and `old/7` are ordinals the
registry represents perfectly well. `jimledger.sh:689` floors at three digits,
so the lift silently drops any pair naming one. The direction is fail-closed
(it drops rather than admits), and the 3-digit floor does match the *tree*
path shape — but it means the ledger parser and the registry do not accept the
same set, which is the property the emission work set out to guarantee. Whether
to lower the parser's floor or record the tree-shape bound deliberately is the
open question.

Three things make this worth closing rather than leaving as a documented wart:

1. **The bound became load-bearing.** Before per-side canonicalization, an
   ordinal that failed the width gate dropped its whole rename record — the two
   sides shared one fate, so a disagreement between the files was mostly a
   question of which malformed record got skipped. Now the bound decides, per
   side, whether a destination's establishing claim survives. A `jimfile.sh`
   that admitted a width `jimalloc.sh` rejects would let a directory exist on an
   ordinal the registry treats as unrepresentable — registry-vs-tree drift the
   sweep would report but neither file would have prevented.

2. **A copy already diverged before anyone noticed.** The lower-bound
   disagreement above shipped without being caught, in the same build that made
   the upper bound load-bearing per side. That is the failure mode this issue
   predicts, already realized once.

3. **The mechanism exists and is proven.** The provisional-identity grammar had
   the same shape — three hand-synced copies that had already drifted — and it
   was closed with byte-identical bodies under a `SYNC:` comment plus a
   `tests/jimfile.sh` case asserting the copies agree, following the earlier
   `is_valid_id` precedent. The same discipline applies directly here, and that
   fixture is the model for the one below.

## Proposed action

Decide the bound's shape first — is the 3-digit floor part of the rule, or only
of the tree's path shape? The registry and the ledger parser currently answer
differently, so a single source has to settle it rather than encode both.

Then either extract the bound so every site reads one value, or — where a regex
or awk literal is genuinely needed inside a gate — assert agreement
mechanically: a test that reads the constant from `jimalloc.sh` and the width
from each `jimfile.sh` predicate and from `jimledger.sh`'s `isord`, failing when
they diverge. Extraction is preferable where it costs no subprocess on a hot
path; the fixture is the fallback that at least makes a divergence loud. Note
the three spellings differ in kind (shell constant, shell regex, awk
comparison), so a byte-identity fixture like the provisional grammar's will not
transfer directly — this one has to compare extracted *values*, not bodies.

Surfaced during the rename/redirect record emission build, which touched every
reader of that bound and added the third site, but deliberately left this seam
alone as out of scope. The post-build review recorded the lower-bound
divergence as a partial satisfaction of that spec's width-agreement criterion.
