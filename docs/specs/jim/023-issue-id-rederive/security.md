---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-06-17"
---

# Security Review: Re-derive existing issue ids to the active prefix scheme

## Summary

**Findings:** 0 Critical · 3 Notable · 3 Advisory — all resolved (folded into spec or plan).

**Plan-phase update 2026-06-17 (dual lens):** the two carried findings are now
designed into plan.md — finding 2 (rewrite/index parity) via DD 5 + Task 5,
finding 5 (TOCTOU) via DD 6 (`--apply --expect` drift guard + idempotent retry).
The no-verb surface (DD 1/7) further dissolves finding 3 — no LLM ever touches
issue content. One new Advisory (finding 6) surfaced and was folded into plan.md (DD 2). With
no open findings, status is Active. (Earlier spec-phase pass: findings
1, 3, 4 folded into spec.md.)

Dual-lens review of a one-shot, opt-in command that renames every issue file to
its re-derived id and rewrites all inbound references. The id/slug pipeline is
the spec's declared security boundary (AC #11), so the review centers on
path-injection through that boundary, rewrite/index parser divergence, the
untrusted-content boundary on issue files, and recoverability of a destructive
operation. STRIDE applied in full; LINDDUN marked N/A (no PII / Credentials /
Session data — see Data Classification).

## Coverage

- spec.md — reviewed 2026-06-17 (requirements-gap lens)
- plan.md — reviewed 2026-06-17 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Command operates on ids, `num` ordinals, slugs, `created:` timestamps, and the relation graph — not personal data. |
| Credentials | No | No secrets handled. |
| Session data | No | No session state. |
| Internal-only | Yes | Issue ids/slugs, `num` ordinals, the typed-relation graph, and `INDEX.md` are project-internal developer metadata. |
| Public | No | Nothing published. |

## Findings

### 1. "Preserved verbatim" slug can bypass the id security boundary

- **Severity:** Notable
- **Description:** AC #11 requires every re-derived id pass the bounded allowlist + length bound (the declared security boundary). But the Out-of-Scope note "The slug and `.md` extension" says the slug is "preserved verbatim." A slug on disk may have been hand-edited since creation to contain path metacharacters (`../`, `/`), and "preserved verbatim" reads as *not validated*. If only the re-derived prefix is guarded and the carried slug is trusted, a tampered slug could steer the rename outside `issues_path` (path traversal) — exactly the escape the id pipeline exists to prevent.
- **Suggestion:** State that the allowlist + length guard applies to the **full** re-derived id — new prefix **+** carried-over slug **+** any `-2`/`-3` discriminator — not just the new prefix; a verbatim slug that fails the guard makes the issue un-migratable. Reconcile the Out-of-Scope wording so "preserved verbatim" means "not re-slugified," not "not re-validated."
- **Route:** Spec
- **Relates to:** AC #11, AC #7, Out of Scope ("The slug and `.md` extension")
- **Resolution:** Folded into spec.md — AC #11 now pins the allowlist/length guard to the full re-derived id (prefix + carried slug + discriminator); the Out-of-Scope slug note states verbatim ≠ unvalidated.

### 2. Reference rewrite must recognize references identically to the index

