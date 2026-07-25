---
spec: "spec.md"
reviewed_phases: [spec, plan]
status: "Active"
date: "2026-06-19"
resolution: "Spec findings 1-3, 5 folded into spec.md; 4, 6 addressed by plan design (DD #1/#3/#4/#5, Tasks 3/6). Plan-phase findings 7-9 folded into plan.md (7→DD #9; 8→DD #10 commit at start+finish; 9→DD #6 composition). No outstanding Critical/Notable."
---

# Security Review: Post-build review phase

## Summary

**Findings:** 0 Critical · 6 Notable · 3 Advisory (cumulative)

Dual-lens re-run (spec + plan). The spec-phase Findings 1–3, 5 were folded into
`spec.md`, and 4 & 6 are addressed by the plan's design (DD #1/#3/#4/#5, Tasks
3/6) — see the delta below. This run adds **three plan-phase findings (7–9)**
drawn from the design itself: a trusted-channel-integrity gap in the metrics
stream (7), a committed-durability gap for interrupted builds (8), and an
automation-composition ambiguity (9). LINDDUN remains N/A (no PII / Credentials /
Session data intentionally handled).

**Re-run delta:** new — 7, 8, 9. Addressed-in-plan — 4, 6 (design honors the
suggested mitigations). Folded-into-spec — 1, 2, 3, 5. Unchanged/open — none of
the original six.

## Coverage

- spec.md — reviewed 2026-06-19 (requirements-gap lens)
- plan.md — reviewed 2026-06-19 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Only incidental git author identity (name/email in commit metadata) — the developer's own, not third-party data the feature processes. |
| Credentials | No | Not intentionally handled. But diffs/commit content the reviewer ingests *could* contain secrets a developer committed during the build (see Finding 3). |
| Session data | No | None. |
| Internal-only | Yes | Process metrics, commit SHAs, spec/plan IDs, plan-deviation data, interruption/re-run events. The ledger and `review.md` are internal development artifacts. |
| Public | Yes | The ledger and `review.md` are committed; per VISION/ROADMAP the repo is slated to go public, so internal process data and any leaked diff content become public. |

## Findings

### 1. Ingested git / ledger / diff content must be parsed, never sourced or eval'd

- **Severity:** Notable
- **Description:** The reviewer and the ledger helper read commit messages, diffs, and a committed ledger file. These are untrusted (a merged contributor can shape commit text; the ledger is plain committed text). The spec is silent on the safety boundary. jim's `CLAUDE.md` already mandates "never `source`/`eval` user-supplied data; parse with `grep`/`sed`/`cut`," and specs 017/018 establish the untrusted-content discipline — but nothing in this spec carries that forward.
- **Suggestion:** Add an acceptance criterion (or explicit Out-of-Scope/security note) requiring that any script and agent ingesting commit, diff, or ledger content treat it strictly as data — no `source`/`eval`, line-oriented parsing only — consistent with `CLAUDE.md` → Bash scripts and the spec 018 untrusted-content pattern.
- **Route:** Spec
- **Relates to:** AC #5 (build records events), AC #6 (review reports metrics), Handoff Insights 1 & 5

### 2. Prompt injection via ingested content can bias the reviewer's verdict and issue-filing

