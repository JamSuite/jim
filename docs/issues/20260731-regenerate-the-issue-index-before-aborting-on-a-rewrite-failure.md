---
id: 20260731-regenerate-the-issue-index-before-aborting-on-a-rewrite-failure
num: 174
title: "Regenerate the issue index before aborting on a rewrite failure"
status: closed
priority: high
labels: [issue, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:38:33Z
updated: 2026-07-31T20:41:03Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

`rewrite_num` now exits non-zero when it replaces nothing. The issue realizer
handles that with `return 1` (`skills/issue/scripts/reconcile.sh:182-186`), which
aborts `apply_pending` and returns before the `index.sh` call at `:229` — even
though earlier files in the batch were already rewritten atomically.

Result: realized ordinals on disk, stale `INDEX.md`, no regeneration attempted.
That is the failure mode the regen-exit-status fix exists to prevent, now
reachable through the door the verified-rewrite change opened.

## Related asymmetry

The spec realizer handles the same non-zero rc differently
(`skills/spec/scripts/reconcile.sh:278-284`: `failed=1; continue`), which leaves a
different residue — the directory is already renamed at that point, so the
identity is omitted from `applied` and therefore from the remap: moved directory,
still-provisional frontmatter, un-swept citations, no ledger row, rc 1.

The two scripts are documented as mirrors and should agree on this path.

## Fix

Regenerate the index before returning on the failure path (or accumulate the
failure and regenerate once at the end, matching the spec side's batch
semantics), and reconcile the two scripts' handling of the rc.

Finding 4 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.

## Resolution (2026-07-31)

Closed by the C′-fix build. Both halves of the fix landed, and the two scripts
now agree.

**Issue side — accumulate and continue.** `apply_pending` reports each failing
file and carries on; the caller takes its rc instead of returning on it, so the
index is regenerated for the files that *did* rewrite. Every ordinal in the
mapping is already durably published, so abandoning the batch stranded more work
than it saved. The `mktemp` failure path got the same treatment.

**Spec side — the asymmetry closed in the other direction.** The residue this
issue describes was real and is fixed rather than matched: past the rename the
directory has moved, so the `REALIZED` line is now emitted whatever the
frontmatter rewrite does. That line is what puts the identity into the remap, and
the remap is what sweeps the citations the move just made dead and writes the
ledger row. Dropping it left a moved directory that nothing pointed at and
nothing recorded. The run still fails and the message now names the frontmatter
as what to repair.

**On the fixtures.** The per-file rewrite failure is unreachable through either
command surface — the bounded scan and the bounded rewrite match the same set of
inputs, which is exactly why it shipped unfixtured. Both realizers are therefore
driven directly, the way pure functions are tested elsewhere in this suite, and
the caller's non-abort is pinned by shadowing the realizer with one that reports
both a realized file and a failure. That is the guard-wiring discipline this
build was set up to apply: the function alone was never the part in doubt.

This also lands the first of the three items in
[[20260731-write-the-fixtures-the-plan-named-but-the-build-skipped]] — the
"forced no-op rewrite fails loudly" fixture, against both realizers.
