---
id: 20260812-place-direct-publish-reads-a-git-failure-as-nothing-to-publish
num: 340
title: "place_direct_publish reads a git failure as nothing to publish"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, fail-open]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T21:53:21Z
updated: 2026-08-13T07:57:24Z
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

## Resolution

**2026-08-13.** Fixed in `19eb76e`. `place_direct_publish` captures `git
status`'s exit status and refuses on non-zero, naming what it could not tell —
the shape `place_dirty_guard` already uses, whose comment names this exact
failure class.

Pinned by `case_place_direct_commit_refuses_when_the_publish_status_cannot_run`,
which corrupts `.git/index` *after* `begin` so the dirty guard has already run
in its own process and this read is the one being driven — the composition the
issue describes. It asserts the refusal, that HEAD did not move, and that the
handle's state survives so the mutation stays recoverable.

That last assertion needed care: on this arm the directory `begin` prints is the
working tree's own collection, which exists whatever happens, so asserting
against it could never fail. It is asserted against the state directory under
the git dir instead.

Proven by neutering the status check and watching the case go red.

**The related item is taken too.** On a failed `git commit` the collection is
unstaged before returning, so the arm's stated contract — the checkout is left
exactly as it is — holds on the failure path as well. It is pinned separately
under the hook-exposure issue, which owns that half.
