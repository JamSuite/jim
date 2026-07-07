---
title: "Blueprint-surface approval gates can present content invisibly"
type: bug
group: "jim"
id: "040"
status: approved
---

# 040 Blueprint-surface approval gates can present content invisibly

## Overview
jim's blueprint-surface gates instruct the agent to "present X and wait for
approval" without defining a format, so long content collides with the
harness's rendering limits and the developer can approve content they never
saw — hollowing jim's hard human gates. This fix defines one canonical
gate-presentation rule and references it from every affected gate site.

## Defect Profile
- **Steps to Reproduce:**
  1. Run a blueprint-surface gate that must present long content for approval
     with auto-write off — e.g. `/jim:partition` greenfield (which materializes
     a project map and per-group blueprints through the blueprint surface), or
     `/jim:blueprint <group>` with `auto_blueprint` unset, so a ~100-line group
     blueprint or the full project map requires developer approval.
  2. Follow the pattern the current instructions invite: compose the full draft
     as chat text and, in the **same turn**, call `AskUserQuestion` to ask for
     approval.
- **Actual Behavior:** The developer sees only the bare approval question. The
  draft — assistant text emitted *between* the message and the tool call — does
  not reliably render, because in Claude Code's terminal only a turn's final
  message is dependable. Retrying by embedding the draft in an `AskUserQuestion`
  option `preview` truncates past ~20 lines. In an observed run the project-map
  M2-create gate was approved this way — very possibly without the draft ever
  rendering — degrading a hard gate to a rubber-stamp with no one noticing.
- **Expected Behavior:** At every blueprint-surface gate, the developer can
  reliably see the full content (or a path to it) and a faithful compact
  summary before answering the approval question, so the gate is a real review.
  jim's strongest safety property — "nothing is written before approval",
  "creation always prompts" — is trustworthy by instruction, not by luck.
- **Environment:** Claude Code terminal; jim blueprint surface (`/jim:blueprint`
  and `/jim:partition`, which delegates every write through it). Observed
  first-hand on the specs 038–039 `/jim:partition` greenfield run, 2026-07-07.

## Acceptance Criteria

**Canonical rule**
- [ ] A single gate-presentation rule is defined **once** in a shared reference
      document and referenced **by path** from every affected site — never
      restated inline per site (mirrors the § 7a shared-contract pattern where
      `skills/issue/SKILL.md` owns the rule and other skills point at it).
- [ ] The rule requires, for approval of content beyond a short length
      threshold, all four of: (a) the full draft/diff is written to a
      reviewable file and the developer is given its path; (b) a compact chat
      summary accompanies it that reproduces the **load-bearing content
      verbatim** — at minimum the Invariants table, and for map updates the
      graded downgrade list — rather than paraphrasing it; (c) the approval
      request is the turn's **final plain-text message**, with no tool call
      (including `AskUserQuestion`) emitted after the presented content in the
      same turn; (d) no content beyond the threshold is placed in an
      `AskUserQuestion` option preview.

**Coverage**
- [ ] Every blueprint-surface gate that can present beyond-threshold content
      references the canonical rule: blueprint generate/update (Step 5), the
      Step 4a downgrade prompts, the U2a regen prompt, the U4 targeted diff, the
      U3a violation fork, the reconcile-findings presentation, map create/update
      (M2), the partition proposal + hard gate, and Retire mode.

**Safety properties preserved**
- [ ] "Nothing is written before approval" still holds across a **decline**: if
      a gate writes a reviewable file before approval, declining removes it — no
      orphaned pre-approval artifact survives a decline.
- [ ] The fix introduces no data-loss path: an approved-by-summary write never
      persists empty or truncated content when the reviewable file is cleared —
      the approved draft is written from content the agent still holds, and any
      file-sourced write is guarded against an empty source before it is
      ledgered or committed.
- [ ] The reviewable-file write applies the same secret-scrub and
      untrusted-evidence discipline as the final artifact (sec Finding 1): a
      diff- or evidence-derived reviewable file is scrubbed before it is written
      (secret-looking values → `secret-looking value at <path:line>`), and the
      verbatim summary reproduces already-scrubbed content, never raw. The
      reviewable file lives in a session/repo-scoped location (scratchpad or the
      in-repo target path), never a shared or world-readable one.
- [ ] Untrusted evidence (the U3a violation fork, reconcile findings, the
      partition proposal) stays inside its delimited block in **both** the
      reviewable file and the chat summary (sec Finding 2) — the "verbatim"
      requirement of AC 2b never re-frames untrusted evidence as the agent's own
      prose.

**Regression**
- [ ] A build-gate check fails if any affected gate site no longer references
      the canonical rule (the enumerated sites are the checked set).
