---
id: 20260812-three-load-bearing-place-sh-guards-are-unpinned
num: 343
title: "Three load-bearing place.sh guards are unpinned"
status: open
priority: high
labels: [test, integrity]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-12T21:53:45Z
updated: 2026-08-12T21:53:45Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

The fourth review's test-integrity sweep found **4 of 168** cases in the spec's
test surface cannot fail for the guard they name. On the third review's narrower
slice the count is 3 of 146, against its reported 2 of 115.

## Cases that cannot fail

**1. `tests/issues.sh:3460` — `case_issues_declaration_is_not_required_by_default`.**
The assertion label reads "files with no declaration at all", but `:3464` passes
`--reviewed`. The guard it claims to pin is the `route` scoping of the XOR gate
(`new.sh:124` wrapping `:152`). Hoist that block out of the `route` branch — making
the declaration required for every project — and the case stays green.

`:3431` is the only filing in the whole tree with neither flag and no `--dir`, and
it is the refusal case *under* a placement. **So nothing anywhere exercises a bare
filing on the default path**, which is the behaviour AC 2 exists to protect. Added
in the review-remediation round.

**2. `tests/place.sh:185` — `case_place_refuses_an_unsafe_issues_path`.**
Configures `issues_path = "../outside"` and asserts only rc 2 plus non-emptiness.
That value never reaches the gate the case names: `place_prefix`
(`place.sh:308-314`) matches `../*` in its dot-segment `case` and returns 2 before
`:315-319`'s `valid-relpath` call. Deleting the `valid-relpath` gate leaves the
case green; so does deleting the leading-dash gate at `:320`.

## Cases whose headline holds but whose named gate does not

**3–4. `tests/place.sh:532` and `:606`** — the two uncontained-tree-entry cases.
The crafted entry arrives as `../../evil`, which contains `/`, so the *plain-name*
gate (`place.sh:1314-1318`) refuses it. Both assert only `'evil'` in stderr, a
string every refusal message carries, so the per-entry realpath containment gate
they name (`place.sh:1329-1334`) can be deleted with the suite green.

## Load-bearing guards that no case pins

- **`place.sh:746`** — `place_worktree_contained` inside `place_direct_publish`.
  The two existing containment cases are refused earlier (`place.sh:726` and
  `:963`); nothing introduces the symlink *between* `begin` and `commit`, the one
  path where `:746` is load-bearing. Named by the third review as still unproven;
  still unproven.
- **`place.sh:1276`** — `place_check_rewrite`'s `(( authoritative )) || return 0`.
  This is the single defence against a bookmark rewind. Delete it and every offline
  run compares against and records its own state, reintroducing two closed
  false-alarm findings — and no case goes red.
- **`place.sh:185-189`** — `place_destination`'s resolver-failure arm. Replace it
  with a plain assignment and the whole suite stays green; no case induces a
  jimconf failure while invoking `place.sh`. This is the guard WP15 shipped as the
  fix for a fail-open.

## Action

1. Drop `--reviewed` from `tests/issues.sh:3464`, and add a companion asserting
   both flags together are also inert by default.
2. Retarget `tests/place.sh:185` to a path that is shape-invalid without a dot
   segment, and assert each refusal's own wording.
3. Assert the plain-name refusal's own wording in `tests/place.sh:532` and `:606`,
   and add one case whose entry name is separator-free yet resolves outside `$dest`.
4. Pin the three guards above — for `:746`, open a direct write handle, replace
   `docs` with a symlink out of the repo, then `commit`, asserting rc 2.

Also worth tracking here: `tests/jimalloc.sh:1131`
(`case_jimalloc_group_alias_map_cycle`) has the identical `timeout 10` shape to the
known load-dependent flake at `:940`, so a 124 in either should be recognised as
the known flake rather than investigated as a regression. And
`tests/place.sh:661` / `:2443` capture a `before` tip with no non-emptiness floor,
so a silently-failed `place_seed_collection` makes them compare `"" == ""` — only
2 of ~17 call sites check the helper's status.
