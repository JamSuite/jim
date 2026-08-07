---
id: 20260807-placement-tests-one-vacuous-case-and-untested-direct-mode
num: P-20260807-placement-tests-one-vacuous-case-and-untested-direct-mode
title: "Placement tests: one vacuous case and untested direct mode"
status: open
priority: medium
labels: [testing, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:58Z
updated: 2026-08-07T11:43:58Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

An audit of the placement test suite found one case that cannot fail, three that
pass for reasons other than the property they name, and coverage holes in the
riskiest code.

**Cannot fail.** `case_place_cleans_up_its_temp_directory` discards rc, inspects
no output, and asserts only that a temp dir is absent — **it passes if
`place.sh` is deleted entirely**. One added landing assertion fixes it.

**Pass for the wrong reason.**
- `case_issues_placement_read_publishes_nothing` and
  `case_issues_placement_preview_publishes_nothing` assert "tip unmoved" in
  scenarios where the tip cannot move either way, because `place_changed`
  already guarantees it. They do not pin read-only routing.
- `case_issues_placement_tolerates_a_branch_only_origin` creates the origin file
  in the working tree, so the origin is present rather than dangling.
- `case_place_leaves_the_working_tree_untouched` is absence-only: a `place.sh`
  that returned 0 while writing nothing anywhere would pass.

**Fixture robustness.** `place_seed_collection` checks none of its own
`mktree`/`commit-tree`/`update-ref` exit statuses, and three cases take a
baseline with `rev-parse` **without `--verify`** — so a silently failed fixture
would compare two identical error strings.

**Coverage holes, ranked.**
1. The entire `direct`-token branch of `begin`/`commit`/`abort` — zero tests,
   and it is where the read-handle-publishes and no-HEAD-recheck defects live.
2. `place_prefix`'s unsafe-path refusal — the one security gate in the script
   with no coverage at all.
3. `--id` validation, at both call sites (the verb half of "no free text reaches
   a commit message" is tested; the id half is not).
4. The entire local-tier retry path — all four race cases use the origin tier,
   so a regression dropping the local CAS old-value would be invisible.
5. `place_commit_tree`'s fallback identity; `place_snapshot`'s non-regular-file
   refusal; `place_regraft`'s already-applied early return; the argument-shape
   refusals; `place_shown`'s control-character scrubbing.

## Proposed action

Fix the one vacuous case and the three misnamed ones first — a test that cannot
fail is worse than no test, because it reports coverage. Then add the
direct-branch and `place_prefix` cases; both are cheap and both guard confirmed
defects.
