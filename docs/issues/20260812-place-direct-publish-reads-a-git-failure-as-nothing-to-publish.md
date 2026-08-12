---
id: 20260812-place-direct-publish-reads-a-git-failure-as-nothing-to-publish
num: P-20260812-place-direct-publish-reads-a-git-failure-as-nothing-to-publish
title: "place_direct_publish reads a git failure as nothing to publish"
status: open
priority: critical
labels: [issue, placement, fail-open]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:21Z
updated: 2026-08-12T21:53:21Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

`place_direct_publish` reads `git status`'s stdout and discards its exit status,
at `skills/issue/scripts/place.sh:749-750`:

    st="$(git --literal-pathspecs status --porcelain -- "$prefix" 2>/dev/null)"
    [[ -n "$st" ]] || return 0

Any git failure that produces no output — a corrupt index, a pathspec git
refuses, a permissions error — reads as "nothing changed" and returns **0**.

On the `cmd_commit` direct-handle path (`place.sh:1146`) this is the process's
first `git status`: the dirty guard ran in the separate `begin` process. So
`place_direct_publish` returns 0, `cmd_commit:1148` deletes the handle, and the
caller is told the mutation published while the agent's edits sit uncommitted in
the working tree and the handle is gone.

The sibling guard 145 lines earlier is the same two lines **with** the check, and
carries a comment naming this exact failure class (`place.sh:598-613`):

    #   collection on stdout, so testing output alone reads every failure — a
    #   corrupt index, a pathspec git refuses, a permissions error — as a clean
    #   collection, and waves through exactly the states this exists to stop.
    place_dirty_guard() {
      local prefix="$1" st rc
      st="$(git --literal-pathspecs status --porcelain -- "$prefix" 2>/dev/null)"
      rc=$?
      if (( rc != 0 )); then
        …
        return 2
      fi

`place_dirty_guard` was hardened for this by a closed issue in the previous round.
The publish side did not inherit it, and its failure direction is worse: silent
success rather than silent pass-through.

It is also a direct AC 4 failure — "each mutation auto-commits on the destination
as exactly one commit" — since zero commits are produced at rc 0. No test counts
commits on the direct arm.

Found independently by the AC 4 and AC 7 investigators during the fourth review.

## Action

Capture and check `git status`'s exit status at `place.sh:749`, refusing with a
named message on non-zero, exactly as `place_dirty_guard:604-611` does.

Pin it by corrupting `.git/index` so `status` exits non-zero having printed
nothing, then asserting `commit` refuses rather than reporting success — the
shape `tests/place.sh:2185-2199` already uses for the dirty guard.

Related, same function: on a failed `git commit` (`place.sh:752`) the collection
is left staged in the developer's real index with no reset, against the arm's
stated contract elsewhere that the checkout is left exactly as it is.
