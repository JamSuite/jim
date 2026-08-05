---
id: 20260802-single-source-the-ordinal-width-bound-across-jimalloc-and-jimfil
num: 212
title: "Single-source the ordinal width bound across jimalloc, jimfile and jimledger"
status: closed
priority: medium
labels: [id-coordination, sync-discipline]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-02T20:57:29Z
updated: 2026-08-05T02:25:13Z
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

## Scope re-derived (2026-08-03) — nine sites, three disagreeing sets

The table above says three sites. That count was inherited, not measured, and it
is wrong in both directions: it omits four deciding sites, and it describes the
disagreement as narrower than it is. Re-derived by a `/jim:verify` judge over the
platform territory, then confirmed against the files.

| Accepted set | Sites |
| :--- | :--- |
| 1–15 digits | `jimalloc.sh:741` (`ALLOC_MAX_ORD_DIGITS`, the one named constant) · `jimfile.sh:403` (occupancy-predicate argument) · `jimfile.sh:415` (sibling leading token) |
| 3–15 digits | `jimfile.sh:371` (`is_spec_dir_basename`) · `jimfile.sh:584` (`mv-spec-id` new-id) · `jimfile.sh:900` (`path spec\|plan\|research` id) · `jimledger.sh:691` (awk `isord`) |
| exactly 3 | `jimledger.sh:586` (`move-spec-dir` `src_shape`) · `jimledger.sh:587` (`move-spec-dir` `dst_shape`) |

One named constant, **eight** inlined literals, **three** mutually incompatible
accepted sets. The registry itself has no lower bound at all
(`alloc_valid_specid` is `^[0-9]+$`, printed `%03d`).

**A functional consequence nothing records.** `alloc_next_id_spec` mints a
4-digit ordinal once a group passes 999, and `jimfile.sh:371/584/900` accept it —
but `move-spec-dir`'s gates are `exactly 3` on **both** sides, so the move
primitive cannot move such a spec at all. A group that crosses 999 can allocate
specs it can never renumber, rename, or realize across parents. That is not a
tidiness problem; it is a reachable dead end.

**Nothing mechanical would catch a further divergence.** `tests/` contains no
reference to `ALLOC_MAX_ORD_DIGITS`; the SYNC fixtures cover `is_valid_id`,
`is_prov_token` and the timestamp shape only; `tests/scripthygiene.sh` has no
width check. Whatever shape the fix takes, it needs a fixture asserting the
sites agree — the same discipline the provisional grammar got.

## Provenance of this correction

Filed by the emission build, which counted the sites it happened to touch. A
later session re-derived a sibling issue's scope from scratch and, in the same
pass, repeated this issue's count without deriving it — the exact failure the
cluster note's practice 7 describes (*a finding's stated scope is a claim, not a
measurement; never inherit the reporter's grep*). The count above is measured.

## The blueprint was weakened to match this defect — closing must reverse that

On 2026-08-03 the `platform` blueprint's `ordinal-single-source` invariant was
**deliberately weakened** so it would stop asserting something the code does not
do. That fold is a waypoint, not a destination: it makes the blueprint honest
about today, and it must not become the permanent statement of intent.

**Closing this issue is not complete until the invariant is restored to at least
its pre-fold strength through `/jim:blueprint`** — never by hand. The fix
single-sources the bound; the invariant should then be able to claim it again,
and more strongly than before, because the restored claim can rest on a fixture
rather than on convention.

The pre-fold text, recorded verbatim so the restoration target needs no
archaeology:

> Ordinal computation, legality, and occupancy each resolve to one definition:
> the next-ordinal high-water is one shared fold per kind that every allocation,
> preview, and reconcile path reads; ordinal legality is one named constant the
> allocator, the registry bootstrap, and `resolve` all read, while the tree-side
> path/rename predicates hold the same bound as inlined literals — agreement by
> convention, not by construction, and the one seam here where a divergence
> would not be caught structurally; and occupancy is one numeric predicate,
> exposed as a verb so the realize and partition-move paths consult the
> definition itself rather than a copy

Note what the restored text should *drop*: "agreement by convention, not by
construction" and "the one seam where a divergence would not be caught
structurally" were true confessions when written. Once a fixture asserts the
sites agree, both clauses become false in the good direction and the invariant
should say so — construction, not convention.

Two clauses of the current folded text must also disappear on close: the
eight-inlined-literals / three-accepted-widths admission, and the
tree-derived `next-num` carve-out on the issue kind if that is folded in too.

## Resolution (2026-08-05)

The bound's shape was settled rather than encoded twice: ordinal legality is one
predicate, `alloc_valid_ord`, around one named constant. Seven inline
comparisons folded in; the constant is compared in exactly one function and the
allocator spells no width literal of its own (both counts re-measured). The tree
and ledger sides carry the bound as two documented rules sharing that ceiling —
the canonical `{3,15}` spelling and the numeric `{1,15}` acceptance, the latter
confirmed load-bearing rather than drift: a `{3,15}` occupancy gate would read
`18-foo` as free space and land a second directory on ordinal 18.
`move-spec-dir`'s exactly-3 gates are widened and a 4-digit spec now moves
cross-parent end to end. The cross-file fixture extracts each site's value and
binds it to the constant, proven genuinely value-binding by mutating the
constant alone and watching four assertions fail.

Scope correction, third in this cluster: the count is **eleven runtime gates
across four files**, not the nine this issue recorded or the ten the handoff
revised it to — plus six more in `jimpartition.sh` that no count has included.

Residual, tracked separately: the tree-wide guard excludes by basename (so
`skills/issue/scripts/reconcile.sh` is silently exempt) and matches only
comma-form ranges, missing exactly-N literals, awk `length()` and `${#x}`
comparisons; it also never scans `tests/` or repo-root `scripts/`. And the
partition layer's own gates did not follow the widening, which is where the
`>999` dead end still lives.
