---
id: 20260801-surface-a-suppressed-agent-fan-out-as-a-named-degradation
num: P-20260801-surface-a-suppressed-agent-fan-out-as-a-named-degradation
title: "Surface a suppressed agent fan-out as a named degradation"
status: open
priority: high
labels: [sdlc, blueprint, review, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-01T00:22:55Z
updated: 2026-08-01T00:22:55Z
origin: conversation
---

## Description

## Description

Claude Code v2.1.219 began injecting a system-prompt section — registered
internally as `heron_brook` — whose payload is:

    Do not call the AgentTool unless the user requested it
    Do not use workflows or deep-research unless the user requested it

It is gated on the `opus_5_prompt_bundle` model capability, so it applies to
Opus 5 and not to Fable 5 or other models. It is still present in v2.1.220.
Tracked upstream as https://github.com/anthropics/claude-code/issues/80988
(open, no maintainer response); a prior instance in v2.1.150 was labeled
`bug` / `has repro` / `area:security` and closed with no visible response.

## Why this is jim's problem

Jim's quality machinery **is** delegation:

- `/jim:review`'s investigator fan-out
- `/jim:verify`'s judge rung
- `/jim:partition`'s per-group gatherer
- the `@jim:pm` / `@jim:architect` / `@jim:researcher` / `@jim:coder` personas

`docs/notes/20260728-id-coordination-issue-grouping.md` records the fan-out as
the single cheapest lever in the whole cluster: the same commit range reviewed by
its author produced `minor-drift` and 5 findings, while a ten-investigator
fan-out produced `major-drift`, 3 criticals and 15.

**Observed live during the C′-fix build.** A `/jim:verify --since platform` run
executed its judge rung inline because the directive suppressed the fan-out. It
reported 10 invariants, 0 violations. Re-run with the fan-out over the same code,
it returned **two** violations — one of them a shipped defect in the
`move-spec-dir` occupancy gate that let a cross-parent renumber land two
directories on one ordinal at rc 0, and one an invariant restatement that
overstated what the code guarantees. The inline pass had written both off as
holding.

## Why it is hard to notice

- The section is not in `CLAUDE.md`, `settings.json`, or any project file — it
  arrives in the system prompt, so from inside a session it is indistinguishable
  from an instruction the developer set.
- Transcripts do not record system prompts; the upstream reporter located it by
  running `strings` on the CLI binary.
- No supported opt-out: no settings key, no `CLAUDE_CODE_*` env var,
  `--exclude-dynamic-system-prompt-sections` does not cover it, and
  `DISABLE_GROWTHBOOK=1` makes it worse (the killswitch defaults to off).
  `CLAUDE.md` is reported as overridden.

## What jim can actually do

Jim cannot fix the harness, but it does not have to degrade silently:

1. **Document the standing-authorization phrase** in `WORKFLOW.md` — the
   directive is self-limiting ("unless the user requested it"), so an explicit
   request satisfies it. This is the cheap, reliable mitigation.
2. **Make the degradation loud.** `/jim:verify` and `/jim:review` already have a
   doctrine of naming every degradation (`UNSCOPED` floor, capped fan-out,
   appetite in force). A fan-out that did not run belongs in that same list —
   the run should say so in its report and, for verify, in its ledger counters,
   rather than presenting inline judgment as equivalent coverage.
3. Consider whether a skill whose contract depends on independent judgment
   should **refuse to report a clean result** when its fan-out was suppressed,
   rather than reporting `holds` on the author's own read.

Item 2 is the substantive one: the failure mode here is not that the fan-out was
unavailable, it is that its absence was invisible in the artifact.

## Sources

- https://github.com/anthropics/claude-code/issues/80988
- https://clauding.de/en/posts/claude-code-2-1-219-opus-5-default-bash-subagenten
