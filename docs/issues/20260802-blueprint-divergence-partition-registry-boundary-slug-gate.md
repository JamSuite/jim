---
id: 20260802-blueprint-divergence-partition-registry-boundary-slug-gate
num: 205
title: "Blueprint divergence: partition registry boundary slug gate"
status: closed
priority: critical
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, drift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-02T21:50:25Z
updated: 2026-08-05T02:25:13Z
origin: docs/specs/blueprint/025-rename-redirect-record-emission
---

## Description

## Divergence

**Invariant:** `partition-registry-boundary` (critical) — "The extractor registry
runs project tooling only through operator-configured `deps_command_<name>`
values executed via the Bash tool; `jimpartition.sh` never resolves or executes a
config-derived command string, and dynamic suffixes are slug-validated before any
lookup."

**resolved: fix the code**

## What the change did

The rename/redirect emission build added a shared pending-provisional detection
helper to `jimpartition.sh` and called it from all three preflights:

- `pending_provisionals` (`:919-927`) globs `"$specs_dir/$group"/P-*/`
- `check_pending_provisionals` (`:938-953`) emits the CHECK fact and the stderr
  refusal
- call sites: `:1050` (rename), `:1183` (split), `:1365` (merge)

The invariant's first clause is untouched — the new code resolves no config
value, executes nothing, and contains no `eval` or `source`.

The second clause is breached on one of the three paths. `cmd_rename_preflight`
(`:967-972`) and `cmd_split_preflight` (`:1076-1081`) reject a non-slug group at
entry with rc 2, so their calls pass an already-gated value.
`cmd_merge_preflight` (`:1212-1214`) validates only `specs_dir` — neither
`target` nor the listed sources are slug-gated — and `:1365` hands the whole
effective set into the glob at `:921`.

Reproduced:

```
merge-preflight BLUEPRINT.md docs/specs cart ../../OUTSIDE
  -> CHECK  pending-provisionals  pass  ../../OUTSIDE

rename-preflight BLUEPRINT.md docs/specs ../../OUTSIDE new
  -> jimpartition rename-preflight: invalid old slug: ../../OUTSIDE   (rc 2)
```

## Bounding the severity honestly

The group is inside double quotes in the glob word, so metacharacters are
literal: no word-splitting, no pattern injection, no execution. `specs_dir` is
already relpath-validated, so only `..` traversal escapes. Any such source has
already set `fail=1` at `:1259`, so there is no gating bypass and the verb still
returns 1. The concrete impact is a read-only directory-existence oracle plus
reflected (control-stripped, 512-byte-capped) foreign basenames.

What makes it worth fixing rather than accepting is that the same function states
the opposite rule twice, in the code the new call sits between:

- `:1264-1265` — "Slug-gate before the filesystem probe — never `test -d` an
  unvalidated component (split-preflight / rename-preflight parity)"
- `:1308-1309` — "already failed target-slug-valid — never probe an unvalidated
  slug"

`:1365` is the one probe in that function that does not follow the convention its
neighbours enforce.

## Proposed fix

Have `check_pending_provisionals` (`:938-953`) `valid_slug`-guard each group and
skip the probe on failure, matching the `:1268-1270` pattern. Rename and split
behavior stays byte-identical since their argument is already gated.

No test exercises a non-slug group component on the merge path; the five new
preflight cases all pass well-formed slugs.

Surfaced by the living-intent sensor on the post-build review of blueprint/025,
and independently by the review's own output-hygiene investigation.

## Resolution (2026-08-05)

`check_pending_provisionals` slug-gates each group through the file's existing
`valid_slug` before the `P-*/` glob. Rename and split are byte-identical — both
were already gated at entry, and the entry gate calls the same function, so the
two cannot disagree on any input. Merge no longer reports a traversal component
as a clean pass.

Verified by execution on both revisions: a 20-payload attack matrix (traversal,
absolute, empty, glob metacharacters, command substitution, control bytes) all
refused with the fact `invalid group slug` and the glob never reached; a
54-comparison byte-identity diff across 27 payloads x 2 verbs confirming rename
and split are unchanged; and a 29-payload comparison showing the gate reuses the
canonical slug rule rather than introducing a second one.

Correction to the record: the pre-fix defect was worse than this issue's
reproduction block showed. That block demonstrated a directory-existence oracle.
With a directory actually present at the traversal target, the pre-fix code
enumerated and reflected basenames from arbitrary paths inside *and outside* the
repo, on stdout and stderr. The prose severity was accurate; the repro
understated it.
