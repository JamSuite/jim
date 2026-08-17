---
spec: "docs/specs/platform/010-allocator-issue-prefix/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-28"
---

# Security Review: Allocator honors the configured issue-id prefix

## Summary

**Findings:** 0 Critical · 0 Notable · 1 Advisory

Dual-lens review (spec requirements-gap + plan design-flaw), plus the spec↔plan
artifact-misalignment check. LINDDUN omitted (no PII / credentials / session
data). The injection surface (config → durable id → filename/registry/git) stays
fully fenced: AC 5 requires revalidation and the plan's **DD4 concretely adds the
final composed-base `is_valid_id` gate** — closing the one implementation note the
spec-phase pass raised. The plan-phase lens surfaced a single **Advisory**
consistency gap: the plan's "ordinal schemes fall back in provisional" claim is
inaccurate for the `{seq}` template escape hatch. No security-severity finding;
`platform/007`'s boundary is intact.

## Coverage

- spec.md — reviewed 2026-07-28 (requirements-gap lens)
- plan.md — reviewed 2026-07-28 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | The change alters the id *prefix*, not the title-derived slug or `<who>` (unchanged from `platform/007`); it handles no personal data. |
| Credentials | No | None. |
| Session data | No | None. |
| Internal-only | Yes | Project-internal issue ids and the checked-in `issue_id_project` / template config that shapes them. |
| Public | No | Ids stay repo-internal. |

## Findings

### 1. `{seq}` template diverges from the `sequential` preset in provisional mode

- **Severity:** Advisory
- **Description:** DD2/DD3 state that ordinal-dependent schemes fall back to
  date-slug in provisional mode (no numeric ordinal). That holds for the
  `sequential` *preset* — `cmd_prefix_from`'s `sequential` arm requires a numeric
  `num` and returns non-zero, triggering the fallback — but **not** for the
  literal template escape hatch: the `*'{'*` arm defaults `num=0` and renders, so
  `issue_id_prefix = "{seq:04}"` under a provisional allocation yields `0000-slug`
   — a valid id, but an arbitrary `0000` prefix that is neither the eventual real
  ordinal nor the date-slug the plan implies, and `reconcile` does not rename the
  file. No security impact (valid id, no injection); a correctness/consistency
  corner in a doubly-rare config (custom `{seq}` template + provisional mode).
- **Suggestion:** either force the date-slug fallback for a *provisional*
  allocation whenever the scheme carries a `{seq` token (preset **or** template)
  — e.g. skip `prefix-from` when `num` is empty and the scheme is ordinal-bearing
  — or document the `{seq}`-template-provisional `0000` result as an accepted
  quirk alongside AC 2.
- **Route:** Plan
- **Relates to:** DD2, DD3, AC 2

The change otherwise remains a narrow, well-bounded derivation fix with a single
untrusted input — the developer-supplied `issue_id_prefix` / `issue_id_project`
config — which the spec and plan fence:

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

The plan now concretely honors this boundary: **DD4** re-validates the *final*
`prefix-slug` base (not only the prefix `prefix-from` already checked), and
**DD3** treats any `prefix-from` non-zero as the AC 2 date-slug fallback without
interpolating its stderr — so the spec-phase implementation note is covered, not
an unaddressed gap.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or authentication surface; ids are advisory, never an auth anchor (`platform/007` non-goal). |
| Tampering | Yes | The config → durable-id → filename/registry/git path; addressed by AC 5's `is_valid_id` boundary and the inherited `cmd_prefix_from` gate. No unaddressed vector. |
| Repudiation | N/A | Ids carry no authority and there is no audit-trail claim; `<who>`/dates stay informational (`platform/007`). |
| Information Disclosure | N/A | No new disclosure — the slug already lived in the id; the `project` scheme exposes only the developer-chosen prefix. |
| Denial of Service | N/A | One extra `jimfile.sh` sub-invocation per allocation; no resource-exhaustion surface. |
| Elevation of Privilege | N/A | Ids are never authorization anchors (`platform/007` non-goal). |

## Artifact Misalignment

- **Plan overstates the provisional fallback.** DD2/DD3 assert ordinal-dependent
  schemes fall back to date-slug in provisional mode; the mechanism
  (`cmd_prefix_from`) falls back only for the `sequential` *preset*, while the
  `{seq}` *template* renders `0000` (Finding 1). Spec AC 2 is the source of truth
  for the fallback contract. **Route: Plan** — align the plan's claim with the
  mechanism (force the fallback for any ordinal-bearing scheme in provisional
  mode, or document the template `0000` quirk).

## Routing Recommendations

### Plan amendments
- Finding 1 (Advisory) — **done**: plan DD2 now force-falls-back to date-slug for
  any ordinal-bearing scheme (`sequential` preset **or** `{seq}` template) when
  `num` is empty (provisional); the interface contract and Data Flow reflect the
  pre-check and task 3 asserts it. The `0000` quirk is eliminated.

### Spec amendments
- None — AC 5's boundary is now concretely implemented by plan DD3/DD4; no
  spec change required.
