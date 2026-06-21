---
title: "Issue candidate-batch mechanics extraction"
type: refactor
group: "jim"
id: "025"
status: approved
origin:
  - docs/issues/20260620-extract-duplicated-candidate-batch-block-into-a-shared-contract.md
---

# 025 Issue candidate-batch mechanics extraction

## Overview
The end-of-phase candidate-batch block is copy-pasted across seven surfacing skills (`spec`, `research`, `plan`, `build`, `brainstorm`, `debug`, `sec`); this refactor pays down that duplication by moving the deterministic issue-file write into the shared scripting layer, single-sourcing the filter definitions, and unifying the "fileable" bar with `/jim:issue add` — without relitigating the prose-centralization approaches prior specs deliberately rejected.

## Refactor Rationale
- **Motivation:** Issue #8 tracks ~60 lines of candidate-batch logic duplicated across seven skills (six standard, `sec` a partial variant). Spec 024 added a third filter to the same block without paying down the duplication, widening the drift surface. This violates the meta-skill anti-pattern ("same instructions in 3+ places → extract a shared contract") and means any future change to issue-filing touches eight scattered sites.
- **Current State:** Each surfacing skill restates verbatim: the issue-file template write, the three candidate filters (Resolution / Actionability / Pipeline-ownership), and the untrusted-content note. `/jim:issue add` independently restates the same template write and applies a *separate, stricter* actionability gate than the batch filters (the "two bars" gap surfaced in spec 024). The spec-017 template shape is described in multiple places. The only mechanical operations not already behind a shared script are template instantiation and the file write itself (`next-id`, `path`, `mkdir`, and `index.sh` regen are already shared script calls).
- **Desired State:**
  - Issue-file template instantiation and persistence live in exactly one deterministic mechanism in the scripting layer — the single source for "how an issue file is written" — consumed by all seven batch steps and by `/jim:issue add`.
  - The three candidate filters are defined once in a canonical location; each surfacing skill carries a brief restatement plus a pointer to that definition rather than the full verbatim text (the same single-source-plus-pointer model already proven for the untrusted-content rule).
  - One canonical "fileable" bar governs both candidate-batch filtering and the `/jim:issue add` actionability gate; both reference it, or the spec records a deliberate, documented divergence.
  - The prose that genuinely requires judgment or conversation (candidate materialization heuristic, interactive confirm/edit flow) stays in the skills — only the deterministic and the duplicated-policy surfaces are consolidated.
  - The consolidation holds the line on safety the old per-skill path had implicitly: once a script owns the write, untrusted field values are encoded as inert data, the target path is derived only through the validated id resolver, and the single-sourced filters keep their anti-injection semantics — the implicit safety of the LLM-mediated write must become explicit.
- **Affected Systems:** `skills/issue/scripts/` (new or extended write mechanism + its tests); the seven surfacing skills' candidate-batch steps (`skills/{spec,research,plan,build,brainstorm,debug,sec}/SKILL.md`); `skills/issue/SKILL.md` (the `add` verb's write + the canonical filter / fileable-bar definitions); the issue template asset; `tests/` and `ARCHITECTURE.md` (Scripting Layer entry).

