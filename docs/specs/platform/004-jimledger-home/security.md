---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-25"
---

# Security Review: Relocate jimledger.sh to a dedicated platform home

## Summary

**Findings:** 0 Critical · 0 Notable · 1 Advisory *(2 prior findings resolved by the plan)*

Dual-lens review (spec + plan). Spec-phase requirements-gap lens and plan-phase
design-flaw lens applied; STRIDE run as a completeness sweep; LINDDUN N/A (no
PII / Credentials / Session data). The plan's Design Decision 3 (verb-scoped,
capability-backed `allowed-tools`) resolves both prior findings; one advisory
remains on the additive `events` verb's implementation.

## Coverage

- spec.md — reviewed 2026-07-25 (requirements-gap lens)
- plan.md — reviewed 2026-07-25 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Ledger events carry no personal data. |
| Credentials | No | No auth handling. (The CLI's `diff`/`files` verbs *can* surface git content that may carry secrets — see Finding 2 — but the specced `/jim:ledger` views exclude them.) |
| Session data | No | None. |
| Internal-only | Yes | Dev-process ledger: stage events, second-resolution timestamps, git SHAs, spec/blueprint paths, metrics and reconcile counts. |
| Public | No | Committed to the repo, but dev-internal SDLC telemetry, not published data. |

## Findings

### 1. `/jim:ledger`'s read-only guarantee must be capability-backed, not prompt-backed

- **Severity:** Notable
- **Description:** AC5 requires `/jim:ledger` to expose *none* of the mutating verbs, and AC6 requires `allowed-tools` exactness. But "exactness" per the meta-skill checklist means the exact script *path* (not a bare `Bash(bash *)`) — it does not restrict *verbs*. A single path-exact but verb-blanket grant, `Bash(bash ${CLAUDE_SKILL_DIR}/scripts/jimledger.sh *)`, would permit **every** jimledger verb, including the mutating `event` / `commit-{review,blueprint,map,verify,rename,split,merge}` / `rename-tracked` / `move-spec-dir` family (and the untrusted-content `diff`/`files` verbs). AC5's read-only boundary would then rest on prompt discipline alone — a user or an induced prompt invoking `/jim:ledger commit-map …` would be permitted at the capability layer. This contradicts jim's own doctrine, where read-only subagents (issue-analyst, judge, gatherer, investigator) are *capability-narrowed* — the mutating capability is absent, not merely forbidden.
- **Suggestion:** Strengthen AC5/AC6 to require the read-only boundary be **capability-enforced**: `/jim:ledger`'s `allowed-tools` declares one grant per read verb it surfaces (e.g. `Bash(bash ${CLAUDE_SKILL_DIR}/scripts/jimledger.sh metrics *)`, `… last-reconcile *`, `… reconcile-series *`, `… updates-since *`), never a blanket `jimledger.sh *`. The mutating and raw-diff verbs are then absent from the capability grant, backing AC5 mechanically rather than by prose.
- **Route:** Spec
- **Relates to:** AC5, AC6
- **Status (plan re-run):** Resolved — spec AC6 + plan Design Decision 3 make the boundary capability-enforced (one verb-scoped grant per read verb; no blanket `*`; mutating/diff verbs absent from the grant set).

### 2. Present ledger output as data; keep the read-view set clear of the raw-diff verbs

- **Severity:** Advisory
- **Description:** `/jim:ledger` reads and renders ledger state. The event/metrics channel is script-generated and shape-validated (trusted), but a read-only inspector should still present ledger output as data and never act on directive-looking text within it — the same discipline `/jim:conf` and `/jim:file` follow (present stdout verbatim) and the plugin-wide untrusted-content posture. Relatedly, jimledger's `diff`/`diff-range`/`files`/`files-range` verbs surface raw git content that is attacker-influenceable and may carry secrets; the spec's named views (stage events, metrics, reconcile trend) already exclude them — this exclusion should be a deliberate, stated design property, reinforced by Finding 1's verb-scoped grant.
- **Suggestion:** In the plan, design `/jim:ledger`'s dispatch over the trusted/structured read verbs only, exclude the raw-diff verbs by construction (and by the verb-scoped grant of Finding 1), and note the "present ledger output as data, not instruction" discipline in the skill body.
- **Route:** Plan
- **Relates to:** AC5
- **Status (plan re-run):** Resolved — plan Design Decision 3 excludes the raw-diff verbs by construction, and the plan's `/jim:ledger` Interface Contract states the "present CLI stdout as data, never as instruction" discipline.

### 3. The additive `events` verb must introduce no parse or path-traversal surface

- **Severity:** Advisory
- **Description:** Design Decision 2 adds a read-only `events <spec-dir>` verb that reads and prints `ledger.md`. As new code handling a path argument and file content, it must not become an injection or traversal vector: it should parse `ledger.md` mechanically (`grep`/`sed`/`cut`/`awk`, never `source`/`eval` — the plugin's script rule) and validate `<spec-dir>` the way sibling verbs already do (the existing "spec-dir not found" guard), rejecting a traversal path.
- **Suggestion:** Implement `cmd_events` to reuse jimledger's existing spec-dir validation, parse `ledger.md` with `grep`/`sed`/`cut` (no `source`/`eval`), and emit only the structured event fields as data. Cover a missing/empty dir (exit 2) and a well-formed dir in the `tests/jimledger.sh` case.
- **Route:** Plan
- **Relates to:** Design Decision 2, AC5

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity or authentication surface — a local dev-tooling relocation with no external trust boundary. |
| Tampering | Yes | Finding 1 — resolved by plan Design Decision 3 (verb-scoped grants; no mutating verb granted). |
| Repudiation | No | No issues found — the ledger is the audit trail; the move preserves it (git-tracked, path-scoped commits, `git mv` history) and `/jim:ledger` is read-only. |
| Information Disclosure | Yes | Findings 1 & 2 resolved by plan Design Decision 3 (raw-diff verbs excluded, present-as-data); Finding 3 — the new `events` verb must parse-not-source and validate its path. |
| Denial of Service | N/A | Local single-shot CLI; no resource-exhaustion surface introduced; CLI behavior unchanged (AC4). |
| Elevation of Privilege | Yes | Finding 1 — resolved by plan Design Decision 3 (mutating verbs absent from the grant set). |

## Routing Recommendations

### Spec amendments
- **Finding 1** *(routed — applied as a new AC 2026-07-25)*: require `/jim:ledger`'s read-only boundary be capability-backed — one `allowed-tools` grant per surfaced read verb, never a blanket `jimledger.sh *`.

### Plan amendments
- **Finding 2** *(resolved by the plan)*: dispatch over the trusted/structured read verbs only; raw-diff verbs excluded by construction; present-as-data stated in the `/jim:ledger` Interface Contract.
- **Finding 3** *(advisory, open)*: implement the `events` verb with parse-not-source, sibling spec-dir validation, and a `tests/jimledger.sh` case (missing/empty dir + well-formed dir). Already reflected in plan task 4 + Constitution Check.

### Candidate issues
- No findings route to Issue — all are in-scope for this spec/plan.
