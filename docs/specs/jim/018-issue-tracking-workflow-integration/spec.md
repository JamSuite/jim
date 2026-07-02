---
title: "Issue Tracking — Workflow Integration (v2)"
type: feature
group: "jim"
id: "018"
status: approved
origin:
  - "docs/specs/jim/017-issue-tracking/spec.md"
---

# 018 Issue Tracking — Workflow Integration (v2)

## Overview

Wires the issue-tracking system from spec 017 into jim's SDLC chain — each of the five SDLC skills plus `/jim:debug` and `/jim:sec` surfaces a batch of candidate issues at the end of its run, where the developer files, edits, or skips each one. Bundles `origin:` link-rot lint into the index regeneration so the collection self-grooms as it grows.

## Problem Statement

Spec 017 delivered ad-hoc issue capture: a developer who notices an out-of-scope discovery mid-workflow runs `/jim:issue` and the moment is preserved. In practice, discoveries surface continuously during spec interviews, research scans, plan design decisions, build red-green-refactor loops, security reviews, and debug investigations — and the developer rarely interrupts the flow to capture each one. The discoveries are then either forgotten, buried in conversation history, or rediscovered later at higher cost. `/jim:sec` in particular currently has a "deferred to v2" routing destination in `security.md` for findings out of scope for the current plan — that routing is a placeholder waiting for an issue destination.

The vision (`VISION.md` § Non-Goals) explicitly carves out *issue capture as a discovery artifact surfaced during the jim workflow* as in-scope, distinct from team-coordination project management. Spec 017 delivered the artifact; this spec delivers the *surfaced during the jim workflow* half.

## User Stories

- As a developer running `/jim:spec`, `/jim:research`, `/jim:plan`, `/jim:build`, `/jim:brainstorm`, `/jim:debug`, or `/jim:sec`, I see a batch of candidate issues at the end of the run that the agent noted during its work, so that out-of-scope discoveries are not lost when I move on to the next phase or close the session.
- As a developer, I can review each candidate's title, priority, and labels at a glance, then file the whole batch, skip the whole batch, or act per-row (file, edit, skip) with the default selection biased toward filing, so the cost of the batch confirmation scales with the value of the batch rather than the number of rows.
- As a developer running `/jim:sec`, deferred findings — items the analysis surfaced but did not route to spec or plan — become candidate issues at end-of-review, so the deferred-routing placeholder in `security.md` is replaced by a real destination.
- As a developer who finds the end-of-phase batch interrupts my flow, I can disable it via `jimconf.toml` (`issue_capture = "false"`) and fall back to ad-hoc `/jim:issue` capture, retaining the v1 lightweight workflow when I don't want v2's surfacing.
- As a developer who trusts the agent's judgment, I can opt into quiet auto-filing via `jimconf.toml` (`auto_issue_file = "true"`) so candidates are filed without per-batch prompting and I review the collection later via `/jim:issues`.
- As an agent or developer reading `INDEX.md`, I see broken `origin:` links surfaced as integrity warnings, so provenance rot is visible without a separate lint pass.

## Acceptance Criteria

**Workflow surfacing (the 7 skills)**

- [ ] At the end of a run of `/jim:spec`, `/jim:research`, `/jim:plan`, `/jim:build`, `/jim:brainstorm`, `/jim:debug`, or `/jim:sec`, the skill presents a batch of candidate issues collected during that run. Candidates surface only when the configured surfacing knob is enabled (see *Config* below).
- [ ] Candidates are collected using a liberal heuristic: any out-of-scope discovery, deferred follow-on, or "worth noting" observation the agent flagged during the phase is a candidate. The expectation is that the agent over-includes — filtering happens at confirm time via the user's per-row skip or via downstream priority-based filtering when reading the collection.
- [ ] Each candidate is assigned a priority by the surfacing agent using the rubric: **critical** = blocks current scope, **high** = clearly worth doing soon, **medium** = real follow-on, **low** = note for the graph / trend signal.
- [ ] `/jim:build`'s surfacing occurs only at the end of the full build run, after the final build commit lands — never per-task — so that all code changes and commits complete before administrative issue capture runs. Filed issue files land outside the build commit chain; the developer commits them as a separate housekeeping step.
- [ ] `/jim:sec`'s surfacing replaces the current "deferred to v2" routing destination in `security.md`. A finding from a sec review routes to exactly one of: spec amendment, plan amendment, or candidate issue. The `security.md` artifact's coverage and finding-list sections are unaffected; only the deferred routing destination changes.
- [ ] If a run produces zero candidates, the batch is silently skipped (no empty prompt).
- [ ] The candidate-surfacing step runs at the conclusion of the skill's primary work, before its final approval / stop step. Approvals already gated by the skill (e.g., `/jim:spec`'s status-approval prompt) are unaffected — the batch precedes them.