- [ ] The `meta-skill` and `meta-agent` validation checklists include a
      gate-presentation item enforcing the rule reference at new or updated gate
      sites.
- [ ] Regression test covers the reported scenario.

## Out of Scope
- Non-blueprint-surface gates (`/jim:spec`, `/jim:plan`, `/jim:review`,
  `/jim:build`, `/jim:debug`, `/jim:research`, `/jim:sec`). The same
  "present X and wait" exposure exists there but is deliberately deferred; it is
  captured as a follow-up, not fixed here.
- The issue candidate-batch edit flow ("present the full drafted issue inline",
  § 7a) across the surfacing skills — a distinct, established contract that
  presents a single, usually-short issue.
- Changing Claude Code's harness rendering or `AskUserQuestion` truncation — it
  is outside jim's control; the rule adapts to it rather than fixing it.
- Replacing `AskUserQuestion` for short, structured choices — it remains valid;
  the rule governs only long-content approval gates.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point to
evaluate, not a directive.*

### Insight 1: reviewable-file location

- **Relates to AC:** *"the full draft/diff is written to a reviewable file"* (AC 2a)
- **Surfaced as:** whether the reviewable file lives in the session scratchpad
  or is the target path written in place.
- **Levelled-up requirement (already in the ACs):** the developer is given a
  path to the full content before approving.
- **Deflection reason:** Delegation
- **Architect note:** both options were weighed during scoping. Scratchpad is the safer default
  but ephemeral and needs a decline-cleanup. Writing the target path in place is
  clean when nothing is ledgered/committed until approval (blueprint generates
  qualify), but a decline must then delete it — which the current "write
  nothing" decline discipline does not contemplate (see AC on decline).
- **Routing hint:** Architect to decide

### Insight 2: the length threshold

- **Relates to AC:** *"content beyond a short length threshold"* (AC 2)
- **Surfaced as:** the ~20-line figure the developer observed.
- **Levelled-up requirement (already in the ACs):** the rule fires for content
  long enough to collide with the harness.
- **Deflection reason:** Constraint-Sourcing
- **Architect note:** ~20 lines traces to the observed `AskUserQuestion` preview
  truncation point, not a general principle. The architect fixes the exact
  trigger wording (a hard line count vs. "more than a screenful").
- **Routing hint:** Architect to decide

### Insight 3: draft ephemerality guard

- **Relates to AC:** *"the fix introduces no data-loss path"* (safety AC)
- **Surfaced as:** during the observed session a host reboot cleared `/tmp`, a
  draft file vanished, and a `sed draft > spec.md` pipeline briefly committed an
  empty `spec.md` (repaired by amend because the draft was still in context).
- **Levelled-up requirement (already in the ACs):** an approved-by-summary write
  never persists empty/truncated content.
- **Deflection reason:** Delegation
- **Architect note:** two mitigations to weigh — keep the approved draft in
  context so a cleared temp file can't silently empty a write, and guard any
  file-to-file write (`test -s`) before ledgering/committing.
- **Routing hint:** Architect to decide

### Insight 4: canonical rule's home and name

- **Relates to AC:** *"defined once in a shared reference document"* (AC 1)
- **Surfaced as:** the rule spans two skills (`blueprint` and `partition`).
- **Levelled-up requirement (already in the ACs):** one shared doc, referenced
  by path, not restated per site.
- **Deflection reason:** Delegation
- **Architect note:** § 7a lives in `skills/issue/SKILL.md` because issues are
  that skill's domain. Gate-presentation has no equally-obvious owner, but
  `partition` materializes every write through the blueprint surface, so
  `blueprint` is the natural home (e.g. a `references/gate-presentation.md`).
- **Routing hint:** Architect to decide

### Insight 5: the session's working improvisation (verbatim starting sketch)

- **Relates to AC:** *"the rule requires … all four of"* (AC 2)
- **Surfaced as:** the pattern that carried the remaining five blueprints + map
  + 16 issues once adopted: draft file at a stable path → chat summary of
  Responsibility (1 line), Provides (count + criticals), Requires (count +
  cycles noted), Invariants (id/criticality/check per row), withheld-as-violated
  list → final message ends with "Write it to `<path>`?" → developer replies in
  chat.
- **Levelled-up requirement (already in the ACs):** file + verbatim-preserving
  summary + final plain-text question.
- **Deflection reason:** Delegation
- **Architect note:** a proven concrete shape for the rule; the architect
  generalizes it across the gate sites (blueprint face summary, map summary,
  partition evidence tables).
- **Routing hint:** Architect to decide

## Open Questions
- [ ] Reviewable-file location — scratchpad (safer, needs decline cleanup) vs.
      target-path-in-place (clean until commit, decline must delete). Resolve in
      the plan (Insight 1).
- [ ] Exact length threshold and its wording (Insight 2).
