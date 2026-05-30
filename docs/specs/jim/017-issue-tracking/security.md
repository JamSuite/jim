---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Needs Plan Review
date: "2026-05-30"
---

# Security Review: Issue Tracking — Local Files (v1)

## Summary

**Findings:** 0 Critical · 6 Notable · 8 Advisory

Dual-lens re-review (spec + plan). 6 of the 8 prior findings are now addressed in the amended spec ACs and the plan; 2 remain unrouted Advisory items (deferred to v2). 6 new plan-lens findings (2 Notable, 4 Advisory) surfaced from the design phase — all route to Plan. Data Classification unchanged — LINDDUN sweep is not active.

## Coverage

- spec.md — reviewed 2026-05-30 (requirements-gap lens; re-verified 2026-05-30 against amended ACs)
- plan.md — reviewed 2026-05-30 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | System processes no PII directly; user-authored issue bodies may *contain* identifiers, but the system has no PII-specific processing. See Finding 5 for the related capture concern. |
| Credentials | No | No auth model. System does not collect, store, or transmit credentials. |
| Session data | No | No session state managed by jim. |
| Internal-only | Yes | Issue files live in `docs/issues/` and are version-controlled with the project. |
| Public | Conditional | Issue content becomes public when the repository is published. |

## Findings

### 1. ~~Slug normalization is unspecified — path traversal surface~~ — RESOLVED

- **Severity:** Notable
- **Status:** Resolved in spec — slug normalization AC added (AC-C7); plan tasks 3, 4, 5 implement.
- **Original description:** AC-C1 did not specify how the subject is normalized into a filename slug, leaving a path-traversal surface via inputs like `"../../etc/passwd"`.
- **Resolution:** Spec pins lowercase alphanumeric + dash only; path separators, `..`, leading dots, and control characters rejected before write.

### 2. ~~Wiki-link slug validation is unspecified — graph parser injection surface~~ — RESOLVED

- **Severity:** Notable
- **Status:** Resolved in spec — wikilink validation AC added (AC-I4); plan tasks 7, 8 implement.
- **Original description:** AC-I3 did not specify how wikilink content is validated.
- **Resolution:** Wiki-link content must match the slug rule; malformed content is treated as plain prose, not a graph edge.

### 3. ~~Frontmatter parse discipline pins source/eval but not YAML tag evaluation~~ — RESOLVED

- **Severity:** Notable
- **Status:** Resolved in spec — AC-S1 extended; plan DD #3 + task 7 enforce in script.
- **Resolution:** Parser must use line-oriented tools only; full YAML parsers explicitly forbidden.

### 4. ~~Issue content is a persistent prompt-injection surface for future agents~~ — RESOLVED

- **Severity:** Notable
- **Status:** Resolved in spec — AC-S2 added; plan DD #8 + tasks 13, 14 land the discipline in skill prose and agent instructions.
- **Resolution:** When issue content flows to a subordinate agent, it is wrapped in `<untrusted-issue-content>` delimiter tags and the receiving agent is instructed not to follow embedded instructions.

### 5. ~~Conversation-context capture may persist secrets inadvertently~~ — RESOLVED

- **Severity:** Advisory
- **Status:** Resolved in spec — AC-C2 augmented with explicit scrub reminder; plan task 13 implements in skill body.
- **Resolution:** Confirm-or-edit moment explicitly reminds the user to scrub sensitive content before persistence.

### 6. INDEX.md tampering window between writes

- **Severity:** Advisory
- **Status:** Unchanged. Plan defers per Out of Scope — single-developer threat model accepts the risk for v1.
- **Description:** `INDEX.md` is auto-regenerated on every `/jim:issue` write but can be hand-edited between writes; an agent reading it mid-task may navigate a tampered index.
- **Suggestion (deferred):** Embed a collection hash or per-issue mtime comparison at the top of `INDEX.md` so consumers can detect drift. Defer to v2.
- **Route:** Plan (deferred to v2 per plan Out of Scope)
- **Relates to:** AC-I2, US3

### 7. `origin:` link rot reduces provenance signal

- **Severity:** Advisory
- **Status:** Unchanged. Plan defers per Out of Scope — v2 lint task.
- **Description:** Issues link to source artifacts via `origin:`; v1 does not validate that those paths still resolve.
- **Suggestion (deferred):** Add a `/jim:issues lint` or similar pass that warns about broken origin paths. Defer to v2.
- **Route:** Plan (deferred to v2 per plan Out of Scope)
- **Relates to:** AC-C3 (`origin:` field)

### 8. ~~Status field has no native audit trail~~ — RESOLVED

- **Severity:** Advisory
- **Status:** Resolved in spec — Out of Scope updated; git history named as the v1 audit trail. Plan Out of Scope mirrors.
- **Resolution:** Both spec and plan explicitly name git history as the v1 audit-trail source.

