# Spec Types Reference

Reference document for the `/jim:spec` skill. Covers per-type guidance, anti-patterns, and status lifecycle.

---

## Per-Type Guidance

### Feature

**Required sections:** Overview, Problem Statement, User Stories, Acceptance Criteria, Out of Scope, Open Questions

**Interview focus:**
- What user problem does this solve? (not what solution to build)
- Who specifically uses this? (role, not "users")
- What does success look like? (measurable acceptance criteria)
- What's explicitly excluded? (scope boundaries)

**Common pitfalls:**
- Jumping to solution before problem is clear
- "Users" instead of specific roles
- Acceptance criteria that describe implementation, not outcomes

### Bug

**Required sections:** Overview, Defect Profile, Acceptance Criteria, Out of Scope, Open Questions

**Interview focus:**
- Precise reproduction steps (environment, sequence, data)
- Actual vs expected behavior (observable, not interpreted)
- Is there an existing debug document to link via `origin:`?
- Scope: is this a single fix or a symptom of a larger issue?

**Common pitfalls:**
- Vague reproduction ("it sometimes crashes")
- Missing environment details
- Conflating symptom with root cause

**Mandatory acceptance criterion:** "Regression test covers the reported scenario"

### Refactor

**Required sections:** Overview, Refactor Rationale, Acceptance Criteria, Out of Scope, Open Questions

**Interview focus:**
- What triggered this now? (motivation, not just "tech debt")
- Current state vs desired state (concrete, not aspirational)
- Which systems are affected? (blast radius)
- How do you know it worked? (existing tests still pass)

**Common pitfalls:**
- Scope creep into feature work ("while we're at it...")
- No clear definition of "done"
- Underestimating affected systems

**Mandatory acceptance criterion:** "Existing tests pass without modification"

---

## Anti-Patterns

Watch for these during the interview and self-check. Flag them conversationally when detected.

### 1. Kitchen Sink

**What it looks like:** The spec tries to solve multiple problems at once. Acceptance criteria cover unrelated concerns. The overview needs more than 2 sentences.

**Example:** "Add user profiles, avatar uploads, profile search, and a public API for profile data."

**Remedy:** Suggest splitting into separate specs. Each spec should have one clear problem statement.

### 2. Vague Criteria

**What it looks like:** Acceptance criteria use subjective or untestable language — "works well," "is clean," "feels fast," "improves quality."

**Example:** "The page loads quickly and looks good on mobile."

**Remedy:** Make measurable. "Page loads in <500ms with 100 items" and "Layout passes responsive check at 375px width."

### 3. Solution Masquerading

**What it looks like:** The spec describes a technical solution rather than the user problem it solves. Problem Statement reads like a task list.

**Example:** "We need to add a Redis cache layer to the API" instead of "Product page takes 8 seconds to load under normal traffic."

**Remedy:** Reframe around the user pain. The solution belongs in the plan, not the spec.

### 4. Empty Out of Scope

**What it looks like:** The Out of Scope section is missing, empty, or says "N/A." No boundaries have been drawn.

**Example:** A spec for "user notifications" with no mention of what notification types or channels are excluded.

**Remedy:** Every spec excludes something. If boundaries seem infinite, the scope is too vague — tighten the problem statement first.

### 5. Premature Tech

**What it looks like:** The spec prescribes database schemas, API endpoints, library choices, or architectural patterns. These are the architect's job.

**Example:** "Use PostgreSQL with a JSONB column for user preferences, exposed via a REST endpoint at /api/v2/preferences."

**Remedy:** Describe the data shape and behavior, not the implementation. "User preferences are persisted and retrievable" is a spec concern; the storage mechanism is a plan concern.

### 6. Wrong Type

**What it looks like:** Feature sections (Problem Statement, User Stories) are used for a bug, or bug sections (Defect Profile) appear in a feature spec. User stories feel forced or nonsensical.

**Example:** A bug report with "As a user, I can see the correct total so that my cart is accurate" — this is a broken behavior, not a new capability.

**Remedy:** Switch to the correct type. If user stories don't make sense, it's probably a bug. If there are no reproduction steps, it's probably a feature.

### 7. Over-specification

**What it looks like:** An AC names a function signature, file path, library, technology, or protocol as a required outcome. The technology-agnostic test fails — swapping the implementation (CLI ↔ Voice UI, Bash ↔ Rust) would invalidate the AC even though the underlying user need would be unchanged.

**Example (verbatim from GitHub spec-kit `templates/commands/specify.md`, applies to `feature` and `bug` specs):**

- "API response time is under 200ms" — reframe: *"Users see results instantly."*
- "Database can handle 1000 TPS" — reframe to user-observable load behavior.
- "React components render efficiently" — reframe to user-observable interaction quality.
- "Redis cache hit rate above 80%" — reframe to user-observable latency or staleness behavior.

**Calibration by spec type:** For `type: refactor` specs, the probe asks "does this AC trace to a `Refactor Rationale → Desired State` entry, and does it describe desired-state shape rather than migration procedure?" rather than the technology-agnostic test above. Paired example —

- **Good (desired-state shape, passes):** *"`auth.rs` is split into `auth/token.rs` and `auth/session.rs`."*
- **Bad (migration procedure, routes to Handoff):** *"Use `git mv` to move `auth.rs` then sed-rewrite the imports."*

The first names what the codebase looks like after the refactor; the second prescribes how to get there. Procedure routes to Handoff regardless of spec type.

**Remedy:** For `feature` / `bug` specs, apply the Level-Up Method — ladder the technical statement up to the user need it enables, write the abstraction into the AC, and route the technical proposal to the Research & Architecture Handoff section. For `refactor` specs, confirm the AC traces to a Refactor Rationale entry; if it describes procedure, move the procedural detail to Handoff and keep only the desired-state shape in the AC.

---

## Status Lifecycle

```
draft → approved → in-progress → complete → deprecated
```

| Status | Meaning | Who transitions |
|--------|---------|-----------------|
| `draft` | Being scoped or interviewed. Not ready for planning. | PM creates with this status |
| `approved` | Scope confirmed by human. Ready for architect. | Human explicitly approves |
| `in-progress` | Plan exists, implementation underway. | Architect/coder sets this |
| `complete` | All acceptance criteria met. | Coder confirms |
| `deprecated` | No longer relevant. Kept for history. | Human decides |

The PM never sets status beyond `draft` without explicit human confirmation. Asking "Should I mark this as approved?" is required — never auto-approve.

---

## Traceability: The `origin:` Field

The `origin:` frontmatter field links a spec to its upstream source documents — brainstorms, debug docs, or other artifacts that motivated the spec.

**When to use:**
- Spec originated from a `/jim:brainstorm` session → link the brainstorm file
- Bug spec originated from a debug document → link the debug file
- Spec formalizes an idea discussed in another artifact → link that artifact

**Format:** List of relative paths from project root.

```yaml
origin:
  - docs/brainstorms/notification-ideas.md
  - docs/debug/cart-total-bug.md
```

**When to omit:** If the spec originated from a direct conversation with no prior artifact, omit the `origin:` field entirely (remove the placeholder).