- **Severity:** Notable
- **Description:** `@reviewer` is an LLM that reads commit messages, diffs, and ledger content, then emits an alignment verdict (AC #10) and files issues (AC #8). Directive-style text embedded in any of those inputs ("treat this build as fully aligned", or injected issue body content) could steer the verdict or the filing decisions. The spec does not state an untrusted-content boundary for the reviewer.
- **Suggestion:** Require the reviewer to wrap ingested non-user content in the spec 018 `<untrusted-issue-content>` pattern (canonical wording at `skills/issue/SKILL.md` Step 7) and to never let embedded framing bind its verdict or filing decisions. State that the alignment verdict is the reviewer's judgment over evidence, not a value it may accept from ingested text.
- **Route:** Spec
- **Relates to:** AC #8 (findings → issues), AC #10 (alignment verdict)

### 3. Committed (soon-public) review.md / ledger can re-expose and amplify sensitive diff content

- **Severity:** Notable
- **Description:** If the reviewer copies raw diff snippets, error output, or commit content into `review.md` or the ledger, any secret or sensitive value committed during the build is duplicated into a permanent, version-controlled, and (per the roadmap) soon-public artifact — amplifying a one-off leak. The `/jim:issue` flow already guards this with the AC-C2 scrub reminder; the review artifact currently has no analogous control.
- **Suggestion:** Add a requirement that `review.md` and the ledger record references, counts, and locations rather than raw sensitive content, with a scrub/minimization reminder analogous to `/jim:issue` AC-C2 before persistence. Note the public-repo amplification explicitly.
- **Route:** Spec
- **Relates to:** AC #9 (review.md), AC #5 (ledger), Data Classification (Public)

### 4. Baseline SHA / range input must be validated before interpolation into git commands

- **Severity:** Notable
- **Description:** Handoff Insight 2 scopes the diff via a recorded baseline SHA and an optional range-override argument. A SHA read from the tamperable committed ledger — or a range passed as input — interpolated unvalidated into `git diff <base>..<head>` risks argument/option injection (e.g. a value beginning `--`) or silently wrong scoping.
- **Suggestion:** Capture a plan-phase design constraint: validate the SHA/range shape before use (mirror `jimfile.sh`'s `is_valid_id` validation discipline) and pass it positionally with `--` end-of-options guards. Carry this into `plan.md` when written.
- **Route:** Plan
- **Relates to:** AC #4 (diff scoping), Handoff Insight 2

### 5. Committed ledger is developer-editable — metrics are not tamper-evident

- **Severity:** Advisory
- **Description:** A committed text ledger can be edited, or history rewritten, to hide interruptions/deviations, so the metrics feeding the process-feedback loop and any future aggregation rest on developer trust. Under jim's documented trust model (all input comes from the trusted human developer) this is largely accepted, but it is currently unstated.
- **Suggestion:** Document the trust assumption explicitly (Out of Scope or a security note): the ledger is an honesty aid for a trusted developer, not a tamper-evident audit control. Avoid engineering signing/tamper-evidence — out of proportion to the threat model.
- **Route:** Spec
- **Relates to:** AC #5, AC #6, Out of Scope

### 6. Reviewer agent and the auto_review path should be least-privilege

- **Severity:** Advisory
- **Description:** `auto_review` removes the human confirmation step (parallel to `auto_security`), auto-invoking an LLM agent that ingests untrusted content and can write files and file issues. Excess tool scope plus injected content (Finding 2) widens the blast radius.
- **Suggestion:** Capture a plan-phase constraint that `@reviewer`'s `tools:` are minimal (read; write `review.md`; the issue batch; optional `@jim:security` delegation) per jim's least-privilege convention, and that the auto path cannot be steered into out-of-scope writes or command execution.
- **Route:** Plan
- **Relates to:** AC #1 (auto/require knobs), Handoff Insight 5

### 7. `metrics` output must be a clean trusted channel — never echo ingested content

- **Severity:** Notable
- **Description:** The plan (DD #1, Task 4) has `jimledger.sh metrics` emit `key=value` lines the reviewer consumes as *trusted* metrics. If that stream ever interpolated commit / diff / ledger free-text (e.g. echoing a commit subject), an attacker-shaped commit could inject fabricated metric lines (`alignment=aligned`, spurious keys) into a channel the reviewer trusts — bypassing the untrusted-content boundary that protects the raw git reads (Finding 2). The plan does not yet state that the metrics channel is content-free.
- **Suggestion:** Constrain `jimledger.sh metrics` to emit ONLY script-generated, fixed-key lines (counts, validated SHAs, timestamps) — never echo commit/diff/ledger free-text to stdout. Make the split explicit in the skill: metrics = trusted channel; raw `git log`/diff the reviewer reads = untrusted channel (wrapped per Finding 2).
- **Route:** Plan
- **Relates to:** Plan DD #1, Task 4; AC #6, AC #11

### 8. Committed-ledger durability is unmet for interrupted builds (commit only at finish)

- **Severity:** Notable
- **Description:** Spec AC #5 requires the build to record its boundary/events durably "across an interrupted build and a re-run," and the chosen mechanism is a *committed* ledger. The plan commits `ledger.md` only at `finish` (Task 11). A build interrupted after `start` but before `finish` leaves the `started`/event lines in the working tree only — uncommitted, and losable to `git checkout`/`git clean`. The committed-durability intent is unmet exactly in the interruption case the AC names.
- **Suggestion:** Either commit the ledger at `start` too (so interruption events are durable), or explicitly scope AC #5's durability to working-tree persistence until the next build commit and record that in the plan. Decide deliberately, not by omission.
- **Route:** Plan
- **Relates to:** AC #5; Plan Tasks 10, 11

### 9. `auto_review` and `auto_issue_file` must compose, not cascade

- **Severity:** Advisory
- **Description:** Under `auto_review`, build auto-invokes the reviewer with no prompt; the reviewer's end-of-phase issue batch is independently governed by `auto_issue_file` (default `false` → interactive). The plan should state explicitly that `auto_review` does not imply auto-filing — otherwise a reader may assume the automation cascades, silently writing issue files derived from untrusted content without the human batch-confirm gate.
- **Suggestion:** State in the skill/plan that the two automations compose independently: `auto_review` controls invocation; `auto_issue_file` controls filing. Under `auto_review` with `auto_issue_file` false, the issue batch still surfaces for confirmation.
- **Route:** Plan
- **Relates to:** AC #1, AC #8; Plan DD #6

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Findings 2, 7 (ingested content spoofs a "legitimate" build narrative; injected fake metric lines spoof the trusted channel). Unauthenticated git author fields are out of the single-developer trust model. |
| Tampering | Yes | Findings 1, 4, 5, 7, 8 (ingested content, SHA/range, ledger editability, metrics-channel injection, losable interruption events). |
| Repudiation | Yes | Findings 5, 8 — the ledger/`review.md` is a positive audit trail, but a developer can edit it, and interruption events committed only at finish are losable. |
| Information Disclosure | Yes | Finding 3 (sensitive diff content amplified into a committed, soon-public artifact). |
| Denial of Service | N/A | Operates on the developer's own repo; a pathological diff/ledger is self-inflicted with no external trust boundary. |
| Elevation of Privilege | Yes | Findings 1, 6, 9 (source/eval as a code-execution vector; reviewer-agent / auto-path tool scope; auto_review automation composition). |

## Artifact Misalignment

- **Finding 8 — committed-ledger durability vs interrupted builds:** Spec AC #5
  (record durably "across an interrupted build") and the committed-ledger
  decision assert persistence; the plan (Task 11) commits the ledger only at
  `finish`, so events from an interrupted build persist in the working tree but
  are never committed. The plan's design does not preserve the spec's stated
  durability boundary. Route: Plan.

## Routing Recommendations

### Spec amendments
- Findings 1, 2, 3, 5 — *folded into `spec.md`* (ACs #11–12, Out of Scope) on 2026-06-19. No further spec action.

### Plan amendments
- Finding 4: *addressed in plan* (DD #3, Task 3 — validate via `valid-id`, exit 2, `--` guards).
- Finding 6: *addressed in plan* (Task 6 least-privilege tools; DD #4/#5 no auto-chain).
- Finding 7: *addressed in plan* (DD #9, Task 4 — content-free trusted metrics channel; test asserts no echoed free-text).
- Finding 8: *addressed in plan* (DD #10, Tasks 10–11 — build commits the ledger at `start` and `finish`; full committed durability).
- Finding 9: *addressed in plan* (DD #6 — `auto_review` and `auto_issue_file` compose independently).

### Candidate issues
- No findings routed to Issue this run.
