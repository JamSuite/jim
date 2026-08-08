---
id: 20260808-local-tier-retry-reopens-a-compare-and-swap-clobber-window
num: P-20260808-local-tier-retry-reopens-a-compare-and-swap-clobber-window
title: "Local-tier retry reopens a compare-and-swap clobber window"
status: open
priority: medium
labels: [issue, placement, concurrency]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-08T18:39:30Z
updated: 2026-08-08T18:39:30Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

The local-tier retry loop reads the tip and the compare-and-swap old value as two
separate `git rev-parse` invocations, **tip first**, reopening a clobber window
that the file's own initial capture sites and the `jimalloc.sh` precedent both
avoid.

## Mechanism

`skills/issue/scripts/place.sh:1286-1287` (and identically at `:1282-1283` on the
origin→local degradation path):

```bash
tip="$(place_local_tip "$dest")"
ref_old="$(place_head_tip "$dest")"
```

Interleaving:

1. `:1286` reads `tip` → `B`.
2. A racer lands `C` (parent `B`) via its own `update-ref`.
3. `:1287` reads `ref_old` → `C`.
4. `place_regraft` runs against tip `B`, so `upstream` is B's collection and
   C's file is not in it — no conflict is detected.
5. `place_build_commit B` produces `D`, parent `B`.
6. `place_land` runs `git update-ref refs/heads/<dest> D C`. The ref *is* `C`,
   so **the swap succeeds** — `update-ref` has no fast-forward check, unlike
   push.
7. rc 0. `C`'s mutation is gone, silently.

## Why it matters more than the window size suggests

The window is one process spawn, but the retry path is entered **only under
active contention** — which is exactly when a racer is running.

Both *initial* capture sites are correctly ordered: `:1168` (`cmd_run`) and
`:627` (`cmd_begin`) read the ref before resolving the tip, which makes the CAS
conservative — a spurious rc 3 costs a retry, and the retry regrafts.
`jimalloc.sh:2208` avoids the split entirely by reading the ref once and using
that value as both the content source and the CAS old value.

## Proposed action

Swap the two lines at both sites so `ref_old` is read first. Then either
`ref_old` is stale relative to `tip` (the swap fails, the loop retries — safe) or
they agree.

## Test

`tests/place.sh:972` covers the local-tier retry but cannot catch this: the
racer completes entirely inside the wrapped command, so both reads happen after
it. A case that interleaves between the two reads is hard to write
deterministically; asserting the read order structurally, or reading the ref
once and deriving the tip from it, may be the more testable fix.
