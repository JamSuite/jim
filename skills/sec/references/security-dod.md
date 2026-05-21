# Security Review Definition of Done

Self-check reference for the `@jim:security` agent and the `/jim:sec` skill. Every security review must pass all applicable items before presentation.

## Checklist

### Findings Quality

1. **Complete findings:** Every finding includes all four required fields — severity (Critical / Notable / Advisory), description, suggestion, route (Spec or Plan). The `Relates to:` field is present when the finding traces to a specific AC, User Story, or section of the reviewed artifact; omitted only when no applicable source can be cited (typically ad-hoc mode).

2. **Actionable suggestions:** Every suggestion is concrete and specific — not vague ("consider security") or aspirational ("should be more secure"). The recipient (PM or architect) can act on it without further clarification.

3. **Correct severity:** Critical = design flaw that will create a vulnerability if built as-is. Notable = gap that should be addressed before build. Advisory = hardening opportunity at lower priority.

4. **Correct routing:** Critical and Notable findings route to Spec or Plan based on where the fix lives — requirements gaps route to Spec, design flaws route to Plan, artifact misalignment routes to whichever artifact is the source of truth. Advisory findings route to Spec or Plan like every other severity (backlog routing is deferred per spec 016 Out of Scope until `/jim:backlog` ships).

5. **No duplicates:** Findings do not duplicate security considerations already documented in `ARCHITECTURE.md`. If a finding reinforces an existing constraint, reference it rather than restating it.

### Data Classification

6. **Classification populated:** The Data Classification table is filled before any threat-framework sweep runs. Each row (PII, Credentials, Session data, Internal-only, Public) is marked Yes or No with notes that name specific data fields where applicable.

7. **LINDDUN activation rule:** LINDDUN coverage is included whenever any of PII, Credentials, or Session data is `Yes`. When all three are `No`, the LINDDUN section is omitted entirely.

### Framework Sweep Coverage

8. **Freeform review precedes systematic sweep:** Expert review is performed first; context-specific, non-obvious issues are considered before the framework-driven sweep. The systematic sweep is a completeness pass, not a substitute for judgment.

9. **STRIDE sweep completed:** All six STRIDE categories appear in the coverage table — Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege. Each row is marked Yes (relevant, with finding refs), No (relevant but no issues found), or N/A (clearly not applicable, with brief reason). Categories are never silently omitted. Source: `https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats`.

10. **LINDDUN sweep (when active):** All seven LINDDUN categories appear in the coverage table — Linking, Identifying, Non-repudiation, Detecting, Data Disclosure, Unawareness & Unintervenability, Non-compliance. Each row is marked Yes / No / N/A with finding refs or "No issues found." Use current linddun.org naming exactly — do not substitute older academic terms (Linkability / Identifiability / etc.). Source: `https://linddun.org/threat-types/`.

11. **N/A handling:** Marking a category N/A requires a one-clause justification in the Notes column or finding reference (e.g., "no external trust boundary"). N/A without justification is a checklist failure.

### Phase Coverage Indicator

12. **`reviewed_phases:` populated correctly:** The frontmatter `reviewed_phases:` array lists exactly the phases analyzed in the most recent run. Entries are unquoted bare tokens — `[spec]`, `[plan]`, or `[spec, plan]`. The array reflects actual coverage, not aspiration; if plan.md was not read, `plan` is not in the array.

13. **`## Coverage` body section matches frontmatter:** The body's `## Coverage` list mirrors `reviewed_phases:` one-to-one, with the review date and lens applied for each entry. The body is the human-readable companion; the frontmatter is the gate's source of truth.

14. **Ad-hoc mode omits `reviewed_phases:`:** When the review target is not a spec directory, the frontmatter uses `target:` instead of `spec:`, and `reviewed_phases:` is omitted entirely. Ad-hoc reviews have no phase semantics.

### Architecture Grounding

15. **Architecture-grounded:** If `ARCHITECTURE.md` exists, it was read before analysis began. Findings are consistent with the project's existing trust boundaries, data flows, and security patterns; contradictions are surfaced as findings rather than silently introduced.

