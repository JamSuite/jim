---
id: 20260731-drop-the-unbounded-bash-grant-from-meta-matrix-probe
num: 166
title: "Drop the unbounded bash grant from meta-matrix-probe"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-31T11:49:17Z
updated: 2026-08-13T11:36:20Z
origin: docs/specs/sdlc/000-blueprint/spec.md
---

## Description

## Description

`/jim:verify sdlc` scored the `agent-boundaries` invariant (high) a partial.
Clauses 1 and 2 hold at every persona: each of the nine agents names the
neighbouring role it must not usurp, tool grants match those declarations (pm,
architect, security and meta carry no `Bash` at all; the reviewer's is enumerated
per script path), and every artifact-producing skill terminates in an explicit
stop with no self-advancing phase chain.

The gap is clause 3 — read-only subagents are capability-narrowed. The group's
declared read-only subagent is exemplary:

    agents/investigator.md:13     tools: [Read, Glob, Grep]
    agents/investigator.md:25-27  "You have no Write, Edit, Bash, or Agent."

The other spawned subagent in this territory is not:

    agents/meta-matrix-probe.md:10  tools: [Bash(echo *), Bash(bash -c *)]
    agents/meta-matrix-probe.md:73  "Stop. Do not perform any work beyond the model header and the row reports."
    agents/meta-matrix-probe.md:81  "do not run `echo` yourself to produce the sentinels"

## Why it matters

The probe's entire process is "report what arrived in your context and stop", and
it is twice forbidden from executing anything — yet it holds an unbounded
command-execution grant that can mutate. That is capability granted-but-forbidden,
the exact posture the investigator's own rationale rejects: "the capability is
absent, not merely forbidden" (`agents/investigator.md:8-9`). This group's own
authoring checklist flags it as a failure — `skills/meta-agent/SKILL.md:130`,
"No permission creep (Write/Bash for a read-only agent)".

Counter-consideration recorded by the judge: the blueprint's Provides paragraph
(`docs/specs/sdlc/000-blueprint/spec.md:45`) names only the investigator as
"read-only by construction", so a narrower reading of the clause's subject class
would exclude the probe and make the invariant hold.

## Fix

Either narrow the probe's grant to what it actually needs (it runs nothing — the
`Bash` clauses may be removable entirely), or widen the blueprint's Provides
paragraph to state which subagents the clause binds, so the reading is not left
to the next judge.

Surfaced by a `/jim:verify sdlc` run during the `sdlc/018` build.

## Re-grade

**2026-08-13. `high` → `medium`.**

Inherited from the invariant, and the judge itself recorded the counter-reading:
the blueprint's Provides paragraph names only the investigator as "read-only by
construction", so a narrower reading of the clause's subject class would make this
invariant hold outright.

The substance is real — an unbounded command grant on an agent whose entire
process is "report what arrived and stop" is capability granted-but-forbidden,
which this project's own posture rejects. It is `medium` rather than `high`
because the holder is an internal probe reached only by a manually-invoked test
harness, and because the invariant may not cover it at all.

The same class in the `allowed-tools` drift issue is the one worth taking first:
there the grant sits on shipped skills.
