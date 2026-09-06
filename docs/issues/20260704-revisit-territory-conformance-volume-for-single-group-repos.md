---
id: 20260704-revisit-territory-conformance-volume-for-single-group-repos
num: 48
title: "Revisit territory-conformance volume for single-group repos"
status: closed
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [verify, blueprint]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-04T23:41:11Z
updated: 2026-07-25T07:49:14Z
origin: docs/specs/blueprint/007-verify-engine/plan.md
---

## Context

Surfaced during the spec 035 build (`/jim:verify`). The `check` verb's
territory-conformance step emits a `TERRITORY-CONFORMANCE` record for every
tracked file outside the group's declared territory (the deterministic set
difference). On jim's own repo — a single group whose territory is
`skills/`, `agents/`, `tests/` — that is ~240 files (all of `docs/`, root
config, README, etc.).

Per DD #8 the script emits the raw set difference and the skill frames
attribution (group code = violation, docs/config = informational). That is
correct by design, but at this volume the framing burden is large.

## What

Revisit the conformance default for the single-group case where a group's
territory is a strict subtree of the repo. Options to weigh:

- Have the skill summarize scaffolding buckets rather than enumerate every
  outside-territory file.
- Consider whether `jimverify.sh check` should narrow the candidate set
  (e.g. only files matching code-like heuristics) or leave it fully to the
  skill.
- Reassess when spec B (pipeline integration) lands, since blast-radius
  scoping may reshape conformance anyway.

## Why

Territory conformance (AC #5) is most useful when it surfaces a genuine
stray; drowning that signal in project scaffolding weakens it. This is a
practice-informed refinement, not a correctness bug — the design is
intentional and the skill's attribution framing handles it; a trend-signal
watch item.

## Resolution (2026-07-09)

Decided and shipped the **skill-summarization** option (of the three weighed
above). `jimverify.sh` is unchanged — it still emits the raw set difference
per DD #8, so the mechanical floor and its tests are untouched. The fix is in
`skills/verify/SKILL.md`: Step 9a now partitions the set difference into
**strays** (group code that plausibly belongs under a territory but fell
outside — the exceptions, enumerated, and fed to 9c as violations) and
**scaffolding** (docs / root config / license / CI / meta — bucketed to a
single summary line, never enumerated). Step 9b's report gains a one-line
`⚑ territory` row carrying the strays plus a scaffolding count. On a
single-group repo whose territory is a strict subtree, the census collapses
from ~240 lines to the strays that matter. (Also fixed a stale "Step 7"
cross-ref in the Step 5 output note — attribution is Step 9a.)

Not pursued: config-declared exclude globs and map-declared unowned paths.
Both are mechanical but add a config / blueprint-schema surface; the noise
lives in the *report*, so the presentation layer was the right place to fix
it. The set difference stays whole for any consumer that wants it.
