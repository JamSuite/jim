---
id: 20260705-migrate-review-s-issue-batch-to-the-new-sh-emitter
num: 55
title: "Migrate review's issue batch to the new.sh emitter"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [issue-tracking, review]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-05T07:25:21Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/008-verify-loop/plan.md
---

## Context

Spec 025 consolidated issue-file creation into a single emitter
(`skills/issue/scripts/new.sh`): every surfacing skill's candidate batch
and `/jim:issue add` file through it, so the spec-017 template is
materialized in exactly one place, ids are validated via `jimfile.sh
valid-id`, and untrusted title/labels/origin values are YAML-encoded —
with bodies passed via temp file, never inline in a shell command
(security 025 Finding 5).

`/jim:review`'s end-of-phase candidate batch (`skills/review/SKILL.md`
Step 9, lines 153-162) predates that consolidation: its auto-file path
still resolves slug/path via `jimfile.sh next-id issue` / `path issue` and
writes the file directly with the Write tool from the spec-017 template —
bypassing `new.sh`'s id validation, field encoding, and single-source
template. Review's `allowed-tools` accordingly grants `index.sh` but not
`new.sh`.

Noticed while planning spec 036: the living-intent sensor routes
pre-existing drift violations into this same Step-9 batch, so the legacy
path gains a new producer and more traffic.

## Proposed action

Rewrite Step 9's filing mechanics (auto-file and interactive paths alike)
to file through the emitter, mirroring the other six surfacing skills:
write each body to a temp file with the Write tool, call `new.sh --title …
--priority … --labels … --origin … --body-file …`, regenerate INDEX.md
once per batch; drop the direct-Write template materialization; extend
`allowed-tools` with the `new.sh` clause.

## Why it matters

- Single-emitter doctrine (spec 025): one place materializes the template.
- `new.sh` validates ids and YAML-encodes untrusted fields; the
  direct-Write path re-implements neither.
- Spec 036 increases traffic through the legacy path (sensor-driven
  violation candidates).

## Resolution

Step 9's filing mechanics now route through the `new.sh` emitter on both
the auto-file and interactive paths: each candidate body is written to a
temp file and filed via `new.sh --title … --priority … --labels …
--origin … --body-file …`, with a single INDEX.md regen per batch. The
direct-Write template materialization is gone, so id validation and
untrusted-field encoding are no longer bypassed. The skill's
`allowed-tools` gained the `new.sh` clause and dropped the now-dead
`mkdir` grant (its only consumer was the removed direct-Write path;
`new.sh` does its own directory creation).
