---
id: 20260805-exclude-by-path-not-basename-in-the-ordinal-width-guard
num: 222
title: "Exclude by path, not basename, in the ordinal width guard"
status: open
priority: medium
labels: [id-coordination, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:44Z
updated: 2026-08-05T01:53:44Z
origin: docs/notes/20260805-b-prime-review.md
---

## Description

## Description

The tree-wide guard added to catch "a NEW script gaining its own width literal"
excludes by **basename**, and two files under `skills/` share an excluded
basename.

`tests/jimfile.sh:1555-1557`:

```bash
assert_eq "no width spelling in any other script" "0" \
  "$(grep -rloE '\[0-9\]\{[0-9]+,[0-9]+\}' --include='*.sh' "$REPO_ROOT/skills" \
     | grep -vE '(jimfile|jimledger|reconcile)\.sh$' | grep -c .)"
```

There are two `reconcile.sh` under `skills/`:

```
skills/spec/scripts/reconcile.sh    ← intended
skills/issue/scripts/reconcile.sh   ← silently exempted
```

So a width literal added to `skills/issue/scripts/reconcile.sh` today passes the
guard, as does any future file named `jimfile.sh`, `jimledger.sh`, or
`reconcile.sh`. The guard's own comment claims it catches "the one divergence none
of the per-file counts above would see."

15 mutations were run against the fixture. M9 (a new script with a range literal)
fires correctly. Six do not:

- a width literal in `skills/issue/scripts/reconcile.sh` — **blind**
- a new `skills/arch/scripts/reconcile.sh` with a range literal — **blind**
- exactly-N literals (`^[0-9]{3}$`) — **blind**
- awk `length(s)>=3 && length(s)<=15` — **blind**
- `(( ${#1} > 15 ))` — **blind**
- a gate losing its bound while a *comment* keeps the literal — **blind** (count preserved)

The last three matter because they are the two spellings the codebase actually
uses outside regex form: the constant's own comparison and `isord`'s awk.

**Consequence for the recorded invariant.** `docs/specs/platform/000-blueprint/spec.md:171`
now asserts the fixture "fails when a new width literal appears in **any script**".
That is false, and it is false in the more dangerous direction — an overstated
invariant makes `/jim:verify` report confidence the code does not earn, where an
understated one at least surfaces as a violation. The fold understated this
invariant; the restoration overshoots it.

## Proposed action

Exclude by **path**, not basename. Then widen the pattern beyond comma-form
ranges to cover exactly-N literals, awk `length()` comparisons, and `${#x}`
numeric comparisons — or state in the fixture's own comment which spellings it
does not see, so the next reader does not inherit the stronger claim.

Correct `spec.md:171` to describe what the guard actually enforces. The six
exactly-3 gates in `jimpartition.sh` are the concrete case the current text
implies are covered and are not.

## Provenance

Post-build review of the B-prime hardening cluster
(`docs/notes/20260805-b-prime-review.md`, Finding 7).
