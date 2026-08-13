---
id: 20260813-six-deliberately-unfiled-items-from-the-c-prime-fix-round
num: 349
title: "Six deliberately-unfiled items from the C-prime fix round"
status: open
priority: low
labels: [docs, correctness, cleanup]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-13T11:00:24Z
updated: 2026-08-13T11:00:24Z
origin: "docs/notes/20260801-c-prime-fix-handoff.md"
---

## Description

## Description

The C′-fix round listed six items as "still unfiled — six, deliberately". They
were never filed, and all six are still present. Verified against the tree on
2026-08-13; line numbers below are current, and several drifted substantially
from the note's originals, which is its own argument for filing rather than
noting.

**1. A temp-file failure names neither the identity nor the residue.**
`skills/spec/scripts/reconcile.sh:398` — `echo "error: cannot create tmp file in
'$target'"`. The sibling failure branch two lines below names both the identity
and the half-applied state. This branch is reached *after* the directory rename,
so the developer is left with a renamed directory, a still-provisional id, and a
message that mentions neither.

**2. A realized count and a mapping listing can disagree.** `skills/issue/scripts/reconcile.sh`
prints a count from `apply_pending` alongside a mapping computed pre-apply over
the full candidate set. Since the batch semantics became accumulate-and-continue,
one file failing makes the two disagree with nothing reconciling them.

**3. A specs root containing a space truncates.** `skills/spec/scripts/reconcile.sh:978`
— `awk '$1=="REALIZED"{print $3}'` splits on whitespace, so `own_dirs` gets a
prefix of the path.

**4. A retired group is taught as the canonical example.** `agents/pm.md:49` —
"Groups: noun-based directories under `docs/specs/` (e.g., `jim`, `auth`,
`search`)". `docs/specs/jim/000-blueprint/spec.md` is `status: retired`. It
evaded the sweep that retired the other citations because that sweep keyed on the
literal string `docs/specs/jim`.

**5. The plan path admits only a realized identity.** `agents/security.md:54` —
`Plans: docs/specs/{group}/{id}-{name}/plan.md`, while the `Specs:` line directly
above it carries both the realized and the `P-{date}-{slug}` provisional forms.
A plan beside a still-provisional spec is not described.

**6. The liveness rule does not cover a rule declared only in a retired
blueprint.** `skills/review/SKILL.md` treats a retired group's blueprint as
not-live and skips it, which is right when a live successor carries the rule
forward — and leaves a rule that only ever existed there unchecked by anything.

## Action

Items 1, 3, 4, and 5 are one-line corrections. Item 2 wants the count derived
from the same pass that builds the listing. Item 6 is a judgment about what
`review` owes a retired-only rule, and is the only one that is not obvious.

Filed as one issue because each is a single edit and none blocks anything — the
same grouping the records-hygiene issue uses. Split if any one grows.