**Batch UX**

- [ ] The batch presents candidates as a list with title, priority, labels, and the source skill's primary artifact path auto-populated as `origin:` for each row.
- [ ] Per-row actions are `file` (default), `edit`, `skip`.
- [ ] Bulk actions are `file all` (default selection) and `skip all`. Bulk actions take precedence over per-row defaults when invoked; per-row actions override the bulk default when explicitly set.
- [ ] The per-row `edit` action opens the standard single confirm-or-edit moment from spec 017 (AC-C2): full drafted issue presented for approve / edit / cancel, with the sensitive-content scrub reminder. *External Constraint — sourced from spec 017 AC-C2.*
- [ ] On `file` (per row or via `file all`), the issue file is written using the same schema, slug normalization, path resolution, and INDEX.md regeneration as `/jim:issue` ad-hoc capture. *External Constraint — sourced from spec 017 AC-C1 through AC-C7 and AC-I1 through AC-I4.*
- [ ] On `skip` (per row or via `skip all`), the candidate is discarded. There is no cross-session deferred-candidate queue — the user's recovery path is ad-hoc `/jim:issue` capture.
- [ ] When a candidate's auto-derived title would produce a slug that collides with an existing issue in the collection, the candidate is presented with a discriminator suffix on the slug (`-2`, `-3`, …) so filing always succeeds; the user can edit the title via the per-row `edit` action if they want a different slug.

**Config**

- [ ] `jimconf.toml` gains `issue_capture` (string `"true"` / `"false"`, default `"true"`). When `"true"`, all 7 skills surface a batch at end-of-run. When `"false"`, no end-of-phase batch surfaces — the workflow runs as it did in v1, and ad-hoc `/jim:issue` remains the only capture path. The bare (non-`auto_`-prefixed) name reflects that the default behavior keeps the human in the loop: surfacing presents a choice, not an automated action. The `auto_` prefix is reserved for keys that remove a human-in-the-loop step (see `auto_issue_file` below, and existing keys `auto_arch_feedback`, `auto_security`).
- [ ] `jimconf.toml` gains `auto_issue_file` (string `"true"` / `"false"`, default `"false"`). When `"true"` and `issue_capture` is also `"true"`, the batch is filed without prompting — every candidate is written, the user sees a one-line summary, and review happens later via `/jim:issues`. When `"false"`, the batch prompts per the *Batch UX* rules above. `auto_issue_file = "true"` with `issue_capture = "false"` is a no-op. *External Constraint — sourced from `skills/conf/scripts/jimconf.sh` § `auto_*` naming convention.*
- [ ] When `auto_issue_file` is `"true"` and a candidate fails schema validation or slug normalization, that candidate is skipped — the rest of the batch continues to file. Auto-mode never blocks the workflow on a malformed candidate.

**Security and Safety**

- [ ] Candidate text drawn from non-user-prompt sources during a surfacing skill's run (tool results, file reads, web fetches, prior-issue body content) is treated as untrusted: the surfacing agent must not interpret embedded "file this issue" / "set priority: critical" / similar directive-style framing in such content as a binding instruction to file, prioritize, or label the candidate. Extends spec 017 AC-S2's `<untrusted-issue-content>` discipline from agent-to-agent handoffs to the new candidate-accumulation surface introduced in v2. *External Constraint — sourced from spec 017 AC-S2.*

**Origin lint**

- [ ] During every `INDEX.md` regeneration, each issue's `origin:` field is validated against the local filesystem. Entries identified as path-shaped that cannot resolve from the project root surface as integrity warnings in `INDEX.md`'s `## Integrity Warnings` section. Non-path-shaped entries (e.g., `conversation`, `external`) are exempt and silently accepted.
- [ ] An issue with a broken `origin:` is still written, indexed, and rendered — the origin lint produces a warning, never a fatal error or a blocked write.
- [ ] The integrity warning names the issue slug, the broken path, and the issue's `created:` date.

