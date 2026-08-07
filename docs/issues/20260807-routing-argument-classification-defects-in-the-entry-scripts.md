---
id: 20260807-routing-argument-classification-defects-in-the-entry-scripts
num: 277
title: "Routing argument classification defects in the entry scripts"
status: open
priority: medium
labels: [issue, placement, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:55Z
updated: 2026-08-07T11:43:55Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

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
