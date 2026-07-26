---
spec: "docs/specs/platform/007-id-coordination-allocator/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-26"
---

# Security Review: ID coordination allocator (foundation)

## Summary

**Findings:** 1 Critical · 6 Notable · 2 Advisory

Spec-only review (no plan.md yet) of a substrate that reads an untrusted,
branch-writable registry and turns its content into git refs, git command
arguments, and filesystem paths. The dominant risk class is trusting replayed
registry/config content before revalidating it. LINDDUN is N/A — no PII,
credential, or session data is handled (the `<who>` attribution field only
duplicates identity already present in git commit metadata).

**Re-run 2026-07-26 (spec hardened).** The four Spec-routed findings (F1–F4)
are resolved by the folded-in ACs and non-goals; no new findings surfaced from
the hardening or the resolved open questions (`peek` reuses the existing
parse-and-revalidate discipline and never binds; the registry-only orphan
branch shrinks the untrusted surface). F5–F7 remain open, routed to the plan
that does not yet exist. Status advances Needs Spec Review → Needs Plan Review:
spec-level security is clean; one Notable plan-level concern (F5) awaits
`/jim:plan`.

**Plan-phase 2026-07-26 (dual lens).** With plan.md present, the design-flaw
lens confirms F5–F7 are discharged by plan tasks (containment → Task 9; backoff
+ low-traffic default → Tasks 1/8; non-interactive git → Tasks 2/8). Two new
Notable design findings surfaced — F8 (write-side record forgery via
unsanitized fields) and F9 (erosion-baseline integrity) — both routed to Plan.
No spec↔plan misalignment. Status remains Needs Plan Review pending F8/F9.

**Verification 2026-07-26 (dual lens, third pass).** Re-reviewed the amended
plan: F8 is discharged by DD 7 + Tasks 3/5 (the emit-encoder sanitizes every
appended field, with an adversarial forge verify) and F9 by DD 8 + Task 7
(local-only erosion baseline, with an erosion-still-detected verify). No new
findings — the amendments only add sanitization and constrain baseline storage.
All nine findings are now resolved (F1–F4, spec) or discharged (F5–F9, plan).
Status advances Needs Plan Review → Active.

## Coverage

