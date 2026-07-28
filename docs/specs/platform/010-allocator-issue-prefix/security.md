---
spec: "docs/specs/platform/010-allocator-issue-prefix/spec.md"
reviewed_phases: [spec]
status: Active
date: "2026-07-28"
---

# Security Review: Allocator honors the configured issue-id prefix

## Summary

**Findings:** 0 Critical · 0 Notable · 0 Advisory

Spec-only review, requirements-gap lens. Hybrid freeform + STRIDE sweep; LINDDUN
omitted (no PII / credentials / session data). The one relevant attack surface —
a config-supplied `issue_id_project` value or `{…}` template flowing into a
durable id, hence a filename, a registry token, and a git argument — is already
fully specified by AC 5 (revalidate the prefix **and** the durable id through the
`is_valid_id` boundary), and the proposed reuse (`jimfile.sh prefix-from`)
inherits that gate rather than adding a new one. Nothing this change introduces
escapes the existing `platform/007` boundary.

## Coverage

- spec.md — reviewed 2026-07-28 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | The change alters the id *prefix*, not the title-derived slug or `<who>` (unchanged from `platform/007`); it handles no personal data. |
| Credentials | No | None. |
| Session data | No | None. |
| Internal-only | Yes | Project-internal issue ids and the checked-in `issue_id_project` / template config that shapes them. |
| Public | No | Ids stay repo-internal. |

## Findings

No security findings identified.

The change is a narrow, well-bounded derivation fix with a single untrusted
input — the developer-supplied `issue_id_prefix` / `issue_id_project` config —
which the spec already fences:

- **AC 5 covers the injection surface completely.** It requires the derived
  prefix *and* the composed durable id to pass the `is_valid_id` boundary before
  becoming a filename, registry token, or git argument. Research confirmed
  `cmd_prefix_from` already validates its output through `is_valid_id` and
  `render_template` passes the template as a `date +fmt` *argument* (never
  `eval`/`source`), so a crafted `{…}` value cannot execute and a
  boundary-invalid result is rejected, not emitted.
- **No new trust boundary.** The config was already untrusted-input to jim
  (`CLAUDE.md` parse-as-data convention); this spec routes it through the same
  gate the tree-based `next-id` path used.
- **Frozen `platform/007` contract is preserved** (AC 4): a non-date durable id
  is just another `<full-id>` token that resolves identically, so the change
  cannot corrupt the registry grammar or forward-replay resolution.

The plan should keep the reuse on the existing boundary — validate the *final*
`prefix-slug` base (not only the prefix) and treat any `prefix-from` non-zero as
the AC 2 date-slug fallback, never interpolating its stderr — but this is AC 5's
implementation, not an unaddressed gap.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or authentication surface; ids are advisory, never an auth anchor (`platform/007` non-goal). |
| Tampering | Yes | The config → durable-id → filename/registry/git path; addressed by AC 5's `is_valid_id` boundary and the inherited `cmd_prefix_from` gate. No unaddressed vector. |
| Repudiation | N/A | Ids carry no authority and there is no audit-trail claim; `<who>`/dates stay informational (`platform/007`). |
| Information Disclosure | N/A | No new disclosure — the slug already lived in the id; the `project` scheme exposes only the developer-chosen prefix. |
| Denial of Service | N/A | One extra `jimfile.sh` sub-invocation per allocation; no resource-exhaustion surface. |
| Elevation of Privilege | N/A | Ids are never authorization anchors (`platform/007` non-goal). |

## Routing Recommendations

No routing required — all findings are informational.
