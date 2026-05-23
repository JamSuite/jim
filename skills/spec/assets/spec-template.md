---
title: "{title}"
type: feature | bug | refactor
group: "{group}"
id: "{00X}"
status: draft
origin:                           # optional — list of source documents
  - "{relative/path/to/source}"
---

# {00X} {title}

## Overview
{1-2 sentence description of what this spec delivers and why.}

<!-- feature only -->
## Problem Statement
{What user problem does this solve? Why does this need to exist? Focus on user pain, not the solution.}

## User Stories
- As a {role}, I can {action} so that {benefit}.
<!-- end feature only -->

<!-- bug only -->
## Defect Profile
- **Steps to Reproduce:**
  1. {Step 1}
  2. {Step 2}
- **Actual Behavior:** {What is currently happening?}
- **Expected Behavior:** {What should happen?}
- **Environment:** {OS, version, relevant config}
<!-- end bug only -->

<!-- refactor only -->
## Refactor Rationale
- **Motivation:** {Why now? What triggered this refactor?}
- **Current State:** {Technical debt or structural issue being addressed.}
- **Desired State:** {The architectural improvement target.}
- **Affected Systems:** {Subsystems touched by this change.}
<!-- end refactor only -->

## Acceptance Criteria
- [ ] {Specific, testable criterion}
<!-- bug only: always include -->
- [ ] Regression test covers the reported scenario
<!-- refactor only: always include -->
- [ ] Existing tests pass without modification

## UI Mockup
<!-- Optional — include for specs with visible output, remove otherwise -->
```
+----------------------------------+
| {Screen Title}                   |
+----------------------------------+
|                                  |
|   {Key elements here}            |
|                                  |
+----------------------------------+
```

## Data Flow
<!-- Optional — include for specs with non-trivial data flow, remove if straightforward -->
```mermaid
flowchart LR
    A[Input] --> B[Process] --> C[Output]
```

## Out of Scope
{Explicit exclusions to prevent scope creep. If nothing is excluded, boundaries are too soft.}

- {Thing that might seem related but is not included}

## Research & Architecture Handoff
<!-- Optional — include only when Implementation Insights were surfaced during interview. Remove this section entirely otherwise. -->

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive.*

### Insight {N}: {short title}

- **Relates to AC:** *"{paraphrased AC text}"* (AC #{N})
- **Surfaced as:** {what the user or PM originally proposed}
- **Levelled-up requirement (already in the ACs):** {how the user need was extracted}
- **Deflection reason:** {Razor / Delegation / Story-Link / Constraint-Sourcing}
- **Architect note:** {open consideration, alternatives worth weighing, risks}
- **Routing hint:** {Architect to decide | Researcher to investigate | Candidate constraint pending sourcing}

## Open Questions
{Unresolved questions. Write "None" if all questions resolved.}

- [ ] {Question that needs answering}
- [x] ~{Resolved question}~ → {Decision made}
