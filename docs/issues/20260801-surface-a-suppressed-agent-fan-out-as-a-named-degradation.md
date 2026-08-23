---
id: 20260801-surface-a-suppressed-agent-fan-out-as-a-named-degradation
num: 188
title: "Surface a suppressed agent fan-out as a named degradation"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [sdlc, blueprint, review, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-01T00:22:55Z
updated: 2026-08-05T08:25:18Z
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

## Resolution (2026-08-05)

All three proposed actions delivered, plus two doors the issue did not name.

**Item 1 — the standing-authorization phrase is documented.** `WORKFLOW.md` gains
an `## Operating Notes` → *Authorizing the agent fan-outs* section carrying the
phrase and a table of what each phase does when its fan-out cannot be dispatched;
`README.md` gains a sibling `## Authorizing the fan-outs` section, deliberately
outside `## Permissions` because this is a system-prompt behavior and not a
permission anything in `settings.json` can grant. Both spellings of the phrase
are pinned identical by test.

**Item 2 — the degradation is loud, in the report and on the ledger.** Each
surface names it in its own established degradation vocabulary rather than
gaining a new mechanism: `/jim:verify`'s 9b close-out list, `/jim:review`'s Step-8
composition and both template Coverage pick-lists, and the two reference
methodologies' close-out lists. Both skills' `finished` events now carry
`undelegated=<n>`, recorded **always** so a `0` distinguishes a whole run from a
record predating the counter. No `jimledger.sh` change was needed — `cmd_event`
joins `k=v` tokens verbatim with no allowlist. The counter deliberately does not
reach the `metrics` channel, whose fixed, shape-validated key set exists to keep
ledger text out of mined values; `/jim:ledger events` surfaces it already.

**Item 3 — settled as yes, and it was the cheapest part.** Verify's outcome
vocabulary already had the right home: `failed` means *could not check*. So an
invariant whose judge was never dispatched is `failed` with reason `undelegated`,
never `holds` — the honest result, in-idiom, with no new outcome invented. An
inline reading may still raise a `violated` (a weaker method that finds something
has still found it) but can never produce a `holds`. `--retirement` routes the
same case to its existing fail-closed `inconclusive` bucket. Appetite and the cap
stay the only two ways a run goes unjudged and remains whole.

**Two doors the issue did not name.** Its own list stopped at review and verify:

- **`/jim:issue insights` — a refusal, not a disclosure.** The delegation there
  is a capability boundary, not a quality lever: the `issue` blueprint declares
  `insights-capability-boundary` (`high`) — synthesis happens only in the
  write-free analyst, and the main agent reads no bodies. A suppressed dispatch
  does not merely thin that verb, it *violates a declared invariant*. `insights`
  now reports the analyst unavailable and stops.
- **`/jim:partition` — the gatherer is a precondition.** The skill states the cap
  "bounds concurrency, never coverage", so it had no concept of reduced coverage
  at all and a suppressed gatherer was doubly invisible. An ungathered run now
  records no gatherer-marked invariant and does not carry ungathered evidence to
  its human gate.

Adjacent, fixed in passing: `/jim:plan` was the one persona-spawn site with no
unavailability fallback where its three `meta-*` siblings all have one.

**Pinned mechanically, not by convention** — `tests/fanoutdisclosure.sh`, three
cases, all nine mutations red. The counter case sweeps **by rule rather than by
site**: every `verify finished` / `review finished` recitation in the skill,
reference, asset, and agent corpus must carry `undelegated=`, so a *new*
recitation added later without it fails (mutation M3 proves this — pinning the
known sites would not have caught it). Deliberately not covered: `/jim:research`'s
`Agent(Explore)`, where delegation is a cost lever with no independence claim to
lose, and the persona routing sites, which already name their fallbacks.

Not done, and deliberately: no blueprint invariant was added. The natural one
would assert that a phase resting on delegated judgment never reports a clean
result from inline judgment — worth having, but it is a group-ownership decision
and a `/jim:blueprint` write, so it belongs in a pass that is scoped for it.
`ARCHITECTURE.md` → Subagent Delegation likewise wants a fourth bullet, and that
regeneration is already scheduled in B″'s docs pass.
