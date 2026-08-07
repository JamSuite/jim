---
id: 20260807-test-suite-wall-clock-exceeds-a-single-foreground-run
num: P-20260807-test-suite-wall-clock-exceeds-a-single-foreground-run
title: "Test suite wall-clock exceeds a single foreground run"
status: open
priority: low
labels: [testing, performance]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T10:59:37Z
updated: 2026-08-07T10:59:37Z
origin: docs/specs/issue/011-issue-placement/plan.md
---

## Description

## Description

`bash skills/meta-test/scripts/run.sh` now runs 1262 cases in about 7m40s
(measured: `real 7m36s`, `user 1m38s`, `sys 2m44s`).

The shape of those numbers is the finding: wall-clock is roughly 1.8x combined
user+sys, and 360ms per case against ~130ms of actual CPU. The suite is bound by
process spawning and filesystem work, not by computation — every case forks a
subshell, and the per-script invokers fork again for each assertion's
script-under-test call.

The practical consequence showed up during the `issue/011` build: the suite no
longer completes inside a single foreground command's timeout, so every
completion-gate run has to be launched in the background and polled. That is a
workable but worse loop, and it gets worse monotonically as cases accumulate.

This build contributed roughly 30 seconds — the 45 new `tests/place.sh` cases
(~16s, git-heavy by nature) plus a ~27ms `place.sh mode` call now made by each
issue-script invocation across the render cases. The remaining ~7 minutes
predates it.

## Proposed action

Profile per-file wall-clock (the loop used during this build works:
`for f in <case-filters>; do time bash tests/<file>.sh "$f"; done`) and attack
the top few. Likely candidates, in rough order of expected return:

- Cases that `git init` a fixture repo per assertion rather than per case.
- Per-assertion re-invocation of a script that could be invoked once with its
  output reused across several asserts.
- The aggregate runner's per-case subshell, if a cheaper isolation exists that
  still keeps a failing case from contaminating its neighbours.

A target worth naming: back under 5 minutes, which restores the single
foreground run.

## Notes

Distinct from #139 (`Decide the test suite timeout dependency`), which is about
`timeout(1)` being GNU coreutils rather than POSIX. This one is wall-clock.