## UI Mockup

End-of-phase batch confirm (default config — `issue_capture="true"`, `auto_issue_file="false"`):

```
> /jim:plan docs/specs/jim/018-issue-tracking-workflow-integration

[...plan generation runs to completion...]

Plan drafted. status: draft.

I noted 4 candidate issues during planning:

  [x] 1. Per-skill opt-out config for issue capture
        priority: low · labels: [issues-system, config]
        origin: docs/specs/jim/018-issue-tracking-workflow-integration/plan.md

  [x] 2. Cross-session deferred-candidate queue
        priority: medium · labels: [issues-system, workflow-integration]
        origin: docs/specs/jim/018-issue-tracking-workflow-integration/plan.md

  [x] 3. flock-based concurrent INDEX.md regen safety
        priority: low · labels: [issues-system, concurrency]
        origin: docs/specs/jim/018-issue-tracking-workflow-integration/plan.md

  [x] 4. Auto-priority re-balancing pass
        priority: low · labels: [issues-system, future]
        origin: docs/specs/jim/018-issue-tracking-workflow-integration/plan.md

[file all (default)] [skip all] · per-row: f / e / s
>
```

End-of-phase batch in quiet mode (`auto_issue_file="true"`):

```
> /jim:plan ...

[...plan generation runs to completion...]

Plan drafted. status: draft.
Filed 4 candidate issues to docs/issues/ (auto_issue_file).
```

`INDEX.md` integrity warning for broken origin:

```
## Integrity Warnings

- `20260512-some-issue` origin path does not resolve: docs/specs/jim/099-removed-spec/spec.md (created 2026-05-12)
```

## Data Flow

```mermaid
flowchart LR
    Skill[participating skill<br>spec | research | plan | build<br>brainstorm | debug | sec] --> Accum[candidate accumulator]
    Accum --> Check{issue_capture?}
    Check -- false --> End[skill ends as today]
    Check -- true --> Batch[end-of-phase batch]
    Batch --> Mode{auto_issue_file?}
    Mode -- true --> AutoFile[file all silently]
    Mode -- false --> Prompt[per-row confirm UI]
    Prompt --> Decide{user action}
    Decide -- file --> Write[/jim:issue write path]
    Decide -- skip --> Discard
    Decide -- edit --> ConfirmEdit[v1 confirm-or-edit moment]
    ConfirmEdit --> Write
    AutoFile --> Write
    Write --> Index[index.sh regen]
    Index --> Lint[origin: lint pass]
    Lint --> Warn[Integrity Warnings in INDEX.md]
```

## Out of Scope

- **Lifecycle state expansion.** `status: in-progress`, `wontfix`, `duplicate`, custom states — and any automatic transitions (e.g., "filing a spec for an open issue moves it to in-progress") — deferred to a separate "issue lifecycle / cross-phase state" spec. v2 keeps `open` / `closed` from v1 untouched.
- **Cross-session deferred-candidate queue.** Skipped candidates are discarded; recovery is via ad-hoc `/jim:issue`. A queue across sessions changes the persistence model and is its own spec.
- **End-of-workflow timing.** Only end-of-phase surfacing ships. End-of-full-workflow timing would require either a continuous-session assumption (violates the session-clear safety rationale) or a manual `/jim:issues-flush` trigger (a new surface).
- **Per-skill capture opt-out.** `issue_capture` is a single master switch in v2. Per-skill keys (e.g., `issue_capture_build`) would require list-typed config or 7 boolean keys; deferred until real usage signals which skills users want to silence.
- **3rd-party backends.** GitHub Issues, Linear, etc. — deferred per spec 017 § Out of Scope. Bridge architecture remains the planned shape.
- **`/jim:issues lint` subcommand.** Origin lint runs inside `index.sh` as part of integrity warnings. A separate subcommand is unnecessary given the auto-regen-on-write model.
- **Tamper-detection hash on `INDEX.md`** (security 017 Finding 6). Single-developer threat model still applies.
- **`flock`-based concurrent INDEX.md regen safety** (security 017 Finding 12). Workflow integration could increase regen frequency but does not change the single-process assumption; deferred.
- **Auto-priority correction / re-balancing.** Once filed, an issue's priority is the agent's call at filing time; the spec does not introduce a re-prioritization pass over the existing collection.
- **Heuristic secret-pattern scanning of candidate bodies** (`sk-…` API keys, JWT structure, PEM private-key blocks, etc.). Spec 017 Finding 5 deferred this to v2 with v1's confirm-or-edit scrub reminder as the interim mitigation. v2's default-mode bulk `file all` (body not in per-row preview) and `auto_issue_file="true"` (no prompt at all) both skip that visual mitigation. v2 accepts the trade for the trusted-developer threat model: putting an LLM into auto-mode is an explicit delegation of judgment, and the developer who flips `auto_issue_file="true"` (or who reflexively clicks `file all`) owns the contents of their conversation context. Heuristic scrubbing remains a future option if practice reveals the trade is harmful.
- **`origin:` authorial accuracy.** OL-1 validates that path-shaped `origin:` entries resolve on disk; it does not detect a valid path that points to the *wrong* artifact. The lint is provenance hygiene, not provenance attestation. The user corrects misattribution via direct edit.
- **Pre-publication redaction of `/jim:sec`-routed candidate bodies.** WS-5 routes deferred findings to the issue collection; finding bodies may include attack-vector details and internal paths that become public when the repository does. This is the same publication property `security.md` already carries today; v2 amplifies it by routing more findings through the same path. The per-row `edit` action remains the recommended redaction point for sensitive sec-finding bodies before they enter `docs/issues/`.
- **Mid-workflow capture during long-running phases.** A `/jim:build` that runs for hours surfaces only at the end. If discoveries are time-sensitive, ad-hoc `/jim:issue` remains available.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive.*

