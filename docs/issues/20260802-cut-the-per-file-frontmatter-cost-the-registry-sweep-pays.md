---
id: 20260802-cut-the-per-file-frontmatter-cost-the-registry-sweep-pays
num: 201
title: "Cut the per-file frontmatter cost the registry sweep pays"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [allocator, performance, registry]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-02T00:47:13Z
updated: 2026-08-02T00:47:13Z
origin: docs/specs/platform/012-registry-integrity-and-drift/review.md
---

## Description

## Description

The registry integrity sweep takes **~14 s** against jim's own collection (64
spec records, 200 issue files), against **~0.5 s** for a `peek`. That is inside
the `verify_registry_timeout` default of 120 s, so the check works — but it is
slow enough to be felt in CI, and it grows linearly with the collection.

The plan's DD 4 predicted the cost would be the id boundary and named #142
(memoize the boundary) as the escalation path. **Measured, that is not where the
time goes.** Profiling the phases:

| phase | ms |
| :--- | ---: |
| `alloc_seed_derive_issues` | 6954 |
| `alloc_sweep_pending_count` (before the grep narrowing landed) | 2177 |
| `alloc_seed_derive_specs` | 1220 |
| `alloc_classify_spec` | 116 |
| `alloc_classify_issue` | 51 |
| `alloc_sweep_uncovered_groups` | 48 |

The classification cores — the new code, and DD 4's subject — account for
**167 ms of ~14 s**. The cost is the *frontmatter read*: `alloc_seed_field`
forks a `sed` per field, and the issue derivation reads three fields per file,
so a 200-issue collection pays ~600 `sed` forks before any comparison happens.
The in-run token cache added by this spec (inside `alloc_valid_token`) already
removed the repeat id-boundary forks; what remains is per-file parsing.

The bootstrap has always paid this, but it is a one-time migration. The sweep is
meant to run in CI on every push, which is what makes it worth fixing now.

## Proposed action

Reduce the per-file frontmatter cost in `alloc_seed_field` / its callers — one
pass per file extracting every needed key (a single `sed -n`/`awk` invocation
instead of one per key), or a pure-bash frontmatter read with no fork at all.
Both stay inside the bash + POSIX constraint. Re-measure the sweep afterwards;
the target is the same order as a `peek` plus the unavoidable git reads.

Note for whoever picks this up: #142 (memoize the id-validation boundary) is a
*different* cost and is now partly addressed in-process by the allocator's own
token cache. Do not close #142 against this measurement, and do not assume this
one is fixed by fixing #142.

## Provenance

Measured during the build of the registry-integrity spec, on the live
collection, with the phase profile above.