### 9. Nested-YAML `relations:` parsing strategy not specified

- **Severity:** Notable
- **Description:** The issue schema (AC-C3) uses nested YAML for `relations:` — a top-level key whose value is an indented map of `<type>: [<slug>, ...]` entries. Plan DD #3 mandates line-oriented `grep` / `sed` / `cut`, but the plan does not specify how nested structures are parsed. A naive line-by-line approach can mis-attribute relations (a body containing the literal token `blocks:` as prose; off-indent values; a `---` body separator that confuses frontmatter bounds). Without an explicit parsing strategy, `index.sh` will either over-match or under-match `relations:` entries inconsistently.
- **Suggestion:** Add a design decision (or extend DD #3) specifying the nested-YAML parsing approach. Concrete pattern: "Read frontmatter as the block between the first two `^---$` lines only; within that block, parse `relations:` as a top-level key whose value lines are 2-space-indented `<type>: [<slug>, ...]`. Use `awk` with explicit indent-depth state matching the schema. Deeper indents are ignored. Malformed `relations:` blocks emit an Integrity Warning, not a fatal error." The pattern should match the discipline in `jimconf.sh` (no full YAML parser).
- **Route:** Plan
- **Relates to:** Plan DD #3, Interface Contract for `index.sh`, AC-C5, AC-S1

### 10. Atomic INDEX.md write strategy not specified

- **Severity:** Notable
- **Description:** Plan DD #9 promises "preserve previous INDEX.md on parse failure" but does not specify the implementation. Direct write to `INDEX.md` is non-atomic — a mid-write crash (signal, OOM, disk full) corrupts INDEX.md and breaks both `/jim:issues` and mid-task agent navigation. The canonical pattern is write-to-tmp + atomic rename: write to `<issues_dir>/.INDEX.md.tmp.$$`, then `mv` to `<issues_dir>/INDEX.md` on success. `mv` within a single directory is atomic on POSIX filesystems.
- **Suggestion:** Add a design decision (or extend DD #9) specifying the atomic-rename pattern: tmp file with PID suffix, `trap` for cleanup on signal, `mv` only after successful construction. Existing INDEX.md remains untouched on any failure path. Tested by `tests/issues.sh` injecting a mid-build failure.
- **Route:** Plan
- **Relates to:** Plan DD #9, Interface Contract for `index.sh`

### 11. Locale-sensitive `tr` behavior in slug normalization

- **Severity:** Advisory
- **Description:** Plan DD #5 uses `tr A-Z a-z` for case folding. POSIX locales without `LC_ALL=C` can produce locale-dependent behavior — Turkish locale famously maps dotless `ı` and dotted `İ` rather than ASCII `i`/`I`. Slugs would then differ across user environments for the same input, producing non-deterministic file names that fragment the collection.
- **Suggestion:** Set `LC_ALL=C` in the script preamble for `index.sh`, `render.sh`, and the new `jimfile.sh` branches that touch slug normalization. Consistent with the deterministic-behavior discipline in `CLAUDE.md` → Bash scripts.
- **Route:** Plan
- **Relates to:** Plan DD #5

### 12. INDEX.md regen race under concurrent invocation

- **Severity:** Advisory
- **Description:** Two concurrent `/jim:issue` writes (e.g., two terminals on the same repo, or a future workflow integration that batches multiple captures) could race on INDEX.md regeneration. Both reads see the issue collection at roughly the same moment; both writes race. Last writer wins; the loser's just-written issue may be absent from the final INDEX.md until the next regen. Finding 10's atomic-rename pattern ensures no half-written INDEX.md ever exists, but does not prevent the regen race itself. The single-developer threat model in `ARCHITECTURE.md` mitigates practical impact; the race is still real.
- **Suggestion:** v1 accepts the race per the single-developer assumption — document explicitly in plan Out of Scope or as part of DD #2 / DD #9. v2 (or any multi-process workflow expansion) should wrap the regen critical section in `flock -x <issues_dir>/.INDEX.lock`.
- **Route:** Plan
- **Relates to:** Plan DD #2, DD #9, AC-I2

### 13. `$issues_path` empty-string sanity check before `mkdir -p`

- **Severity:** Advisory
- **Description:** Plan DD #10 specifies `mkdir -p "$issues_path"` in both `/jim:issue` body and `index.sh`. If `jimconf.sh get issues_path` returns an empty string for any reason (malformed `jimconf.toml`, future config-parse bug, accidental whitespace-only value), `mkdir -p ""` fails noisily but worse — depending on quoting, the fallthrough could write to the current working directory or the wrong location.
- **Suggestion:** Validate `$issues_path` is non-empty and path-shaped before any `mkdir -p` or file write. Preferred fix is in `jimconf.sh`: refuse to return empty for a path-typed key (return `NOT_FOUND` instead, which both call sites already handle via the sentinel convention). Alternative fix: per-call-site `[[ -z "$issues_path" ]] && { echo "issues_path empty" >&2; exit 1; }` guard.
- **Route:** Plan
- **Relates to:** Plan DD #10, `jimconf.sh` path-key dispatch

### 14. Smoke-test temp-dir naming uses PID instead of `mktemp -d`

- **Severity:** Advisory
- **Description:** Plan tasks 7 and 9 Verify commands use `/tmp/jim-issues-smoketest-$$` and `/tmp/jim-issues-render-$$` for smoke-test scratch directories. PID-based naming is predictable — a hostile process can pre-create the dir with restrictive permissions to break the test; a CI runner sharing /tmp could see PID collisions across builds. `mktemp -d` is the POSIX-canonical safer pattern.
- **Suggestion:** Replace `/tmp/jim-issues-...-$$` patterns in plan tasks 7 and 9 Verify commands with `$(mktemp -d -t jim-issues-XXXXXX)`. Trivial change; aligns with `CLAUDE.md` → Testing ("Always use temporary directories for test files, never production paths") — but also use safer temp-dir naming within `/tmp`.
- **Route:** Plan
- **Relates to:** Plan Task Breakdown — tasks 7, 9 Verify commands

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 4 (resolved) — prompt-injection content posing as authoritative instruction. |
| Tampering | Yes | Finding 6 (deferred) — INDEX.md tampering window; Finding 4 (resolved) — content alters agent behavior; Finding 10 (new) — atomic-write strategy needed to avoid mid-write corruption; Finding 12 (new) — concurrent regen race. |
| Repudiation | N/A | Single-developer threat model per `ARCHITECTURE.md`; git history is the v1 audit trail. Finding 8 (resolved) names git explicitly. |
| Information Disclosure | Yes | Finding 5 (resolved) — secret capture via confirm reminder; Finding 4 (resolved) — injection-driven exfiltration consequence; Finding 9 (new) — parsing fragility could mis-attribute relations and leak edges into the wrong context. |
| Denial of Service | N/A | Local filesystem, single-user session; index-regen cost at scale is addressed by AC-I2 and research § Security & Performance. |
| Elevation of Privilege | N/A | No privilege model in jim's v1 — single user, no roles, no auth. |

## Artifact Misalignment

No spec ↔ plan misalignment identified. The plan's Requirements Coverage Summary maps every spec AC (including the security-driven additions AC-C7, AC-I4, AC-S1-extended, AC-S2) to at least one task. Design decisions DD #3 (no-eval parsing), DD #5 (slug normalization), DD #6 (wikilink parser), DD #7 (bidirectional integrity), DD #8 (subordinate-agent wrapping) directly implement those ACs.

The Notable findings surfaced in this dual-lens review (Findings 9, 10) are plan-phase design gaps — not spec ↔ plan misalignment. The spec is silent on parsing strategy and atomic-write because those are implementation concerns (correctly delegated by the spec to the plan). The plan simply needs more detail in those two design areas.

## Routing Recommendations

### Spec amendments

No additional spec amendments required. All Notable findings from the original spec-lens review (Findings 1–4) and the spec-routed Advisories (5, 8) are addressed in the amended ACs.

### Plan amendments

- **Finding 9** — Add a design decision (or extend DD #3) specifying the nested-YAML `relations:` parsing approach for `index.sh` (frontmatter-bounded scan, 2-space-indented map, indent-aware `awk` state machine, malformed → Integrity Warning).
- **Finding 10** — Add a design decision (or extend DD #9) specifying atomic INDEX.md write: write to `.INDEX.md.tmp.$$`, `mv` on success, `trap` cleanup on failure.
- **Finding 11** — Set `LC_ALL=C` in the script preamble for `index.sh`, `render.sh`, and the new `jimfile.sh` slug-related branches.
- **Finding 12** — Document the single-developer concurrency assumption in plan Out of Scope (or DD #2 / DD #9). Defer `flock` to v2.
- **Finding 13** — Sanity-check `$issues_path` is non-empty before `mkdir -p`. Preferred: fix in `jimconf.sh` (return `NOT_FOUND` for empty path values). Alternative: per-call-site guard.
- **Finding 14** — Replace `/tmp/jim-issues-...-$$` with `$(mktemp -d -t jim-issues-XXXXXX)` in Verify commands for tasks 7 and 9.
- **Finding 6** (deferred) — Plan Out of Scope acknowledges INDEX.md tampering risk; defer mitigation to v2.
- **Finding 7** (deferred) — Plan Out of Scope acknowledges `origin:` link rot; defer lint to v2.