16. **Lens-appropriate:** Spec-phase analysis focuses on requirements gaps (missing controls, unaddressed boundaries, data classification gaps). Plan-phase analysis focuses on design flaws (flawed mitigations, privilege issues, crypto choices). Both lenses applied when both artifacts exist. Artifact misalignment surfaces explicitly when both lenses run together.

### Output Format and Mode-Specific Behavior

17. **Status set correctly:** Frontmatter `status:` is one of: `Active` (no Critical or Notable findings — all are Advisory or none exist), `Needs Spec Review` (at least one Critical or Notable finding routes to Spec), `Needs Plan Review` (at least one Critical or Notable finding routes to Plan).

18. **Severity summary header present:** The `## Summary` section opens the artifact with the one-line severity count (`N Critical · N Notable · N Advisory`) and a 1–2 sentence orientation line.

19. **Spec-scoped mode writes the artifact:** Output is written to `security.md` in the spec directory as a sibling artifact (or updated in place when one already exists). Routing offers Spec and Plan destinations at the end of review.

20. **Ad-hoc mode no-default-write:** Output is delivered in conversation by default — no file is written. The skill prompts conversationally at end of review for opt-in file output; only on the developer's affirmative response is a file written to `{security_adhoc_path}/{YYYYMMDD}-{slug}.md`. Writing a file unsolicited is a checklist failure.

21. **Differential update used Edit:** When `security.md` already exists, the existing file is read first, changes are summarized to the developer (or auto-applied in `auto_security` mode), and `Edit` is used to preserve sections the developer did not authorize changes to. `Write` is reserved for the initial creation.

22. **Re-run delta surfaced:** On a re-run against a target with an existing review, the conversational output names new findings, resolved findings, and unchanged findings explicitly so the developer can scope attention to the delta.

### Routing and Auto-Routing Safety

23. **Routing offer matches mode:** In default mode and `require_security` mode, the developer is prompted to route findings to Spec or Plan. In `auto_security` mode, routing happens automatically without per-finding prompts and the routing decisions are visible in the artifact's `## Routing Recommendations` section.

24. **Auto-route Edit safety:** When `auto_security = "true"`, `Edit` calls modify spec.md or plan.md only in their designated content sections — new ACs appended to the spec's Acceptance Criteria list, new tasks or design decisions appended to the plan's Task Breakdown / Design Decisions sections. Frontmatter, locked-constraint sections, and non-content prose are never modified by the auto-route mechanism. Edits outside these sections are a checklist failure.

25. **Critical findings highlighted in conversational summary:** Any conversational summary surfaced to the developer — default offer, required gate, or automated gate — names the Critical-finding count prominently and lists each Critical finding's title and route.

### Loop and Halt Behavior

26. **Loop entered only when `require_security_loop = "true"`:** When the loop flag is absent or `"false"`, the review-and-routing cycle runs once. When the loop flag is `"true"`, the cycle repeats until `require_security_loop_sev` is clear or `auto_security_loop_limit` is reached.

27. **Loop exit determinism:** The loop exits on whichever condition is met first — severity threshold clear, or iteration limit reached. The most recent iteration's findings determine the exit condition.

28. **Halt-error format when limit reached with unresolved findings:** When `auto_security_loop_limit` is reached and findings remain at or above `require_security_loop_sev`, the skill emits a structured conversational error block — one paragraph naming each unresolved finding (severity, title, route, `Relates to:` source where applicable), one paragraph naming the gate that blocked (`/jim:plan` or `/jim:build`), and one sentence suggesting remediation (address findings or relax `auto_security_loop_limit` / `require_security_loop_sev`). The skill exits non-zero so the calling phase halts cleanly.

### Stop Discipline

29. **Skill stops after producing findings and completing routing:** The skill does not invoke other skills, does not modify artifacts outside the auto-routing mechanism, and does not proceed to subsequent SDLC phases. The developer (or the calling phase gate) decides what happens next.
