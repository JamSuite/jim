---
id: 20260730-realization-cannot-follow-a-group-renamed-since-issuance
num: 152
title: "Realization cannot follow a group renamed since issuance"
status: closed
priority: medium
labels: [id-coordination, spec]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-30T10:36:05Z
updated: 2026-08-03T05:46:40Z
origin: docs/specs/sdlc/017-coordinated-spec-identity/plan.md
---

## Description

## Description

When a spec's group is renamed between the moment an offline session bound a
provisional identity and the moment realization runs, `/jim:spec reconcile`
halts that identity instead of realizing it.

The allocator behaves correctly: `alloc_reconcile_realize_spec` resolves the
group through the alias map and answers under the group's *current* name, since
minting into a retired namespace is what `sdlc/017` AC 10 forbids. The realizer
then needs `docs/specs/<old-group>/P-<token>/` to become
`docs/specs/<new-group>/<NNN>-<slug>/` — a cross-parent move. Neither primitive
it holds can express one: `jimledger.sh rename-tracked` enforces
`dirname(old) == dirname(new)`, and `jimfile.sh mv-spec-id` composes its target
inside the source's own group directory. So `apply_pending` refuses that
identity, names the reason, and leaves the rest of the batch — whose ordinals
are already durable — to land.

It fails safe, and the manual path converges: the ordinal is published before
any rename, so moving the directory into the new group by hand and re-running
`--apply` finds the existing record (keyed on group, slug, issuance date),
reports it as `have`, and renames onto the same ordinal. No second allocation.

Two parts of the flow already handle cross-group correctly and need no work:
the citation sweep rewrites `<group>/<token>` as one token, so a path citation
picks up the new group, and the ledger `moved=` grammar can express
`<old-group>/P-<token>:<new-group>/<NNN>`.

A fix is four points:

1. **Widen `move-spec-dir`'s source-basename gate.** `jimledger.sh` already has
   the cross-parent spec-dir `git mv`; its gate is
   `^[0-9]{3}(-[a-z0-9][a-z0-9-]*|-wip)$`, which refuses a reserved provisional
   source. Widen the *source* side only — the destination stays `NNN-slug`.
   (This is the change `sdlc/017`'s plan described as task 6, attributed there
   to `rename-tracked`, which has no such gate. The instruction was a residue
   of the `move-spec-dir` option DD 4 had rejected as "cross-parent power the
   flow never needs" — true for the same-group case, which is why
   `rename-tracked` needed no change at all.)
2. **Route the realizer to it** when the realized group differs from the issued
   group and the directory is tracked.
3. **Cover the untracked case.** No cross-parent plain-move verb exists; either
   add one to `jimfile.sh` or require the directory be committed first and say
   so in the refusal.
4. **Rewrite the frontmatter `group:` field.** The realizer rewrites `id:` only.
   This is a latent defect independent of the rename: nothing rewrites `group:`
   today, and that is currently harmless only because the group never changes
   across a realization.

Not urgent — it takes a group rename landing inside an offline window, and the
failure is a loud halt with a converging manual path. Point 4 is worth doing
whenever this is picked up, regardless of the rest.

## Resolution (2026-08-03)

All four points delivered by `blueprint/025`.

1. `move-spec-dir`'s source-basename gate widened to admit a provisional token;
   the destination side stays `NNN-slug`.
2. The realizer routes to it when the realized group differs from the issued
   group (`skills/spec/scripts/reconcile.sh:347`).
3. The untracked case refuses loudly and names the remedy rather than being
   worked around (`:356`) — no cross-parent plain-move verb was added.
4. The frontmatter `group:` field is now rewritten alongside `id:` (`:248-249`),
   closing the latent defect this issue flagged as worth doing regardless.

One caveat carried forward: that new untracked refusal is the one realize halt
whose remedy genuinely **is** a re-run, and `skills/spec/SKILL.md`'s
stderr→repair table has no row for it while its general advice argues against
re-running. Tracked in
[[20260802-retire-the-stale-documentation-the-emission-build-left-behind]].
