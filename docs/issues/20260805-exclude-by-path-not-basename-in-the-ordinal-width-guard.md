---
id: 20260805-exclude-by-path-not-basename-in-the-ordinal-width-guard
num: 222
title: "Exclude by path, not basename, in the ordinal width guard"
status: closed
priority: medium
labels: [id-coordination, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T01:53:44Z
updated: 2026-08-05T10:21:33Z
origin: "20260805-b-prime-review.md (retired; see 5e712bf)"
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

## Resolution (2026-08-05)

Fixed as proposed, and the guard now catches every blind spot the issue
measured.

**Excluded by path, not basename.** The two `reconcile.sh` under `skills/` were
the live case; a future file taking any of the four names was the latent one.

**Widened beyond comma-form ranges.** It sees exactly-N literals (`[0-9]{3}` —
the spelling that let six gates in `jimpartition.sh` keep a 999 ceiling after the
bound moved), awk `length()` comparisons, and bash `${#x}` comparisons. The
discriminator is the **ceiling**: an ordinal spelling names 15, while an
unrelated length check that happens to name a floor of 3 does not. That keeps
`index.sh`'s `length(line) >= 3` out of scope without an exemption list.

**Counts only non-comment lines**, which closes the sixth mutation — a gate
losing its bound while a comment nearby gains the literal used to preserve the
per-file count. No counted site sits in a comment today, so the numbers did not
move; only the way one could move unseen.

Fail-closed on the comparison sweep, so its zero cannot mean "the pattern
stopped matching".

Five of the six reported-blind mutations now fail, and the sixth with them.

**Deliberately still open, and it belongs to a different surface:**
`docs/specs/platform/000-blueprint/spec.md:171` still asserts the fixture "fails
when a new width literal appears in any script", which is now much closer to true
but is a blueprint sentence, and blueprint text is written through
`/jim:blueprint` rather than by hand. It rides the docs pass with the other
blueprint corrections this cluster owes.

## Fold record (2026-08-05)

The blueprint sentence this issue said to correct was folded rather than made
true, so the pre-fold text is recorded here verbatim and the restoration target
with it.

**Pre-fold**, `docs/specs/platform/000-blueprint/spec.md`, the
`ordinal-single-source` row:

> …with a fixture that extracts every site's value, binds each to the constant,
> and fails when a new width literal appears in any script…

**Post-fold**: the same clause, scoped to the production roots (`skills/`,
`scripts/`), naming the three spellings it sees and the code-or-comment reach,
and saying that `tests/` is outside it by design.

**What changed in the mechanism first, so the fold is smaller than it looks.**
The guard now excludes by path rather than basename, sees the awk `length()` and
bash `${#x}` spellings as well as the regex one, counts only non-comment lines
per file, and sweeps **both** production roots — the last of those closed by the
verify judge, which proved a top-level production script could carry its own
width literal unseen.

**The restoration target, and why it is not simply "sweep `tests/` too".** A
bounded digit class under `tests/` is as often a pattern being matched as a bound
being enforced: `tests/provenance.sh` spells `[0-9]{3}` four times to detect
three-digit spec citations in prose, enforcing no ordinal bound at all. Restoring
"any script" honestly therefore needs a way to tell a gate from a detector — not
an exemption list, which would re-introduce exactly the by-name blindness this
issue was filed about. Until that exists, the narrower sentence is the true one.

**What should not come back:** the "any script" phrasing itself, even if the
sweep later reaches every root. It was false when written, and the fixture's
reach is the kind of claim that should be stated as what it covers rather than
as a universal.
