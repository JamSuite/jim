# Brainstorm: Bash scripts in jim plugin — should @jim:meta know about them?

*2026-05-05*

## Origin question

When 001-meta was written, jim didn't have any bash scripts. Skills were pure prompt artefacts. Then 007-meta-test, 008-jimconf, and 009-jimfile introduced a deterministic scripting layer (`skills/*/scripts/*.sh`) — and the meta agent / meta-skill / meta-agent never got told that this is now a thing.

Two threads to pull on:

1. **Documentation drift.** Should 001-meta's spec, research, plan be updated retroactively? Should `agents/meta.md`, `skills/meta-skill/`, `skills/meta-agent/` learn how to handle skills that have a `scripts/` directory?
2. **Convention legitimacy.** We picked bash on a hunch ("lowest common denominator", "no third-party deps", "future-proof for Codex/Gemini"). We never validated that. Is there research/evidence that bash is genuinely the right floor — or did we cargo-cult it?

## Open questions to think through

- When is a bash script the right tool vs. a prompt? Is there a crisp decision rule?
- Is bash actually the LCD across Codex / Gemini CLI / other coding agents — or is something else (Python? a sandboxed JS runtime? POSIX shell only?) closer to universal?
- What guardrails should @jim:meta apply if a future skill spec asks for a `scripts/` directory? (e.g. enforce CLAUDE.md's "no `set -e`", "no third-party deps", "no `source` of user data")
- Does meta-skill need to learn the scaffolding pattern that meta-test uses? Or is bash tooling out-of-scope for meta-skill (meta-test owns it)?
- If meta is silent on scripts, does that *de facto* discourage future skills from having them? Is that a good or bad default?

## User answers — round 1

*Captured 2026-05-05.*

### A1 — On "verifying bash-as-LCD"

> "MAIN THING IS DO THEY SUPPORT BASH?"

Verification = a literature/docs scan of how Codex, Gemini CLI, Aider, Cursor, and similar coding-agent platforms handle deterministic tooling in their plugins/skills. The minimum useful answer per platform is: *can a plugin/skill ship a bash script and have the agent invoke it?* Secondary: what *else* do they support (Python, sandboxed JS, custom DSL, nothing)? That tells us whether bash is genuinely the floor or if a different LCD exists.

This is a `/jim:research` task, not a brainstorm task. Output goes into a research doc that 001-meta (or its amendment) can cite.

### A2 — Why bash bias is plausible even before the research

User's argument from environment shape:

- Most Anthropic-distributed skills are written in Python.
- Claude Code itself is distributed as JavaScript.
- But devcontainers for non-Python/non-JS projects (e.g. a Rust devcontainer) typically *don't* ship a Python interpreter. The user doesn't put Python into Rust devcontainers unless absolutely necessary.
- Open mystery: how do Anthropic's Python-based skills work in those Python-less devcontainers? The user notes this is a separate investigation, not blocking.
- Bash, by contrast, is present in essentially every Linux/macOS/WSL devcontainer by default.

So the prior is "bash is the safest assumption for portability across devcontainer shapes," but it's a prior — not a verified claim. The research in A1 is what upgrades it from prior to evidence.

### A3 — Decision rule for "bash script vs. prompt"

User does not have a polished rule yet. Working guess (theirs):

> Deterministic logic that could be executed much more efficiently in a script than through LLM interpretation (think 10-1000x reduction in latency and token usage for the task at hand).

That's a strong starting heuristic. Sharpened slightly:

| Use a bash script when… | Use a prompt when… |
| --- | --- |
| The task is **deterministic** (same input → same output, no judgment). | The task requires **judgment, synthesis, or rationale** (interview, design tradeoff, validation reasoning). |
| The cost in tokens or latency through the LLM would be 10–1000× higher than a script. | Tokens/latency are dominated by the LLM's reasoning, not the mechanical step. |
| The result is **verifiable** by exit code or string compare. | The result is qualitative ("is this spec well-scoped?"). |
| The operation can fail loudly and recoverably (exit 1, empty string). | The operation needs graceful degradation or a conversational fallback. |

Existing examples that fit this rule:
- `jimconf.sh get <key>` — deterministic config parsing → script.
- `jimfile.sh next-id <group>` — deterministic enumeration → script.
- `jimfile.sh exists <path>` — deterministic stat → script.
- `meta-test/scripts/*.sh` — deterministic test execution → script.

Counter-examples (rightly stayed in prompts):
- "Read this spec and identify gaps" — judgment.
- "Is this research adequate for the 7-point check?" — judgment.
- The interview phase of `/jim:spec` — synthesis from a conversation.

This is the rule that should land in `ARCHITECTURE.md` → Plugin Conventions → Scripting Layer (where the bash conventions already live), and be referenced from the meta-skill validation checklist.

### A4 — Cross-link to the BASIC-style logic-flow convention

> **Superseded by spec 011 (2026-05-12; re-amended 2026-05-13)** — the BASIC-style dialect referenced here and prescribed in the §"Outcome" planning table below was retired in favor of (first) the directive vocabulary + lean paren-free `IF` block, and (then, on 2026-05-13) the sentinel form `SET … = !\`bash …\`` + `IF … != "NOT_FOUND" THEN`. See `ARCHITECTURE.md` → Plugin Conventions → Logic-Flow Conventions and `docs/brainstorms/20260513-directive-vocab-exists-trap.md`. References below preserved as forensic record.

There's an active sibling brainstorm at `docs/brainstorms/20260505-file-resolver-conventions-audit.md` proposing a small BASIC-style pseudocode dialect (`IF (...) EXISTS THEN ... END IF`, `IF (...) ABSENT THEN`, `THEN DO: 1. ... DONE`, `ELSE`) for in-prompt logic gates that wrap `!`bash …`` substitutions.

It's the same family of question:

- *That* brainstorm asks: "when prose is verbose and ambiguous, can we adopt a tiny convention for control flow inside skill bodies?"
- *This* brainstorm asks: "when prose is doing work a script could do deterministically, can we adopt a convention for offloading to bash?"

Both end at the same conclusion shape: a **small, codified, documented convention** that any skill or agent can opt into, governed centrally so it doesn't drift. They should be presented to @jim:meta together, because:

- The decision rule "use a script when X" pairs naturally with the gate idiom "and wrap its result in `IF (…) EXISTS THEN`".
- A skill author hitting either question wants both answers in one place.
- The validation checklist gets one new section, not two.

Implication: the 001-meta amendment (see A5) should reference both — the bash-script decision rule *and* the BASIC-style gate idiom — as a unified "Scripting & Logic-Flow Conventions" reference.

### A5 — Scope of the 001-meta retro update

User: "I don't know what is right. Looking for your suggestion. Stick to the intent of the 001-meta scope."

001-meta's intent: define how @jim:meta builds and validates jim plugin components (skills + agents) against jim's structural standards. It is *not* meant to enumerate every implementation detail of those components — it points at the standards, and the standards live elsewhere (CLAUDE.md, ARCHITECTURE.md → Plugin Conventions, the skill bodies themselves).

Recommended scope, smallest viable:

**Tier 1 — must do (in scope of 001-meta):**

1. **Spec amendment to 001-meta.** Add a short subsection under "Standards Applied" that says:
   - *Skills MAY include a `scripts/` directory for deterministic tooling.*
   - *Bash is the canonical scripting language; conventions live in `CLAUDE.md` (security/portability rules) and `ARCHITECTURE.md` → Plugin Conventions → Scripting Layer (composition rules).*
   - *In-prompt logic gates around script outputs follow the BASIC-style idiom documented in `ARCHITECTURE.md` → Plugin Conventions.*
   - *Skill validation must check that scripts conform to those rules, and that gate idioms are used consistently.*
   This is a paragraph, not a redesign. The detailed rules live in the canonical conventions doc; the spec just acknowledges that the standards include them.
2. **`agents/meta.md` amendment.** Add scripts (and the BASIC idiom) to the "Key paths" list and the Rules of Engagement, so the agent knows skills can have a `scripts/` directory and that gate idioms exist. ~3 lines total. Stays under the 800-token budget.
3. **`skills/meta-skill/SKILL.md` validation checklist.** Add bullets:
   - If `scripts/` exists, scripts conform to CLAUDE.md (no `set -e`, no third-party deps, no `source` of user data, `BASH_SOURCE`-relative composition).
   - In-prompt gates use the documented BASIC-style idiom (no invented variants).
4. **`skills/meta-agent/SKILL.md` validation checklist.** Same gate-idiom check (agents reference paths too). Agents themselves don't ship scripts, so the script-conformance bullet doesn't apply.
5. **Research amendment to 001-meta.** Cite the cross-platform bash-support research (output of A1) as the verification basis for the LCD claim.

**Tier 2 — nice to have, but separate spec:**

- `/jim:research` task: "Cross-platform support for bash scripting in coding-agent plugins/skills (Codex, Gemini CLI, Aider, Cursor, …)." This is the research that *proves* bash-as-LCD. It blocks the research amendment in Tier 1 #5 — but the rest of Tier 1 can land first with the prior as a "to-be-validated" note.
- A separate spec for the canonical conventions doc itself (the "Scripting & Logic-Flow Conventions" section in `ARCHITECTURE.md`). This is where the *substance* lives — not in 001-meta. 001-meta just points at it.

**Out of scope:**

- A new `/jim:meta-script` skill. Scripts are an *artifact* of skills, not a top-level component type. meta-skill already governs the skill they live in; that's enough.
- Folding script authoring into meta-skill's build flow (i.e. teaching meta-skill to scaffold scripts). meta-test already owns scaffolding via `/jim:meta-test scaffold`. Don't duplicate.
- Retroactively rewriting 007/008/009 specs — they're approved and built. Their existence is the *evidence* that the convention works; that's all 001-meta needs to acknowledge.

The principle: 001-meta is the constitution for jim plugin components. The constitution should *acknowledge* that scripts and gate idioms are part of the world (and point at the canonical rules), but it should not *re-state* those rules. That keeps 001-meta stable as the substance evolves.

## Decisions — round 2

*Captured 2026-05-05.*

### D1 — Order of operations: research first

Research lands before the 001-meta amendment. The research output informs *what* the amendment says about bash-as-LCD; we don't want to write a stub and patch it later.

Sequence:

1. `/jim:research` — bash-script support across coding-agent platforms (Codex, Gemini CLI, Aider, Cursor, plus the Python-in-Rust-devcontainer thread folded in — see D3). Output: a research doc grounding the LCD claim with evidence.
2. `/jim:spec` — 001-meta amendment, citing the research. Touches: 001-meta spec.md (paragraph addition under Standards Applied), 001-meta research.md (cite the new research), `agents/meta.md` (add scripts + gate idiom to Key Paths and Rules of Engagement), `skills/meta-skill/SKILL.md` (validation checklist bullets), `skills/meta-agent/SKILL.md` (gate-idiom validation bullet).
3. (Out of scope here) Whatever the *file-resolver* brainstorm spawns lands as its own separate spec(s).

### D2 — Canonical conventions home: `ARCHITECTURE.md`

Decision: extend `ARCHITECTURE.md` → Plugin Conventions with the bash-vs-prompt decision rule and the BASIC-style gate idiom.

Considered and rejected: putting the conventions inside the jim:meta skill (`skills/meta-skill/SKILL.md` or `skills/meta-agent/SKILL.md`). Reason: they'd be **buried**. These conventions apply to *every* skill author — not just to people building or auditing jim plugin components via meta. ARCHITECTURE.md is already the canonical home for Plugin Conventions / Scripting Layer rules; this is the natural extension.

No new `skills/CONVENTIONS.md`. One canonical home, not two.

### D3 — Spec scope: this brainstorm only touches 001-meta

Confirmed: this brainstorm is focused on the **001-meta scope**. The output is a 001-meta amendment (spec.md, research.md, agent body, two skill bodies) plus the new ARCHITECTURE.md subsection it cites.

The file-resolver brainstorm (`docs/brainstorms/20260505-file-resolver-conventions-audit.md`) is its own spec track — separate scope, separate sweep, separate PR. The two brainstorms share the BASIC-style idiom *as a documented convention*, but they don't share a spec. Each amends what it owns.

### D4 — Python-in-devcontainer thread: folded into the same research

Decision: fold the Python-in-Rust-devcontainer mystery (A2) into the same `/jim:research` task as the bash-LCD scan. Same research lens (what runtime assumptions can a plugin make about a developer's environment?), so it makes more sense as one investigation than two.

Research scope (combined):

1. **Primary:** for each of Codex, Gemini CLI, Aider, Cursor, and any other major coding-agent platform — does it support running bash scripts from a plugin/skill? What else does it support (Python, sandboxed JS, custom DSL, none)?
2. **Secondary:** what runtime/interpreter assumptions do these platforms make about the user's environment? Specifically: how do Anthropic's Python-based skills work in devcontainers that don't ship a Python interpreter (e.g. typical Rust devcontainer)? Is there a sandboxed Python runtime, a bundled interpreter, or do those skills simply fail in those environments?
3. **Synthesis:** is bash actually the LCD across these platforms, or is something else (POSIX shell only? a sandboxed runtime? nothing?) closer to universal?

The research lands **directly into `docs/specs/jim/001-meta/research.md` as a differential update** — not as a new research doc and not as a new spec. We're refactoring 001-meta in place; the research is part of that refactor, not a separate artifact.

## Decisions — round 3

*Captured 2026-05-05.*

### D5 — No new spec. In-place refactor of 001-meta only.

Course-correction: this work is **not a new spec**. The brainstorm rolls directly into edits of the existing 001-meta artifacts (spec.md, research.md, plan.md) and the existing implementation files (`agents/meta.md`, `skills/meta-skill/SKILL.md`, `skills/meta-agent/SKILL.md`). No `002-meta-amendment` directory, no new spec ID.

The research task still runs first (D1 stands), but its output is folded into `001-meta/research.md` via the standard differential-update flow rather than landing in a fresh research doc.

## Files to change — change matrix

The complete list of files touched by this refactor, with the specific change each one needs. Anything not listed here is **not changing**.

| # | File | Change | Notes |
|---|------|--------|-------|
| 1 | `docs/specs/jim/001-meta/research.md` | Differential update — add a new section "Scripting Layer in jim plugin components" capturing the bash-LCD evidence + Python-in-devcontainer findings. Cite per-platform sources (Codex, Gemini CLI, Aider, Cursor). | Run `/jim:research docs/specs/jim/001-meta/spec.md` — the research skill detects the existing file and offers a differential update. |
| 2 | `docs/specs/jim/001-meta/spec.md` | Add a subsection under "Standards Applied" titled "Scripting Layer (optional)" — one paragraph stating: skills MAY ship a `scripts/` directory; bash is canonical; security/portability rules in CLAUDE.md; composition rules in ARCHITECTURE.md → Plugin Conventions → Scripting Layer; in-prompt logic gates use the BASIC-style idiom (also in ARCHITECTURE.md). Add corresponding bullets to Acceptance Criteria for both `/jim:meta-skill` and `/jim:meta-agent` (script conformance check, gate-idiom check). | Spec stays acknowledging-not-restating: points at canonical conventions, doesn't re-document them. |
| 3 | `docs/specs/jim/001-meta/plan.md` | Two changes: (a) add a new design decision (Decision #10 or appended) covering the scripting layer's place in meta's validation flow; (b) extend Task 1 (meta-skill SKILL.md) and Task 2 (meta-agent SKILL.md) checklists with the new validation bullets so the plan's task list and verify commands match the updated spec. | Plan must stay consistent with the amended spec — otherwise the next `/jim:build` against this spec drifts. |
| 4 | `agents/meta.md` | Three small additions: (a) add `skills/{name}/scripts/` to the "Key paths" list; (b) add a one-line Rule of Engagement noting that skill artifacts may include `scripts/` directories and gate idioms in prose, and that validation must check both; (c) keep the body under 800 tokens. | No new tools. No new model. The agent learns about scripts through the preloaded skills, not through agent-body bloat. |
| 5 | `skills/meta-skill/SKILL.md` | Add validation-checklist bullets: (a) if `scripts/` exists, scripts conform to CLAUDE.md (no `set -e`, no third-party deps, no `source` of user data, `BASH_SOURCE`-relative composition); (b) in-prompt gates use the documented BASIC-style idiom (no invented variants); (c) every script reachable by an `!`-injection in the SKILL.md body actually exists at the cited path. | Stays under 500 lines. |
| 6 | `skills/meta-agent/SKILL.md` | Add validation-checklist bullet: in-prompt gates (if any) use the documented BASIC-style idiom. Agents don't ship scripts, so the script-conformance bullet doesn't apply here. | Stays under 500 lines. |
| 7 | `ARCHITECTURE.md` | Extend "Plugin Conventions → Scripting Layer" with: (a) the bash-vs-prompt decision rule (the table in §A3); (b) a new "Logic-Flow Conventions" subsection codifying the BASIC-style idiom (`IF (X) EXISTS THEN`, `IF (X) ABSENT THEN`, `THEN DO: 1. ... DONE`, `ELSE`, `END IF`). | This is the canonical home for the conventions both meta-skill and meta-agent will cite. Touched here, not duplicated in 001-meta. |

### Files explicitly *not* changing

- `WORKFLOW.md` — process definition unchanged. Scripts and gate idioms are an artifact-level convention, not a workflow-level one.
- `CLAUDE.md` — security/portability rules for bash scripts already live here; they don't need to change.
- `agents/pm.md`, `agents/architect.md`, `agents/researcher.md`, `agents/coder.md` — none of these own meta-component validation. They reference paths but don't author scripts as part of jim plugin development.
- All other skill SKILL.md files — they consume scripts already; their conventions are unchanged.
- 002–009 specs — historical record; left alone.

## Routing — what happens next

A single in-place refactor track. No new specs.

1. **`/jim:research docs/specs/jim/001-meta/spec.md`** — kicks off the research task targeting 001-meta. The research skill detects the existing `research.md` and offers a differential update covering the bash-LCD evidence and Python-in-devcontainer findings. Output: file #1 in the change matrix.
2. **Apply changes #2 through #7** in the order they're listed (spec → plan → agent → skills → ARCHITECTURE.md). Each gets the differential-update treatment per WORKFLOW.md (read existing, summarize proposed change, edit not write).
3. Smoke-test: read the amended SKILL.md files end-to-end and confirm validation checklists are coherent and under budget. No new test infrastructure needed — the existing test scripts already cover the bash layer's correctness.