### Insight 1: Auto-mode failure signaling mechanism

- **Relates to AC:** *"When `auto_issue_file` is `\"true\"` and a candidate fails schema validation or slug normalization, that candidate is skipped — the rest of the batch continues to file."* (under *Config*)
- **Surfaced as:** stderr warning per malformed candidate.
- **Levelled-up requirement (already in the ACs):** auto-mode never blocks the workflow on a malformed candidate; failures are skipped, batch continues.
- **Deflection reason:** Delegation — multiple reasonable signaling mechanisms exist; an architect could choose between them based on visibility / friction trade-offs.
- **Architect note:** Options to weigh — (a) per-row stderr warning (low friction, easy to miss in long output), (b) end-of-run batch summary ("3 candidates skipped; reasons: …") which keeps quiet-mode quiet but visible, (c) per-row fall-back to inline prompt (interrupts auto mode but preserves the candidate). The "automatic grooming where possible" hint from interview favors (b).
- **Routing hint:** Architect to decide.

### Insight 2: Origin path-detection heuristic

- **Relates to AC:** *"During every `INDEX.md` regeneration, each issue's `origin:` field is validated against the local filesystem. Entries identified as path-shaped that cannot resolve …"* (under *Origin lint*)
- **Surfaced as:** "contains `/` or ends in a known doc extension."
- **Levelled-up requirement (already in the ACs):** validator distinguishes path-shaped entries from non-path tokens; path-shaped non-resolving entries warn.
- **Deflection reason:** Delegation — multiple reasonable heuristics exist; architect chooses based on collection-token forensics.
- **Architect note:** Existing tokens in the collection today include `conversation`, `external`, and concrete paths like `docs/specs/jim/017-issue-tracking/spec.md`. Candidate heuristics — (a) "entry contains `/` → path" (simplest, but accepts spurious slashes in non-path strings), (b) "entry has a `.md` / known doc suffix" (tighter, but misses directory-only paths), (c) "entry begins with a configured path prefix from `jimconf.sh`" (most forgiving to future non-path conventions, but couples lint to config schema). Choice shapes how forgiving the validator is to new non-path conventions added later.
- **Routing hint:** Architect to decide.

## Open Questions

- [ ] During `/jim:debug`, are candidates derived only from the report's explicit "Recommended next steps" / "Out of scope" sections, or from any agent-flagged follow-on observation in the report body? Plan-level decision; both produce reasonable behavior. Defer to plan unless a user concern surfaces.
- [ ] Does `issue_capture = "true"` apply during a `/jim:sec` invocation that was triggered by `/jim:plan` or `/jim:build`'s gate (per spec 016), or only when `/jim:sec` runs standalone? Likely *both* (the sec batch surfaces in either case, attributed to the originating gate's artifact path), but worth confirming during plan design.