- spec.md — reviewed 2026-07-26 (requirements-gap lens); re-reviewed 2026-07-26 after F1–F4 routed in
- plan.md — reviewed 2026-07-26 (design-flaw + dual lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Registry records carry a `<who>` author handle, but it is the same identity git already records in every commit — no new personal-data collection. |
| Credentials | No | Allocation relies on the developer's ambient git auth (SSH/token/credential-helper) for push/fetch; it neither stores nor transmits new secrets. |
| Session data | No | None. |
| Internal-only | Yes | Registry ids, slugs, group names, author handles, dates — project-internal metadata living on the shared coordination branch. |
| Public | No | Registry is visible to everyone with repo read access, but is not intended for external publication. |

## Findings

### 1. Replayed registry and config-derived tokens must be revalidated before reaching git or the filesystem

- **Severity:** Critical
- **Description:** The coordination branch is writable by everyone running jim (it is *less* protected than main — the spec's own premise), so the registry is attacker-controllable input. AC 13 requires the registry be parsed as data and never sourced — necessary, but not sufficient. Replayed tokens (ids, slugs, group names) and the config-supplied `coordination_branch` are consumed as git ref names, git command arguments, and directory paths. A crafted record — an id of `--upload-pack=…`, a group name bearing ref metacharacters, a `..`-laden slug — yields git option-injection (arbitrary command execution) or path traversal. The spec has no AC asserting that *replayed/config-derived* tokens are revalidated before use; AC 11/AC 13 cover freshly-computed ids and no-source parsing, not replay-then-use.
- **Suggestion:** Add an acceptance criterion: every registry-replayed or config-derived token must pass the id/slug/ref-name charset boundary (`is_valid_id` / `is_valid_slug`) and reach git only under the option-injection guards jim already establishes — `--end-of-options` for refs/SHAs, `--` for pathspecs, `--literal-pathspecs` for path arguments — before it is used as a ref, argument, or path. This makes explicit the discipline `jimledger.sh` (:160-260) and `jimpartition.sh` already apply, so the plan cannot omit it.
- **Route:** Spec
- **Relates to:** AC 5, AC 13
- **Resolution (re-run 2026-07-26):** Resolved — a new AC requires every value read from the registry or supplied by configuration to be revalidated through the id/slug/name boundary before it is used as a git argument, ref, or filesystem path; Handoff Insight 5 carries the concrete gates (`is_valid_id` / `--end-of-options` / `--` / `--literal-pathspecs`).

### 2. State that registry attribution and IDs are not authorization or integrity anchors

- **Severity:** Notable
- **Description:** The `<who>` and timestamp fields are self-asserted and land on a low-protection branch — a contributor can write any `<who>` into their own registry line. The research notes IDs must never serve as authorization or integrity anchors, but the spec does not say so. Without an explicit non-goal, a downstream feature could mistake the registry for an audit trail or treat an ID/`<who>` as a security control.
- **Suggestion:** Add an Out-of-Scope / non-goal statement (or AC) declaring registry records advisory provenance only — not an audit trail, not an authentication or authorization source — so no consumer builds a security decision on them.
- **Route:** Spec
- **Relates to:** AC 12, Out of Scope
- **Resolution (re-run 2026-07-26):** Resolved — an Out-of-Scope non-goal declares registry records advisory provenance only, never an authentication/authorization/integrity/audit anchor.

### 3. AC 10's erosion guard is scoped to locally-known history — say so

- **Severity:** Notable
- **Description:** The byte-prefix growth guard detects force-push/revert erosion only relative to a registry the client has *previously seen*. A first-time clone that fetches an already-rewritten log has no baseline and cannot detect pre-existing erosion; AC 10 as written ("the next allocation detects the erosion") over-promises for that case.
- **Suggestion:** Scope AC 10 to erosion "relative to locally-known history," and name the coordination-branch protection profile (force-push and deletion denied) as the *primary* control, with the byte-prefix guard as defense-in-depth. This aligns the promised guarantee with what the mechanism can actually enforce.
- **Route:** Spec
- **Relates to:** AC 10
- **Resolution (re-run 2026-07-26):** Resolved — the erosion AC is rescoped to detection relative to locally-known history and names force-push/deletion denial on the coordination point as the primary control, with the byte-prefix guard as defense-in-depth.

### 4. Allocation discloses derived slugs on the shared branch before merge

- **Severity:** Notable
- **Description:** Allocation publishes the derived slug to the coordination branch at spec/issue-creation time — before the work merges. A slug derived from a sensitive title (`acquire-competitor-x`, `fix-embargoed-cve-in-auth`) becomes visible to everyone with repo read access earlier than today's on-branch-only behavior. This is a new information-disclosure surface the reservation-ahead-of-content model introduces, independent of the `issue_placement` content/reservation choice (even reservation-only leaks the slug).
- **Suggestion:** Acknowledge the reservation-time disclosure surface in the spec, and note an opaque-reservation option (allocate against a non-descriptive token, bind the human-readable slug at merge) as a follow-on for teams that reserve sensitive work. Filing intent is the developer's call.
- **Route:** Spec
- **Relates to:** AC 1, Problem Statement
- **Resolution (re-run 2026-07-26):** Resolved — an Out-of-Scope note acknowledges the reservation-time slug-disclosure surface and flags opaque reservation (opaque token at reservation, readable slug bound at merge) as a follow-on.

### 5. Registry writes need the worktree-containment guard

- **Severity:** Notable
- **Description:** Writing the registry file (and, in worktree-mode, checking out the coordination branch) is a mutating filesystem/git operation. Jim's existing mutating verbs enforce a containment guard — every target resolved inside `git rev-parse --show-toplevel`, symlink escape refused before any write, never `git add -A`. The spec does not require the allocator's writes to observe the same guard, so a symlinked or out-of-tree registry path could escape containment.
- **Suggestion:** In the plan, require the registry write path and any worktree checkout to pass the same containment discipline as `jimledger.sh` / `jimpartition.sh`'s mutating verbs (worktree-top containment, symlink refusal, literal path staging).
- **Route:** Plan
- **Relates to:** Research & Architecture Handoff Insight 2
- **Resolution (plan-phase 2026-07-26):** Discharged — plan Task 9 requires the write-containment guard (target resolved inside `git rev-parse --show-toplevel`, symlink-escape refused before any object write or ref update).

### 6. Bound contention starvation with backoff and a low-traffic default branch

- **Severity:** Advisory
- **Description:** The registry compare-and-swap (CAS) races with *all* pushes to the coordination branch, not just allocations. On a busy branch — or under deliberate push-spam by an authenticated team member — allocation can repeatedly lose the race. AC 2's bounded-retry-then-hard-fail keeps this fail-loud (no corruption, no duplicate), so the impact is degraded availability of ID issuance, not integrity loss.
- **Suggestion:** In the plan, specify retry backoff with jitter, and prefer a dedicated low-traffic `jim/registry` branch as the shipped default (the spec's own open question) to minimize non-allocation contention.
- **Route:** Plan
- **Relates to:** AC 2, AC 9
- **Resolution (plan-phase 2026-07-26):** Discharged — plan Task 1 sets the low-traffic `jim/registry` default and Task 8 specifies retry backoff with jitter.

### 7. Make git non-interactive during allocation

- **Severity:** Advisory
- **Description:** Allocation fires inside interactive skill flows (`/jim:spec`, `/jim:issue`). A push/fetch that triggers an interactive credential prompt can hang the flow; a sandbox that blocks pushes by policy fails it. AC 9 already unifies network/auth/policy unreachability as a loud hard-fail — the residual requirement is ensuring git cannot *block* waiting for input.
- **Suggestion:** In the plan, run allocation git with `GIT_TERMINAL_PROMPT=0` (and equivalent non-interactive settings) so an auth failure surfaces as the AC 9 hard-fail rather than a hang, and allocate as late in the consumer flow as possible.
- **Route:** Plan
- **Relates to:** AC 9, Research & Architecture Handoff Insight 2
- **Resolution (plan-phase 2026-07-26):** Discharged — plan Task 2 sets `GIT_TERMINAL_PROMPT=0` in the preamble and Task 8 confirms non-interactive git with allocate-late.

### 8. Write path must sanitize every field it appends to the registry

- **Severity:** Notable
- **Description:** The plan validates tokens on *read* (Task 3), but the *emit* path (Tasks 5/6) appends a space-separated record that includes a free-text `<who>` taken from `git config user.name` (plan Open Questions). The registry log is newline-delimited and space-separated; a `user.name` (or any free-text field) containing a newline or the field delimiter could inject a forged `allocate` line — claiming an id, or shifting forward-replay resolution. Read-side validation degrades such a line, but the log is now corrupted and a plain `grep` over it is misled.
- **Suggestion:** In the plan, require the record-emit path to sanitize/encode every field before appending — strip or reject newlines and the field delimiter in free-text values (`<who>`, and any slug/subject not already normalized), mirroring the field-sanitization `jimverify.sh`/`index.sh` already apply (tabs/newlines stripped, length-capped). Add it as an explicit sub-requirement of Tasks 5/6 with its own adversarial verify (a `git config user.name` bearing a newline cannot forge a second record).
- **Route:** Plan
- **Relates to:** AC 15, plan Tasks 5/6
- **Resolution (verified 2026-07-26):** Discharged and verified (dual-lens re-run) — plan DD 7 (encode-on-write / validate-on-read) and Tasks 3 (emit-encoder) + 5 (sanitized `<who>` with an adversarial forge verify).

### 9. The erosion-guard baseline must be local and trusted

- **Severity:** Notable
- **Description:** Task 7's byte-prefix growth guard compares the fetched registry against a "last-seen" cache, but the plan does not specify where that baseline is stored. If it lives on the coordination branch (or is otherwise derived from the untrusted registry), an attacker who force-pushes a rewritten history also rewrites the baseline, and the guard silently passes — defeating AC 11's erosion detection entirely.
- **Suggestion:** In the plan, require the seen-state baseline to be stored locally and outside the coordination branch (e.g. under the clone's local git dir or a local state file), never fetched from or committed to the registry, so the comparison is against a trusted local record. Add it to Task 7 with a verify (a rewritten history is detected even after the attacker controls branch content).
- **Route:** Plan
- **Relates to:** AC 11, plan Task 7
- **Resolution (verified 2026-07-26):** Discharged and verified (dual-lens re-run) — plan DD 8 (local-only erosion baseline) and Task 7 (baseline outside the coordination branch, with an erosion-still-detected verify).

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 2 (self-asserted `<who>` attribution on a low-protection branch) |
| Tampering | Yes | Finding 1 (injection via replayed tokens), Finding 3 (history erosion), Finding 5 (write containment), Finding 8 (write-side record forgery), Finding 9 (erosion-baseline integrity) |
| Repudiation | Yes | Finding 2 (registry is advisory provenance, not an audit trail) |
| Information Disclosure | Yes | Finding 4 (reservation-time slug disclosure) |
| Denial of Service | Yes | Finding 6 (contention starvation), Finding 7 (auth-prompt hang) |
| Elevation of Privilege | Yes | Finding 1 (git option-injection is the EoP vector; jim itself has no in-app privilege tiers to escalate within) |

## Artifact Misalignment

*Dual-lens (spec.md + plan.md) — spec↔plan consistency.*

- **None found.** The plan faithfully implements every spec AC: `allocate`-only emission with the full grammar parsed/resolved (AC 6/7), two-tier CAS matching reachability (AC 9), erosion detection scoped to locally-seen history (AC 11), and the read-side revalidation boundary (AC 13). F5–F7 (the spec's Plan-routed findings) are discharged by plan Tasks 1/2/8/9. F8 and F9 are *new design-level* findings the plan does not yet cover — not spec↔plan contradictions.

## Routing Recommendations

### Spec amendments
*Applied 2026-07-26 — all four folded into spec.md; see each finding's Resolution note above.*

- Finding 1: add an AC requiring revalidation of every replayed/config-derived token through the id/slug/ref boundary before it reaches git or the filesystem (`--end-of-options` / `--` / `--literal-pathspecs`).
- Finding 2: add a non-goal — registry records are advisory provenance, never an authorization/integrity/audit anchor.
- Finding 3: scope AC 10 to locally-known history; name the branch-protection profile as the primary erosion control.
- Finding 4: acknowledge reservation-time slug disclosure; note opaque-reservation as a follow-on.

### Plan amendments
*F5–F7 discharged 2026-07-26 by plan Tasks 1/2/8/9 (see per-finding Resolution notes). F8–F9 are new and open.*

- Finding 5: require the worktree-containment guard on all registry writes. — **discharged (Task 9)**
- Finding 6: specify retry backoff+jitter and a low-traffic default coordination branch. — **discharged (Tasks 1/8)**
- Finding 7: run allocation git non-interactively (`GIT_TERMINAL_PROMPT=0`); allocate late. — **discharged (Tasks 2/8)**
- Finding 8: **applied** — plan DD 7 + Tasks 3/5 (emit-encoder sanitizes every appended field; adversarial forge verify).
- Finding 9: **applied** — plan DD 8 + Task 7 (erosion baseline stored locally, outside the coordination branch; erosion-still-detected verify).

### Candidate issues
- None — no findings routed to Issue this run.
