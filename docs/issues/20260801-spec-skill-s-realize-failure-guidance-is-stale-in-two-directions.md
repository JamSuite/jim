---
id: 20260801-spec-skill-s-realize-failure-guidance-is-stale-in-two-directions
num: 194
title: "Spec skill's realize-failure guidance is stale in two directions"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [spec, docs, id-coordination]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-01T06:36:06Z
updated: 2026-08-01T10:01:09Z
origin: "20260801-c-prime-fix-handoff.md (retired; see 5e712bf)"
---

## Context

`skills/spec/SKILL.md:387` tells the agent what a non-zero exit from
`reconcile.sh --apply` means:

> If it exits non-zero, some identity halted — most likely because the realized
> ordinal's directory already exists, which is registry-vs-tree drift. Name the
> drift and stop; do not rename around it, and do not suffix. The other
> identities in the batch keep their ordinals, which are already durable, so a
> re-run converges on them.

Two changes shipped in the C-prime-fix made that guidance wrong. Both land on
this one paragraph and one edit closes both, so they are filed together.

## Problem 1 — "a re-run converges" no longer holds

After the accumulate-and-continue change to the spec-side realizer, rc 1 also
covers a *moved, swept, recorded, frontmatter-stale* identity. `scan_pending`
cannot see that state, so the prescribed re-run exits 0 reporting nothing
pending — the agent concludes it converged when it did not.

Worse, the instruction points away from the only correct repair. The sweep has
already rewritten every citation by that point, so reverting the directory to
re-run destroys work; the repair is the one-line frontmatter edit named on
stderr. The guidance never mentions it.

## Problem 2 — the new refusal is undocumented

`--apply` now refuses to run off the worktree top. An agent that hits
"must run from the worktree top" is told by this paragraph to report
registry-vs-tree drift and stop. It never surfaces `cd` as the fix, so a purely
mechanical, one-command recovery is reported to the developer as a data-integrity
problem.

## Proposed action

Rewrite the paragraph to enumerate the distinct non-zero outcomes and their
distinct repairs:

- realized ordinal's directory already exists → registry-vs-tree drift; name it
  and stop.
- moved/swept/recorded with stale frontmatter → apply the frontmatter edit named
  on stderr; do **not** revert the directory and do **not** rely on a re-run.
- run off the worktree top → `cd` to the worktree top and re-run.

Prefer keying the guidance on the stderr message rather than on rc alone, since
rc 1 no longer identifies a single condition.

## Provenance

Reported by the five-investigator review of the sdlc/issue-territory changes
(`docs/notes/20260801-c-prime-fix-handoff.md` § 4, findings N4 and N5, merged
here because they are the same paragraph and the same edit). The SKILL.md text
was re-read and re-confirmed 2026-08-01. The `scan_pending` blind spot is the
investigator's analysis and has **not** been reproduced — verify it before
relying on the exact wording of the second bullet.

## Resolution (2026-08-01)

Fixed. The paragraph is now a table keyed on the **stderr message** rather than
the exit code, since rc 1 no longer identifies one condition, with the distinct
repair for each outcome. Two explicit warnings added: do not revert a realized
directory (the sweep has already rewritten every citation, so reverting strands
them), and do not assume a re-run converges (an identity that moved and was
recorded but kept a stale `id:` is no longer pending, so a re-run exits 0).
