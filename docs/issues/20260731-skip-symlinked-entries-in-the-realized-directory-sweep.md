---
id: 20260731-skip-symlinked-entries-in-the-realized-directory-sweep
num: 180
title: "Skip symlinked entries in the realized directory sweep"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [spec, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T12:39:17Z
updated: 2026-07-31T20:28:56Z
origin: docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md
---

## Description

## Description

The realized-directory sweep applies two of the three guards from the
`rewrite-identity` precedent it cites — worktree containment and relpath shape —
but not tracked-ness, which it must drop to do its job at all (the directory is
untracked by definition).

`[[ -f "$entry" ]]` (`skills/spec/scripts/reconcile.sh:372`) follows symlinks, so a
symlink inside a realized directory pointing at an in-worktree file is appended.
It passes `realpath -m` containment, and `>` writes *through* the link to its
target.

## Assessment

Containment itself holds — an escape out of the worktree is refused and fixtured.
What the symlink defeats is the four-content-roots **scoping**: a link can reach
`.github/`, `flake.nix`, `pre-commit.sh` and similar, which `git ls-files --
"${roots[@]}"` would never enumerate.

Exposure is narrow: the target must contain a whole-token, unfenced
`<group>/P-<8digits>-<slug>` occurrence to be written at all, the substitution is
a fixed token-to-ordinal swap with no attacker-chosen content, and each rewrite is
reported on stdout. An attacker who could plant the token in the victim file could
already edit it directly.

A related lower-severity item in the same guard: `:563`'s `realpath` result is
unchecked, unlike `:555`'s. If it ever returned empty the containment comparison
would pass vacuously — the one guard here whose failure mode is *pass* rather than
refuse.

## Fix

`[[ -L "$entry" ]] && continue` at the enumeration costs nothing — a symlink is
never a spec's own body — and restores the scoping bound. Add the emptiness check
at `:563`.

Finding 10 of `docs/specs/sdlc/018-finish-coordinated-spec-identity/review.md`.

## Resolution (2026-07-31)

Closed by the C′-fix build, but **not** as the bare `[[ -L "$entry" ]] && continue`
this issue proposed — that would have silently downgraded a fixtured security
property.

An existing fixture asserts that a symlink escaping the worktree makes the sweep
**refuse loudly at rc 1** with nothing written. A blanket skip turns that refusal
into silence: the escape is still not written through, but the run no longer says
anything about it. The two concerns are distinct and both are wanted —

- **scoping**, which is this issue: a symlink is never a spec's own body, so it
  is not swept, and the four-content-roots bound is restored;
- **containment**, which the security review verified: a link out of the worktree
  inside a spec directory is anomalous, and the run stops.

So the enumeration resolves each symlink it meets: inside the worktree it is
skipped, outside it is refused — before any temp state exists, preserving the
"both refusal arms return with zero files written and the temp directory not yet
created" property. Fixtured on both sides; the pre-existing escape fixture still
passes unmodified.

**The related lower item is already closed.** The unchecked `realpath` this issue
names sits in the `--apply` guard, not in the sweep, and the worktree-top refusal
built for
[[20260731-make-spec-reconcile-apply-work-from-a-subdirectory]] now refuses
explicitly on an empty result rather than comparing against it.