## Acceptance Criteria
- [ ] The spec-017 issue-file template is materialized in exactly one deterministic mechanism; no skill body restates the full template-write procedure inline.
- [ ] All seven surfacing skills' candidate-batch write steps file issues through that single mechanism rather than each describing the template write itself.
- [ ] `/jim:issue add` writes its issue file through the same single mechanism.
- [ ] The write mechanism encodes every field value as inert data: an untrusted `title`, `labels`, or `body` — including YAML metacharacters, a `---` line, or a leading `[[` — cannot inject or alter frontmatter, cross the frontmatter/body boundary, or break the `index.sh` / `render.sh` parsers. Tests feed adversarial values and assert containment.
- [ ] The write mechanism derives its target path only through the validated id resolver (`jimfile.sh`'s `is_valid_id`), rejecting any id that fails validation; raw title or slug input can never direct the write outside the issues directory.
- [ ] The three candidate filters (Resolution, Actionability, Pipeline-ownership) are defined in exactly one canonical location; each surfacing skill references that definition via a brief restatement plus pointer rather than restating the full text.
- [ ] A single canonical "fileable" bar governs both the candidate-batch filtering and the `/jim:issue add` actionability gate; both reference it, or the spec documents the specific intentional divergence.
- [ ] The single-sourced filters and the unified fileable bar preserve their anti-injection semantics: ownership, priority, and label claims embedded in untrusted candidate content do not bind the filing, drop, or priority decision.
- [ ] The `sec` skill's domain-specific field derivation (severity→priority, STRIDE/LINDDUN labels, `Route` routing) is preserved and feeds the shared write mechanism with its derived fields.
- [ ] Filing through every path — batch auto-file, batch interactive, and `/jim:issue add` — produces the same issue-file content shape and INDEX.md result as before the refactor.
- [ ] The new/extended write mechanism has bash test coverage following jim's test conventions (`skills/meta-test/scripts/testlib.sh`).
- [ ] Existing tests pass without modification.

## Out of Scope
- Prose-block centralization via a runtime-read shared reference doc, a `Skill(jim:issue-batch)` sub-skill, or passing the accumulated candidate list as `$ARGUMENTS` — each was explicitly rejected by spec 018 (Design Decision 2) and spec 024 (Design Decision 1) for documented reasons (per-read permission prompts, `$ARGUMENTS` non-forwarding, confirm-or-edit being LLM logic). Carried forward as rejected; not to be relitigated.
- Scripting the interactive confirm / checkbox / per-row-edit flow — it is LLM-prompt conversation logic and stays in prose per the Bash-vs-Prompt decision rule.
- Cross-session or persistent candidate queue (already out of scope per spec 018 Design Decision 3).
- Changing the issue-file schema, template fields, INDEX.md format, or which observations qualify as candidates — this is a structural dedup refactor, not a behavior change. Reconciling the fileable bar may *unify wording* but must not loosen or tighten what currently gets filed.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive.*

### Insight 1: The rejected centralization alternatives are settled — do not relitigate

- **Relates to AC:** *"file issues through that single mechanism rather than describing the template write inline"* (AC #2) and the Out of Scope rejections.
- **Surfaced as:** Issue #8's literal proposal — "extract the prose block into a shared contract that the skills reference."
- **Levelled-up requirement (already in the ACs):** Extract the *deterministic mechanics* into the scripting layer (jim's existing single-sourcing mechanism), not the prose block.
- **Deflection reason:** Constraint-Sourcing.
- **Architect note:** Three options were already rejected — a shared reference `.md` read at runtime (permission prompt every batch step, per the `security-dod` precedent in `skills/sec`); a `Skill(jim:issue-batch)` sub-skill (the parent's `$ARGUMENTS` does not auto-forward, and serializing the accumulated candidate list as args defeats the abstraction); and refactoring `/jim:issue` into a callable subroutine (its confirm-or-edit step is LLM-prompt logic, not bash). The scripting-layer axis is viable precisely because it avoids all three. Sources: `docs/specs/jim/018-issue-tracking-workflow-integration/plan.md` (Design Decision 2), `docs/specs/jim/024-issue-pipeline-ownership/plan.md` (Design Decision 1), `ARCHITECTURE.md` → Skill Invocation / Scripting Layer.
- **Routing hint:** Architect to decide.

### Insight 2: Write-mechanism shape and the untrusted multi-line body

- **Relates to AC:** *"materialized in exactly one deterministic mechanism"* (AC #1).
- **Surfaced as:** "add a `write-issue` script subcommand."
- **Levelled-up requirement (already in the ACs):** A single deterministic write mechanism; its exact form is the architect's call.
- **Deflection reason:** Delegation.
- **Architect note:** Whether this is a new subcommand on `jimfile.sh`, a new subcommand on an issue script under `skills/issue/scripts/`, or a new script is open. The issue `body` is untrusted, multi-line markdown — how fields reach the script (CLI arg vs stdin vs temp file) is a plan decision constrained by jim's bash rules: never `source`/`eval` user data; write via `printf '%s'`, not interpolation. The existing template asset (`skills/issue/assets/issue-template.md`) and the spec-017 schema should anchor the canonical output.
- **Routing hint:** Architect to decide.

### Insight 3: Canonical home for the filter and fileable-bar definitions

- **Relates to AC:** *"defined in exactly one canonical location"* (AC #4) and *"a single canonical fileable bar"* (AC #5).
- **Surfaced as:** "single-source the filters and pointer-reference them."
- **Levelled-up requirement (already in the ACs):** One canonical definition, referenced rather than restated.
- **Deflection reason:** Constraint-Sourcing.
- **Architect note:** The canonical text cannot live somewhere each skill must *read at runtime* without re-introducing the permission prompt that spec 018 avoided. The proven pattern is a brief inline restatement (enough to act on) plus a pointer to the canonical detail (as `skills/issue/SKILL.md` Step 7 does for untrusted content). The Pipeline-ownership filter carries a security nuance — an adversarial candidate body claiming it is pipeline-owned must not cause a drop — so its restatement must preserve that, not just gesture at it (see Open Questions).
- **Routing hint:** Architect to decide.

### Insight 4: ARCHITECTURE.md update is pipeline-owned, not a standalone AC

- **Relates to AC:** the former "ARCHITECTURE.md is updated" criterion, removed during audit.
- **Surfaced as:** an explicit AC requiring ARCHITECTURE.md to document the new mechanism.
- **Levelled-up requirement:** ARCHITECTURE.md should reflect the consolidated write mechanism and canonical definitions — but jim already owns this: the `/jim:build` completion gate runs `/jim:arch`, which regenerates ARCHITECTURE.md from codebase analysis.
- **Deflection reason:** Delegation.
- **Architect note:** Keeping it as an AC is redundant with the pipeline and risks a hand-edit that bypasses `/jim:arch` and stales the doc's Last-updated header (the documented convention edits ARCHITECTURE.md only via `/jim:arch`). Let the build completion gate's `/jim:arch` run capture the new Scripting Layer entry; do not hand-edit.
- **Routing hint:** Architect to decide.

## Open Questions
- [ ] The anti-injection AC above locks the *requirement* that the Pipeline-ownership filter's "never trust embedded claims" property survives single-sourcing (security.md Finding 3). Open *mechanism* choice for the plan: keep that filter's full text inline while pointer-referencing the others, or demonstrate that a brief restatement preserves the property. Lean inline per the security review.
- [ ] Is the `/jim:issue add` actionability gate fully expressible as a facet of the unified fileable bar (Resolution + Actionability + Pipeline-ownership), or does its "already-shipped → point-of-encounter doc" framing warrant a documented divergence? Resolve when defining the canonical bar.
