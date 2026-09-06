---
id: 20260812-spec-reconcile-citation-sweep-bypasses-issue-placement
num: 316
title: "Spec reconcile citation sweep bypasses issue placement"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:41:31Z
updated: 2026-08-12T20:02:19Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`/jim:spec reconcile --apply`'s citation sweep edits issue files without routing
through `place.sh`, so under a branch placement it writes to the wrong branch or
silently does nothing.

## Mechanism

`skills/spec/scripts/reconcile.sh:461-684`. `sweep_citations` builds its target
set from the configured `issues` root, enumerates it with
`git --literal-pathspecs ls-files` plus untracked files — i.e. the **working
checkout** — and rewrites each matching file in place. It then regenerates the
index at `:682` with `bash "$HERE/../../issue/scripts/index.sh" "$issues_root"`.
That explicit directory argument is exactly `index.sh`'s routing opt-out
(`index.sh:284`), so the regeneration cannot route either.

Under a branch placement this gives one of two wrong outcomes:

- the working branch carries a copy of the collection, so issue-body edits **and**
  `INDEX.md` land on the working branch — the outcome AC 3 forbids; or
- it does not, so the destination's issue bodies keep citing the retired
  provisional identity, the sweep counts zero touched files, and it exits clean
  with nothing reported.

`skills/spec/SKILL.md` mentions placement only in its candidate-batch lines;
nothing in the spec group references `place.sh`.

## Proposed action

Route the sweep and its index regeneration through `place.sh` — either by
wrapping the rewrite in a `run --verb edit` invocation, or by using the two-phase
`begin`/`commit` door since the sweep is a multi-file edit with no single
wrappable command. Either way the spec skill needs a `place.sh` grant it does not
currently have.

## Origin

Post-build review of `issue/011`; found by tracing AC 3's "every collection
write" against the tree rather than the diff.

## Decision (2026-08-12)

**Route it, script-to-script.** `reconcile.sh` drives `place.sh begin` /
`commit` directly around the issue half of the sweep.

Two alternatives were weighed and rejected. Moving the issue half behind a
self-routing issue-group entry script — which would keep `place.sh` faceless and
honour plan DD 2 — collapses back into this one unless the *grammar* moves too,
and moving it would put spec's citation forms (typed `group/NNN`, pathed spec
dirs, bare ordinals, fence skipping) into the issue group as a fourth rewriter
that must stay in lockstep with spec's across a group boundary. Refusing under a
placement was rejected because it leaves `/jim:spec reconcile --apply` unusable
on exactly the team configuration the spec exists to serve.

DD 2 nominally rejected caller-side wrapping, but its stated reasons were
cross-group **SKILL.md** edits and a future caller silently missing placement —
neither applies to a script calling a script.

**Consequence to take with it:** `place.sh` gains its first external caller, so
the group blueprint's Structure line ("It exposes no face: no caller outside the
group invokes it") and its Provides face both need amending, plus a contract edge
`issue → spec`. Through `/jim:blueprint`, not by hand.

**Correction to this issue's own text:** no skill grant is required. The agent
runs `reconcile.sh`, not the callee, and that script already calls
`issue/scripts/index.sh` by `BASH_SOURCE`-relative path. The grant claim holds
only for a skill-level shape, which this is not.

**Not yet implemented.**

## Resolution (2026-08-12)

Implemented in `7c235fc`, as decided — `reconcile.sh` drives `place.sh`
`begin`/`commit` directly around the issue half of the sweep.

**What routing meant in practice.** `sweep_citations` asks `place.sh mode` once.
On `direct` nothing changes: the issues root stays in the `git ls-files`
pathspec, the untracked and own-directory passes extend that enumeration as
before, and `index.sh` regenerates with the explicit directory argument. On
`route` the issues root is dropped from the pathspec entirely — sweeping both the
checkout fork and the destination would rewrite a copy nobody reads and publish
the same edits twice — and the handle's collection is enumerated instead.

**Three details that were not obvious from the finding.**

1. *The containment guard had to be split.* Every worktree target clears
   `valid-relpath` plus a `realpath` containment check against the worktree top.
   The handle's entries live in a temp directory outside the worktree by
   construction, so that check would refuse the very collection the sweep exists
   to rewrite. They are appended **after** the guard loop; their containment is
   established where it belongs, in `place_materialize`, which requires each
   entry to be a regular file with a plain name resolving inside the collection
   and aborts before handing back a handle otherwise.
2. *The empty-set early return had to move.* It sat before the handle was opened,
   so a destination with citations to rewrite would have been skipped whenever
   the worktree half was empty — which is the common shape under a placement.
3. *No `index.sh` call on the routed arm.* `place.sh` regenerates the index inside
   what it publishes, and calling `index.sh` with an explicit directory is the
   routing opt-out this issue is about.

**Commit shape.** `--verb edit`, no `--id`: a multi-file citation re-point names
no single issue, and the subject is composed from the verb enum, so no drafted
text can reach it. A refused publish (rc 3) fails the sweep and names the handle,
the directory still holding the edits, and both recovery commands — `place.sh`
preserves a handle on conflict rather than discarding the work.

Pinned by `case_specreconcile_sweeps_the_collection_at_its_placement`, which
files its fixture issue through the emitter so the collection is built on the
destination the way a real one is. Proven red with `place.sh` made unreachable:
the destination's issue still carries both provisional citations, zero commits
land, and the sweep exits 0 — the "counts zero touched and exits clean" outcome
this issue describes, reproduced exactly.

**Confirmed as stated in the decision:** no skill grant was needed. The agent
runs `reconcile.sh`; the script reaches `place.sh` by `BASH_SOURCE`-relative
path, as it already did for `index.sh`.
