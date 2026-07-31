---
id: 20260731-skip-symlinked-entries-in-the-realized-directory-sweep
num: 180
title: "Skip symlinked entries in the realized directory sweep"
status: open
priority: medium
labels: [spec, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-31T12:39:17Z
updated: 2026-07-31T12:39:17Z
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