- **Severity:** Notable
- **Description:** AC #6 requires rewriting `relations:` targets and body `[[wikilinks]]` with no new dangling reference; AC #13 leans on `INDEX.md`'s integrity checks as the verification surface. If the rewrite recognizes references by a different rule than the index's edge parser, the two diverge: a link the rewrite misses becomes dangling (AC #6 violation); a string the rewrite touches but the index ignores corrupts content. This is concrete today — issue `20260531-wikilink-parser-skips-fenced-code-blocks` tracks the index not yet skipping `[[…]]` inside fenced code blocks, so "what counts as a wikilink" is itself in flux.
- **Suggestion:** Require the command to recognize references using the **same canonical parser the index uses** (single source of truth), matching ids on exact id boundaries (never substring/prefix), confined to the four `relations:` buckets and `[[wikilink]]` syntax — so the rewrite-set equals the index's edge-set. Carry into plan.md as a design decision (reuse `index.sh`'s relation/wikilink parser; Insight 3 already gestures at this).
- **Route:** Plan
- **Relates to:** AC #6, AC #13, Insight 3
- **Resolution:** Designed into plan.md — DD 5 (rewrite reuses `index.sh`'s relation/wikilink recognition; exact-id, structured sites only) + Task 5 asserts the rewrite touches exactly the edges `index.sh` reports (incl. the fenced-code must-not-touch case).

### 3. Untrusted-content boundary on issue files is not stated

- **Severity:** Notable
- **Description:** The command is a new reader of issue-file content (relations, wikilinks, `created:`, body). The issue system mandates that issue content is untrusted user-authored data (spec 017 AC-S2; spec 018 § Security and Safety): the deterministic layer parses it without `source`/`eval`, and embedded directives must never be interpreted as instruction. The 023 spec asserts the deterministic-bash boundary (AC #11) but does not state the untrusted-content boundary for the preview/confirm surface, where issue-derived strings are presented and an LLM (or the developer) drives the confirm.
- **Suggestion:** Add a security AC (or extend AC #11): issue-file content is untrusted — the deterministic layer parses it without `source`/`eval`; the preview surfaces only structured derived tokens (ids, counts, skip reasons), never raw issue body prose; and no embedded directive in issue content can cause the apply to proceed without the developer's explicit confirmation. Inherit the spec 017 AC-S2 / spec 018 wrapping discipline.
- **Route:** Spec
- **Relates to:** AC #8, AC #11, User Story 2
- **Resolution:** Folded into spec.md — new AC #12 states issue-file content is untrusted; the preview surfaces only derived tokens and no embedded directive can trigger apply without explicit confirmation. **Further reduced at plan time:** the no-verb design (DD 1/7) removes the LLM from the loop entirely, so the prompt-injection surface is absent — AC #12 reduces to the bash parse-as-data discipline.

### 4. Recoverability of a destructive migration is implicit

- **Severity:** Advisory
- **Description:** The command performs destructive, collection-wide renames; Out of Scope places git staging/commit on the developer. Recovery from a mistaken migration therefore depends entirely on the developer's VCS state, but the spec neither surfaces that assumption nor guards against running against an already-dirty tree, where a revert would also discard unrelated in-progress edits.
- **Suggestion:** Have the preview/confirm gate state that recovery is via the developer's VCS, and optionally warn when the issues collection has uncommitted changes so the developer can checkpoint first. Keeps the Git-ops boundary (still the developer's follow-up) while making recoverability explicit.
- **Route:** Spec
- **Relates to:** AC #8, Out of Scope ("Git operations")
- **Resolution:** Folded into spec.md — AC #8 now states recovery is via VCS and flags an uncommitted issues collection (read-only check) before the confirm.

### 5. Preview→apply staleness window (TOCTOU)

- **Severity:** Advisory
- **Resolution:** Designed into plan.md — DD 6 (`migrate.sh prefix --apply --expect <hash>` recomputes the map and aborts on drift; idempotent retry + VCS recovery cover partial failure).
- **Description:** AC #8 computes the full plan, then applies only after explicit confirmation — which may occur an arbitrary time later. Between plan computation and apply, the collection can change (an edit in another window, a concurrent jim command), making the previewed plan stale; applying it against a drifted collection could rename/rewrite on assumptions no longer true.
- **Suggestion:** In plan.md, specify that the apply phase re-validates that its planned-against inputs are unchanged (recompute the map, or fingerprint the files at apply time) and aborts / re-previews on drift, so a confirmed-but-stale plan is never applied. Low likelihood in single-user use, cheap to guard.
- **Route:** Plan
- **Relates to:** AC #8, AC #10, Insight 3

### 6. `prefix-from` should shape-validate `created:` before reshaping

- **Severity:** Advisory
- **Description:** Plan DD 2 re-derives the date/timestamp prefix by reshaping the issue's stored `created:` (stripping separators). `created:` is untrusted issue-file content; a present-but-malformed value (right shape but impossible date, or non-canonical) would reshape into a syntactically-valid but semantically-wrong prefix. `is_valid_id` (DD 4) blocks the security-critical case (path traversal via `..`/`/`), so this is integrity / defense-in-depth, not an escape — but it lets a corrupt field mint a wrong-but-valid id.
- **Suggestion:** Have `prefix-from` validate `created:` against the canonical `# SYNC(ts-shape)` pattern (spec 022) before reshaping; a present-but-malformed `created:` is un-migratable (skip + report), not reshaped. Tightens the untrusted-input → id path beyond the allowlist.
- **Route:** Plan
- **Relates to:** AC #3, AC #4, DD 2
- **Resolution:** Folded into plan.md — DD 2 / Task 2 shape-validate `created:` against the canonical ts-shape before reshaping; non-conforming → un-migratable. (Calendar validity isn't re-checked — accepted residual, consistent with the no-`date -d` constraint; `is_valid_id` still blocks any traversal.)

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | Local single-user CLI; no authentication/identity, no external actor to impersonate. |
| Tampering | Yes | Findings 1, 2, 5, 6 (all resolved) — collection-corruption vectors (path traversal, rewrite/index divergence, stale-plan apply, malformed-field → wrong id). |
| Repudiation | N/A | No audit-trail requirement for an opt-in, developer-initiated migration; the developer's VCS history is the change record. |
| Information Disclosure | No | Operates on the developer's own local data; preview surfaces only ids/counts the developer owns; no secrets handled. |
| Denial of Service | No | Bounded local operation over a finite collection; best-effort + report (AC #9) prevents abort on a bad issue; no resource-exhaustion vector. |
| Elevation of Privilege | Yes | Findings 1, 3 (resolved) — the id/slug pipeline is the security boundary; deterministic bash + allowlist keep id composition off the LLM, and the no-verb design (DD 1/7) keeps untrusted issue content out of any instruction flow entirely. |

## Artifact Misalignment

None. The plan's design preserves every boundary the spec asserts: AC #11's full-id allowlist → DD 4; AC #12's untrusted-content boundary → DD 7 (strengthened — no LLM at all); AC #8's "mutates nothing until explicit confirm" → DD 6 (read-only preview; mutation requires the explicit `--apply`). The no-verb surface is an implementation choice that satisfies the spec's preview-then-confirm AC without weakening it.

## Routing Recommendations

### Spec amendments (applied)
- Findings 1, 3, 4 — folded into spec.md (see each finding's **Resolution**).

### Plan amendments
- Findings 2, 5 — designed into plan.md (DD 5 / DD 6; see **Resolutions**).
- Finding 6 (folded): `prefix-from` shape-validates `created:` against the canonical ts-shape before reshaping; a non-conforming value is un-migratable.

### Candidate issues
No findings route to Issue — all are spec or plan amendments to the in-flight 023 work, not out-of-scope follow-ons.
