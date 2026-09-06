---
id: 20260823-identity-rewrite-composes-a-path-from-an-unvalidated-slug
num: 360
title: "Identity rewrite composes a path from an unvalidated slug"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue, migration, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T23:37:26Z
updated: 2026-08-24T08:31:35Z
origin: "docs/specs/issue/000-blueprint/spec.md"
---

## Description

The blueprint invariant `id-gate-before-path` states that "every id passes the
validator before any path composition or file read." The identity rewrite's
apply path composes `"$dir/$slug.md"` with no validator call on the slug.

## What is there now

The slug reaching that composition is a byte-identical reconstruction of a
directory entry the plan builder enumerated by glob, with dot-prefixed names
and the index file excluded. No traversal is reachable — a globbed basename
cannot contain a separator — so this is not an exploitable defect.

## Why it is still worth fixing

The invariant's text is unconditional, and this project has already decided
this exact question three times in the other direction:

- `new.sh` applies the validator even to allocator-derived ids, with the stated
  reason that "the sanitization that produced it lives in another group, so the
  value is not provably validator-clean here" — an explicit refusal of
  safe-by-provenance reasoning
- `index.sh` validates this identical category of glob-derived slug, even
  though it composes no path from it
- `migrate.sh` itself was fixed once before for this class: the collision
  discriminator was reaching a filename unvalidated, and the test that pins the
  fix names `id-gate-before-path` as the critical invariant it breached

Leaving it unvalidated makes the new site inconsistent with its own neighbours
and reopens a question the project settled.

## Scope

The sibling `apply_schema_plan` composes `"$dir/$SCHEMA_SLUG.md"` the same way
and predates this change. Both are the same one-line fix and belong together.

Origin: `docs/specs/issue/013-recorded-identity-schemes/review.md` — Finding 2,
and the living-intent violation resolved `fix` at the blueprint fork.

## Resolution (2026-08-24)

Fixed in `2536459`.

`jf valid-id` runs before the path composition in `apply_identity_plan` and in
the sibling `apply_schema_plan`, as the Scope section above asked — fixing only
the first would have left the wrong shape for the next reader to copy.

Nothing reachable changes: each slug is still a byte-identical reconstruction
of an entry the same run globbed. What changes is that the boundary is the
validator call rather than an argument about where the value came from.

Pinned by `case_migrate_identity_apply_gates_the_id_before_composing_a_path`,
which places a `..`-bearing entry in the collection and asserts the run refuses
whole with nothing written. It was run against the unfixed script first and
fails there.

## Update (2026-08-24) — the Scope section named two sites; there are three

Reopened after `/jim:verify issue` graded `id-gate-before-path` **partial**
against the code that had just closed this issue. The judge confirmed the two
gates that landed in `2536459`, then found a third composition site this
issue's own Scope section never named.

`apply_plan` — the `prefix` migration, untouched by the original fix:

```
migrate.sh:268   id="${base%.md}"                                  # glob-derived
migrate.sh:269   finalid="$(awk … "$mapfile")"                     # rename target, or…
migrate.sh:270   [[ -n "$finalid" ]] || finalid="$id"              # …the raw id, ungated
migrate.sh:277   s_new+=("$dir/$finalid.md")                       # composed into a path
```

Counted mechanically across the three apply paths:

```
apply_plan           lines 235-365   valid-id calls: 0
apply_schema_plan    lines 474-558   valid-id calls: 1
apply_identity_plan  lines 830-900   valid-id calls: 1
```

The map lookup's own branch is safe — a rename target was validated at
`build_plan` before it entered the map. It is the **fallback** that is ungated:
a row with no map entry (`skip-unmigratable` — an id with no `-` delimiter, or a
failed `prefix-from`) takes the raw glob-derived id.

Not exploitable, for the same reason the original two sites were not: `finalid`
there is byte-identical to the source file's own basename from the same glob
iteration, so the composed path *is* the source path and the `mv` is a
self-rename. What makes it worth fixing is what made the first two worth fixing
— the site is now the only one in the group missing the convention that
`migrate.sh`'s own comment claims is applied at every composition site.

That comment is currently false as written, which is the same failure mode
`#365` had: a document asserting a property the code does not hold.

**Process note.** This is the third defect in this cycle found by a method
other than the test suite, after the collision check (found by running the verb
against real data) and the bracket bypass (found by adversarial reading). The
suite was green at 1,551 across both commits that closed this issue. The gap
was not too few tests — it was that the fix was scoped from the issue's own
Scope section rather than from an independent enumeration of every site the
invariant covers.

## Resolution (2026-08-24) — all three migration sites

Fixed in `a54cb98`, closing the third site the Update above records.

`apply_plan` now gates `finalid` before composing `"$dir/$finalid.md"`,
covering both arms: the map's rename targets (already validated at plan time)
and the fallback that takes the raw directory entry. The gate census across the
three apply paths is now 1 / 1 / 1, and `migrate.sh`'s own comment claiming
every composition site checks is true as written.

Pinned by `case_issues_migrate_prefix_apply_gates_the_id_before_composing_a_path`,
which stages a `bad..name.md` entry — the row that takes the fallback arm — and
asserts the run refuses whole, writes nothing, and leaves no tmp behind. Run
against the unfixed `apply_plan` first: rc 0 with the collection mutated.

Suite green at 1,552.

**The `id-gate-before-path` invariant is still `partial`, and not because of
this issue.** A re-run of the verify judge against the committed fix confirmed
all three migration sites and found a fourth door elsewhere:
`transition.sh`'s `resolve_slug` returns a directory-derived basename on its
ordinal and prefix branches, and `main` composes `"$work/$slug.md"` from it with
no second gate — the caller's `id` is validated, but the value that actually
names the file is not. Reproduced: a collection holding `a..b.md` with
`num: 42` is read and rewritten by `close 42` at rc 0.

That is a different script, a different mechanism, and predates this increment,
so it is tracked separately rather than folded here. This issue's scope — the
migration apply paths — is complete.
