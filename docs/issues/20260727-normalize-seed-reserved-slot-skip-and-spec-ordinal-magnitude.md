---
id: 20260727-normalize-seed-reserved-slot-skip-and-spec-ordinal-magnitude
num: 121
title: "Normalize seed reserved-slot skip and spec-ordinal magnitude"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, alloc, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-27T05:34:21Z
updated: 2026-08-02T01:07:02Z
origin: docs/specs/platform/008-registry-seed/review.md
---

## Description

## Description

Surfaced by the `platform/008` post-build review (review.md Finding 1; a
judge-confirmed `blueprint-slot-reserved` living-intent violation, in-change).

`alloc_seed_derive_specs` (`skills/file/scripts/jimalloc.sh`) recognizes the
reserved slot with a literal string test `[[ "$ord" == "000" ]]` (:373) and
bounds the spec ordinal with a value-only `(( 10#$ord > 999 ))` (:380), with no
digit-length cap. Two bounded consequences:

- A directory whose ordinal parses to `0` but is not literally `000` (`0-foo`,
  `00-foo`) bypasses the skip and emits `spec allocate <group>/000 …`, occupying
  the reserved coordinate — a breach of "emits no record for the reserved slot."
- A pathological ≥19-digit ordinal could overflow `intmax_t` and wrap past the
  `>999` guard.

Neither reissues a consumed id (id 0 never raises the next-id high-water; a
wrapped ordinal is rejected by the read-side `alloc_valid_specid` on replay) and
neither injects (the value is log content, never a git argument). The issue-num
path already does this correctly with a `${#num} > 15` length cap (:427).

## Half resolved (verified 2026-07-30)

`platform/011` (rename-path correctness) closed the **magnitude** half. The
reserved-slot half is untouched and this issue stays open for it.

**Closed — the spec-ordinal magnitude cap.** The value-only `(( 10#$ord > 999 ))`
guard is replaced by a digit-length check against a shared
`ALLOC_MAX_ORD_DIGITS` constant that the read-path folds consult too, so the
allocator and the bootstrap decide legality from one value. That was not
cosmetic: `platform/011` needed the allocator to stop minting four-digit ordinals
the bootstrap refused, and capping allocation to match the arbitrary 999 instead
would have let one crafted record at the ceiling deny a group forever. Relaxing
the guard upward was the resolution.

The overflow consequence is gone with it — a 19-digit ordinal is now rejected as
malformed rather than wrapping `intmax_t` past the guard:

```
core/1234567890123456789-x
→ error: cannot seed — spec dir has an invalid ordinal
```

**Still open — the reserved-slot skip.** The literal string test is unchanged, so
a directory whose ordinal parses to `0` without being literally `000` still
occupies the reserved coordinate:

```
core/0-foo, core/001-ok
→ spec allocate core/000 foo …      ← the breach
   spec allocate core/001 ok …
```

A side effect worth noting: with *two* such directories (`0-foo` and `00-bar`)
the seed now halts on `duplicate spec ordinal: core/000` rather than emitting
either. So the breach surfaces only for a lone non-canonical zero directory —
narrower than originally described, and still a breach of "emits no record for the
reserved slot."

## Remaining fix

- Normalize the reserved-slot skip to `(( 10#$ord == 0 ))`.
- Add fixtures for `0-foo` / `00-foo`.

The digit-length cap and its over-long-ordinal fixture are done
(`case_jimalloc_fold_max_spec_seed_refuses_over_wide`).

## Remaining half rides Spec E (2026-08-01)

Folded into the registry-integrity spec
(`docs/specs/platform/012-registry-integrity-and-drift/spec.md`, AC 16) and
out of the hardening bucket. The coherence argument that moved it: that
spec's sweep classifies a `<group>/000` record as drift, and its catch-up
verb reuses this very derivation — detect and derive must agree on the
reserved-slot rule, or the pipeline flags records its own sibling verb can
still produce.

## Resolution (2026-08-02)

Both halves are now closed. The magnitude half shipped with `platform/011` (the
`999` value cap became a shared digit-length check). The reserved-slot half
shipped with `platform/012`: `alloc_is_reserved_ord` replaces the literal
`"000"` test with a digits-guarded numeric one, so `0-`, `00-` and `000-` name
the same reserved dir at every width and no derivation can mint the
`<group>/000` record the sweep classifies as drift.

The predicate is genuinely shared rather than duplicated — the derivation skips
by it, the sweep's reserved-slot counter counts by it, and the classifier's
reserved-slot row is decided by it — so the report and the derivation cannot
disagree about which directories are reserved.

The ordering this issue flagged is preserved and now asserted: the skip runs
ahead of the no-slug and ordinal-class checks, so a slugless bare `000` still
skips rather than raising a conflict.
