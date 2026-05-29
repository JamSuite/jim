---
spec: "{relative/path/to/spec.md}"
# target: "{relative/path/to/reviewed/file-or-dir}"     # ad-hoc mode — use instead of spec
reviewed_phases: [spec]                                  # spec | plan | both; omitted in ad-hoc mode
status: Active                                           # Active | "Needs Spec Review" | "Needs Plan Review"
date: "{YYYY-MM-DD}"
---

<!-- Budget: findings are actionable and specific. No vague "consider security" entries. -->

# Security Review: {Title}

## Summary

**Findings:** {N_critical} Critical · {N_notable} Notable · {N_advisory} Advisory

{1–2 sentences: what was reviewed; lenses applied; frameworks marked N/A.}

## Coverage

<!-- Phase-by-phase audit trail. Mirrors `reviewed_phases:` in frontmatter. -->

- spec.md — reviewed {YYYY-MM-DD} (requirements-gap lens)
- plan.md — reviewed {YYYY-MM-DD} (design-flaw lens)

<!-- Remove rows for phases not yet covered. In ad-hoc mode, replace with:
     - {target} — reviewed {YYYY-MM-DD} (ad-hoc lens) -->

## Data Classification

<!-- Classification informs which threat frameworks are applied. LINDDUN runs
     conditionally when PII / Credentials / Session data is "Yes". -->

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes / No | {Specific data fields if Yes} |
| Credentials | Yes / No | {Specific data if Yes} |
| Session data | Yes / No | {Specific data if Yes} |
| Internal-only | Yes / No | {Notes} |
| Public | Yes / No | {Notes} |

## Findings

<!-- Each finding is discrete and actionable. Order by severity (Critical first). -->

### 1. {Finding title}

- **Severity:** Critical | Notable | Advisory
- **Description:** {What the issue is — specific, not vague}
- **Suggestion:** {Concrete actionable recommendation — what to add, change, or specify}
- **Route:** Spec | Plan
- **Relates to:** {AC #N | User Story #N | section name}

<!-- The `Relates to:` line is omitted when no applicable source can be cited
     (typically ad-hoc mode where the target has no acceptance criteria). -->

<!-- If no findings: replace this section with "No security findings identified."
     and explain why (e.g., spec is low-risk, all boundaries are well-specified). -->

## STRIDE Coverage

<!-- Six rows; mark N/A explicitly rather than silently omitting.
     Source: https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats -->

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes / No / N/A | {Finding refs or "No issues found"} |
| Tampering | Yes / No / N/A | {Finding refs or "No issues found"} |
| Repudiation | Yes / No / N/A | {Finding refs or "No issues found"} |
| Information Disclosure | Yes / No / N/A | {Finding refs or "No issues found"} |
| Denial of Service | Yes / No / N/A | {Finding refs or "No issues found"} |
| Elevation of Privilege | Yes / No / N/A | {Finding refs or "No issues found"} |

## LINDDUN Coverage

<!-- Conditional — include only when Data Classification surfaces PII,
     Credentials, or Session data. Seven rows using current linddun.org naming.
     Source: https://linddun.org/threat-types/ -->

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | Yes / No / N/A | {Finding refs or "No issues found"} |
| Identifying | Yes / No / N/A | {Finding refs or "No issues found"} |
| Non-repudiation | Yes / No / N/A | {Finding refs or "No issues found"} |
| Detecting | Yes / No / N/A | {Finding refs or "No issues found"} |
| Data Disclosure | Yes / No / N/A | {Finding refs or "No issues found"} |
| Unawareness & Unintervenability | Yes / No / N/A | {Finding refs or "No issues found"} |
| Non-compliance | Yes / No / N/A | {Finding refs or "No issues found"} |

## Artifact Misalignment

<!-- Conditional — include only when both spec.md and plan.md were reviewed
     together. Findings here identify spec↔plan inconsistencies, distinct
     from routine requirements-gap or design-flaw findings. -->

- **Finding N — {Title}:** Spec states {X}; plan does {Y}. Route: Spec | Plan.

## Routing Recommendations

<!-- Summarize where findings should be routed. Remove empty sub-sections. -->

### Spec amendments
- {Finding N: suggested change to spec}

### Plan amendments
- {Finding N: suggested change to plan}

<!-- If no findings route: replace section with
     "No routing required — all findings are informational." -->
