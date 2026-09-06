---
id: 20260807-routing-argument-classification-defects-in-the-entry-scripts
num: 277
title: "Routing argument classification defects in the entry scripts"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, placement, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-07T11:43:55Z
updated: 2026-08-11T11:05:00Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

Three defects in how the entry scripts classify their own arguments before
routing, plus one contract-timing problem. Grouped because the fixes are all in
the same few lines of routing code.

**1. `reconcile.sh -c <cfg>` is mistaken for the issues dir.** Its routing loop
has no `skip_next`, unlike the sibling `migrate.sh`. `-c` matches `-*` and is
ignored; the config path then matches `*)` and becomes `dir`, so routing returns
before `place.sh mode` is ever called and the realization rewrites the
**working-tree** collection. Latent (no production skill passes `-c`), but it
also means reconcile's routing can never be exercised through the `-c` fixture
path. One line mirroring migrate.

**2. `render.sh show` with no id loses its usage error.** `dir_given` requires
two args for `show`, so a zero-arg `show` routes; `{}` then lands in the *id*
slot, `dir` stays empty, and the fallback resolves the working-tree dir —
creating an untracked `docs/issues/INDEX.md` and printing ``no issue matched
`/tmp/tmp.XXXX/collection` `` at rc 0. It used to be a clean rc 2, and the temp
path now leaks into user-visible output.

**3. `render.sh list <not-a-filter>`** is treated as a dir, so placement is
silently bypassed and a stray `<token>/INDEX.md` appears in the working tree.
The stray-dir behavior is pre-existing; the placement bypass is new.

**4. The emitter's stdout contract is printed before publication is known.**
`new.sh` prints `<slug>\t<path>` inside the wrapped command; the publish happens
afterward and can fail (rc 3 conflict, rc 1 build failure). The caller then
holds a line naming a destination path where nothing landed — and the ordinal is
already burned in the append-only registry. Observed:

```
20260807-alpha	./docs/issues/20260807-alpha.md
place.sh: could not build the destination tree
write rc=1
```

The candidate-batch flows check rc, so they skip the row rather than record a
phantom. `new.sh`'s EXIT CODES header still documents only 0/1/2 while the
`exec` now propagates place.sh's rc 3.

Related: `skills/issue/SKILL.md` §6 step 4 tells the agent to read the written
file's `num:` back from the printed path. Under placement that path is not in
the working tree. Worse after the documented flip-migration, where a leftover
working-tree copy would be read instead, silently reporting the wrong ordinal.
§6a got a placement arm; §6 did not.

## Proposed action

Fix 1-3 in the routing blocks; document rc 3 in `new.sh`'s header; and either
defer the stdout line until after publication or state in §6/§7a that the path
is provisional until the command's exit status is checked.

## Progress (2026-08-11)

**Items 1–3 fixed** in `b467b36`. Reconcile's routing loop skips a flag's value,
so `-c <cfg>` is no longer mistaken for the collection; a `show` with no id is
not routed, so the appended directory cannot land in the id slot; and a lone
`list` argument is treated as a directory only if it is one — with the consumer
refusing a token that is neither filter nor collection, since the stray directory
was reachable with no placement configured too.

**Item 4 remains open** and is the reason this issue is not closed. The emitter
prints `<slug>\t<path>` from inside the wrapped command, before a publish that
can still fail, so a caller can hold a line naming a destination path where
nothing landed — with the ordinal already burned in the append-only registry.
That is a contract-timing decision rather than a classification defect, and it is
not a one-liner. `new.sh`'s EXIT CODES header also still documents only 0/1/2
while the `exec` propagates rc 3.

## Resolution (2026-08-11)

**Item 4 fixed** in `138477e`, closing the issue. `place.sh` holds the wrapped
command's stdout on the plumbing arm and releases it only once the publish has
landed, so a printed path is one that exists at the destination. On a refusal
the line goes to stderr under a `not published` marker rather than being
discarded — the ordinal it names is spent whether or not the publish succeeded,
so dropping it would destroy the only record of which one was burned. The
emitter's contract in `skills/issue/SKILL.md` § 7a states this, and `new.sh`'s
rc 3 entry now says the identity is spent and a re-run files under a new one.

Only the plumbing arm changed. The checked-out arm writes into the working tree,
where the file is there for the caller whether or not the commit succeeds, so
its stdout was never a claim about something absent.

Pinned in `tests/place.sh` by a refused publish whose wrapped command prints a
path — stdout must not carry it, stderr must — with two controls that fail if
the fix were "discard everything": a landed publish emits the line on stdout
naming the destination prefix, and a read hands its output back unheld.

**Correction to this issue's own text**, carried into the Progress note above
and wrong in both: `new.sh`'s `EXIT CODES` header did *not* still document only
0/1/2. Exit 3 has been documented there since `3d4e592`, the build commit that
introduced the placement refusal. Only the wording about what rc 3 leaves behind
was missing.

Items 1–3 were fixed earlier in `b467b36`; see the Progress note above.
