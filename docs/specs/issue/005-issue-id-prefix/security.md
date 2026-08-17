---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-06-14"
---

# Security Review: Configurable issue-id prefix

## Summary

**Findings:** 0 Critical · 0 Notable · 1 Advisory · 4 Resolved

Plan-phase re-review of 2026-06-14 (dual spec+plan lens). All four prior findings are
now resolved: 1 & 2 folded into the spec (AC #7, AC #11); 3 (strftime / no-`eval`)
implemented by plan Decision 6; 4 (`show` ambiguity) handled as the plan's
accepted-degradation path (`render.sh` already multi-match reports). One new Advisory
(5) surfaced from the plan: the `is_valid_id` validator is triplicated across three
scripts and hand-synced — add a consistency test to catch drift. LINDDUN N/A (no PII /
credentials / session data).

## Coverage

- spec.md — reviewed 2026-06-13 (requirements-gap lens; re-reviewed 2026-06-14 after folding Findings 1 & 2)
- plan.md — reviewed 2026-06-14 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Issue ids/prefixes are project-internal naming; no individual identification. |
| Credentials | No | No secrets handled. |
| Session data | No | None. |
| Internal-only | Yes | Issue filenames/ids and the `issue_id_*` config are project-internal identifiers, committed to the repo; non-secret by design (spec 017/019). |
| Public | No | The prefix config is not externally-exposed sensitive data. |

## Findings

### 1. Resolved prefix should use a bounded allowlist, not a forbidden-char denylist

- **Severity:** Notable
- **Description:** AC #7 relaxes jim's documented security boundary — the slug allowlist `^[a-z0-9][a-z0-9-]*$` (`ARCHITECTURE.md` → "Slug pipeline is the security boundary"; `jimfile.sh` `normalize_slug` / `is_valid_slug`) — to "preserve the prefix verbatim within a safety floor," and expresses that floor as a *denylist* of forbidden characters (`/`, `\`, `..`, leading dot, control chars, NUL). A denylist over a verbatim string that becomes a filename is fragile: it omits a leading `-` (a filename like `-x-wire.md` is parsed as a flag by downstream `grep` / `find` / `rm` / `git`), whitespace, glob metacharacters (`* ? [ ]`), `:` and other characters invalid on non-Linux filesystems (jim runs under WSL), and non-ASCII bytes (the rest of jim is ASCII-only under `LC_ALL=C`). The resolved prefix reaches the filesystem from three input paths — a preset, the `issue_id_project` tag, and `{date:…}` / template expansion — so one guard must cover all three.
- **Suggestion:** Reframe AC #7 as a positive allowlist for the *resolved* prefix — broader than the slug's but still bounded, e.g. ASCII letters, digits, `.`, `_`, `-`, with no leading `.`/`-` and no `..` run. This admits every chosen example (`JIM`, `2026.06.13`, the `T` separator) while closing the denylist gaps, and preserves jim's "allowlist is the boundary" discipline rather than inverting it to a denylist.
- **Route:** Spec
- **Relates to:** AC #7
- **Status:** ✅ Resolved 2026-06-13 — AC #7 reframed as a bounded positive allowlist (`[A-Za-z0-9._-]`, no leading `.`/`-`, no `..`); out-of-allowlist input routes to the AC #8 malformed-config notice.

### 2. No length bound on the resolved prefix

- **Severity:** Notable
- **Description:** The slug is capped at 64 chars (`normalize_slug`), but the spec sets no bound on the resolved prefix. A long `issue_id_project` tag, or a `{date:…}` / template that expands large, can push the filename past the common 255-byte filesystem limit — the write fails (a denial of service on issue creation) — or simply produce unwieldy, unreadable ids. Length also compounds Finding 1: the longer the verbatim string, the more surface for an unguarded character.
- **Suggestion:** Add an AC bounding the resolved prefix length (mirror the slug's 64-char cap, or cap so `prefix + slug` stays well under the 255-byte filename limit). On exceed, route through the AC #8 malformed-config path — surface the notice and fall back to the default — rather than silently truncating into a different id.
- **Route:** Spec
- **Relates to:** AC #7, AC #8
- **Status:** ✅ Resolved 2026-06-13 — new AC #11 bounds the resolved prefix length; over-limit routes to the AC #8 notice rather than silent truncation.

### 3. Carry the no-`eval` / quoted-`date` discipline into the plan

- **Severity:** Advisory
- **Description:** The `{date:<strftime>}` token feeds a developer-controlled format string to `date +<fmt>`. AC #9/#10 already constrain resolution to deterministic bash with no `source`/`eval` (sourced to `CLAUDE.md` "never `source` or `eval` user-supplied data"), which is the correct boundary; this finding makes the discipline explicit at plan time so it is not lost in implementation. Risk if ignored: building the `date` invocation via unquoted expansion or `eval` would turn a format string into a command surface.
- **Suggestion:** In the plan, specify that the format string is passed as a single quoted argument to `date` (never `eval` / unquoted word-splitting), that `LC_ALL=C` is preserved for deterministic output (`ARCHITECTURE.md` Finding 11), and that a format which fails to parse routes to the AC #8 notice rather than leaking `date`'s error text into the id.
- **Route:** Plan
- **Relates to:** AC #9, Research & Architecture Handoff Insight 1
- **Status:** ✅ Resolved 2026-06-14 — plan Decision 6 implements it: `date +"$FMT"` as a single quoted arg, exit-checked under `LC_ALL=C`, output re-validated by `is_valid_id`, with `date`-failure routed to the AC #8 notice (no error text leaks into the id).

### 4. Configurable prefixes increase `show` substring-match ambiguity

- **Severity:** Advisory
- **Description:** `render.sh show` resolves an argument against the indexed set by ordinal → exact slug → prefix → substring (it never composes a filesystem path from raw input — 019 Finding 1, so this is not a traversal vector). A shared configured prefix (e.g., `JIM-` on every id, or a low-resolution date) makes the prefix/substring tiers match many issues at once, degrading `show <token>` precision. This is a usability/robustness regression the feature introduces, not a confidentiality breach.
- **Suggestion:** In the plan, confirm exact-id and ordinal resolution stay unambiguous for fully-qualified inputs, and that the prefix/substring tiers degrade predictably (report multiple matches rather than silently pick one) when a shared prefix makes them broad.
- **Route:** Plan
- **Relates to:** AC #5
- **Status:** ✅ Resolved 2026-06-14 — plan accepts this as the documented degradation path: `render.sh` already reports multiple matches and asks for a more specific id (no silent pick); no code change beyond the task-8 `is_valid_id` widening.

### 5. `is_valid_id` validator is triplicated and hand-synced across three scripts

- **Severity:** Advisory
- **Description:** Plan Decision 4 introduces `is_valid_id` as the security validator for resolved prefixes and full ids, copied into `jimfile.sh`, `index.sh`, and `render.sh` (extending the existing `is_valid_slug` triplication those scripts already carry, per jim's self-contained-script convention). The copies are kept in sync only by comment. If they drift — e.g., a consumer copy becomes broader than the generator's — a hand-authored or cross-branch issue filename could pass a looser read-side guard that the write side would have rejected, weakening the filename boundary exactly where on-disk names (untrusted-by-position) are read.
- **Suggestion:** Add a bash consistency test (in `tests/`) that feeds an identical accept/reject corpus to all three `is_valid_id` copies and asserts identical verdicts, so drift fails CI rather than slipping past review. This fits jim's bash-test convention without introducing a shared sourced lib (which would break the self-contained-script rule).
- **Route:** Plan
- **Relates to:** plan Decision 4; tasks 6, 7, 8
- **Status:** Open — recommend a consistency-test task in the plan before build.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | Issue ids / `num` are non-secret display identifiers; no authentication or trust decision rests on id unguessability (predictable sequential/project ids are acceptable by design — spec 019). |
| Tampering | Yes | Findings 1, 2 resolved (folded into AC #7 / AC #11). Finding 5 (advisory) — `is_valid_id` validator-drift across three script copies; mitigated by a recommended consistency test. |
| Repudiation | N/A | No audit-trail requirement for id naming; git history is the record of issue creation. |
| Information Disclosure | No | The AC #8 malformed-config notice echoes developer-authored, non-sensitive config; plan Decision 6 ensures no `date`/error internals leak into ids. No issues found. |
| Denial of Service | No | Finding 3 resolved (plan Decision 6 + the AC #11 length cap bound strftime expansion); Finding 2's length vector resolved via AC #11. No open issues. |
| Elevation of Privilege | N/A | jim runs as the developer's own user with no privilege separation (`ARCHITECTURE.md` → Security Considerations); the directory-escape boundary is covered under Tampering (Finding 1) and escaping the issues dir gains no privilege the developer lacks. |

## Artifact Misalignment

None — the plan faithfully implements the spec's security ACs: `is_valid_id` (DD4) ↔ AC #7 bounded allowlist; the stderr notice + length cap (DD5) ↔ AC #8 / AC #11; bash-only resolution in `jimfile.sh` (DD1/DD6) ↔ AC #10. No spec requirement is weakened or contradicted by the plan's design.

## Routing Recommendations

### Spec amendments
- Finding 1 — ✅ applied 2026-06-13: AC #7 reframed from a forbidden-char denylist to a bounded positive allowlist.
- Finding 2 — ✅ applied 2026-06-13: new AC #11 bounds the resolved prefix length, with over-limit routing to the AC #8 notice path.

### Plan amendments
- Finding 3 — ✅ satisfied by plan Decision 6 (quoted single-arg `date`, exit-checked, output re-validated, failure → AC #8 notice).
- Finding 4 — ✅ satisfied: plan accepts `render.sh`'s existing multi-match reporting as the degradation path.
- Finding 5 — **open**: add a consistency test asserting the three `is_valid_id` copies agree on an identical accept/reject corpus.

### Candidate issues
No routing required — no findings routed to `Issue`.
