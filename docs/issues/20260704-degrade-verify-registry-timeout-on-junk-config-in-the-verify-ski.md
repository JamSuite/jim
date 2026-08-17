---
id: 20260704-degrade-verify-registry-timeout-on-junk-config-in-the-verify-ski
num: 50
title: "Degrade verify_registry_timeout on junk config in the verify skill"
status: open
priority: medium
labels: [verify, config]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-04T23:53:20Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/007-verify-engine/review.md
---

## Description

## Context

From the spec 035 post-build review (`review.md` Finding 2). DD #5 requires
`verify_registry_timeout` to degrade a junk / non-positive value to `120`
(the same degrade + report-note rule as `verify_appetite` / `verify_fanout_cap` /
`verify_model`).

## What

In `skills/verify/SKILL.md` Step 1, add the `verify_registry_timeout` validation
alongside the other knobs: treat a non-positive / non-numeric value as `120` and
note the fallback in the run's report, before Step 6 converts it to the Bash-tool
timeout (seconds -> milliseconds).

## Why

Today the resolved `verify_registry_timeout` (SKILL.md:50) is carried straight to
Step 6 with no range/type gate, unlike its three siblings which Step 1 validates.
A malformed operator value would produce a malformed timeout on the registry
Bash-tool call.

Severity: robustness, not a trust-boundary risk — the value is operator config,
never blueprint-derived. But it is a direct DD #5 omission and cheap to close.
