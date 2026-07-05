---
spec: "{spec id — <group>/<NNN>, e.g. jim/026}"
type: "{feature | bug | refactor — from spec.md}"
base_sha: "{baseline SHA at build start, or empty if no ledger}"
head_sha: "{head SHA at build finish, or empty}"
commits: "{n}"
commits_test: "{n}"
commits_feat: "{n}"
commits_fix: "{n}"
commits_refactor: "{n}"
files_changed: "{n}"
insertions: "{n}"
deletions: "{n}"
spec_runs: "{n, or empty if the spec stage was not instrumented}"
spec_interruptions: "{n, or empty}"
spec_duration_seconds: "{n, or empty}"
research_runs: "{n, or empty}"
research_interruptions: "{n, or empty}"
research_duration_seconds: "{n, or empty}"
plan_runs: "{n, or empty}"
plan_interruptions: "{n, or empty}"
plan_duration_seconds: "{n, or empty}"
sec_runs: "{n, or empty}"
sec_interruptions: "{n, or empty}"
sec_duration_seconds: "{n, or empty}"
build_runs: "{n, or empty}"
build_interruptions: "{n, or empty}"
build_duration_seconds: "{n, or empty}"
review_runs: "{n, or empty}"
review_interruptions: "{n, or empty}"
review_duration_seconds: "{n, or empty}"
artifacts_present: "{comma-separated artifacts present, e.g. spec,research,security,plan,ledger}"
plan_deviations: "{n — reviewer judgment}"
security_regressions: "{n — reviewer judgment}"
invariant_violations: "{n — living-intent sensor: in-change + pre-existing + unlocalized; empty if the group has no 000-blueprint}"
alignment: "{aligned | minor-drift | major-drift}"
date: "{YYYY-MM-DD}"
---

<!-- Budget: findings are specific and actionable. Record references, counts, and
     locations — never raw secrets or sensitive diff content (scrub before write). -->

# Review: {Title}

## Summary

**Alignment:** {aligned | minor-drift | major-drift} · **Depth:** {lean | thorough} · **Findings:** {N} · **Plan deviations:** {N} · **Security regressions:** {N}

{1–2 sentences: what was reviewed, the build range, and the headline verdict.
Note any instrumentation gaps — e.g. "no ledger; metrics unavailable, alignment
assessed over the working tree."}

## Alignment

<!-- Where the implementation diverges from each ground truth. "Met" rows are fine
     to summarize collectively; spell out every divergence. -->

### vs. Spec acceptance criteria
<!-- Verdict per AC; the evidence behind it is recorded under ## Investigation. -->
- {AC #N — met | drift: what diverged}

### vs. Plan tasks
- {Task N — done | not done | scope creep beyond the plan}

### vs. ARCHITECTURE.md
- {convention — respected | violated: what and where}

## Investigation

<!-- The auditable depth record: which high-stakes regions / ACs were
     deep-investigated, the evidence each surfaced, and the coverage. Record
     locations only — never raw secrets (scrub before write). -->

### High-stakes regions investigated

#### {region or AC}
- locations examined: {`path:line`, …}
- callers/consumers traced: {`path:line`, … | none — not a shared symbol}
- tests checked: {`path:line`, … | none found}
- verdict: {satisfied | partial | divergence} — {specifics}

### Coverage

- Depth: {lean | thorough}{; review_model: <tier> when non-default}.
- {Full high-stakes set investigated. | Fan-out capped at {N} — these regions
  were NOT deep-investigated: {list}. | Instrumentation gap: {what}.}

## Living intent

<!-- The blueprint sensor's dimension: the group's living invariants checked
     against the build, distinct from the spec/plan Alignment verdict above — it
     never sets that verdict (AC #3). Locations only — never raw secrets (scrub
     before write). Omit this whole section when the group has no 000-blueprint
     (the sensor did not run, and invariant_violations stays empty). A
     present-but-clean section means "checked and sound", never "not looked at". -->

**Sensed:** {N invariants} · **holds:** {n} · **violations:** {n} (in-change {n} · pre-existing {n} · unlocalized {n}) · **skipped:** {n} · **failed/unconfigured:** {n}

### Violations

<!-- Every non-holding outcome, criticality-led; the channel labels the routing:
     in-change → fed the blueprint-update fork as a grounded divergence;
     pre-existing / unlocalized → reported here and offered as issues (priority
     from criticality). Evidence inside delimited untrusted blocks, secrets
     redacted. -->
- {invariant — criticality · outcome (violated | failed | unconfigured) · channel (in-change | pre-existing | unlocalized) · `file:line` | "None — every checked invariant holds."}

### Coverage

<!-- Honest coverage: name every degradation so a clean section is trustworthy. -->
- appetite in force: {level}{; per-group / per-run override when set}.
- {Whole-group floor ran. | UNSCOPED — no territory declared; floor ran repo-wide.}
- judges: {change-selected, all within cap. | capped at {N} — un-judged remainder: {list}.}
- skipped by scope: {n — the change did not touch them} · skipped by appetite: {n}.
- {registry: {k} configured. | legacy prose-method blueprint — judge fallback. | engine failure contained: {what} — reported, review not aborted.}

## Metrics

<!-- From the trusted jimledger.sh metrics channel. Omit rows that were
     unavailable and say so in the Summary. -->

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | {n} ({t}/{f}/{x}/{r}) |
| Files changed · insertions · deletions | {n} · {+n} · {-n} |
| Stage runs (spec·research·plan·sec·build·review) | {n}·{n}·{n}·{n}·{n}·{n} |
| Stage durations (spec·research·plan·sec·build·review) | {n}s·{n}s·{n}s·{n}s·{n}s·{n}s |
| Interruptions (spec·research·plan·sec·build·review) | {n}·{n}·{n}·{n}·{n}·{n} |
| Artifacts present | {spec,research,security,plan,ledger} |

## Security regressions

<!-- First-pass scan of the changes; reference deeper /jim:sec output if run.
     Locations and types only — no raw secret values. -->

- {regression — severity, location, suggestion | "None identified."}

## Findings

<!-- Each finding is discrete and actionable. Priority is the reviewer's judgment.
     If no findings: "No findings — the build aligns with spec, plan, and architecture." -->

### 1. {Finding title}

- **Priority:** {critical | high | medium | low}
- **Description:** {What diverged or what risk was introduced — specific.}
- **Suggestion:** {Concrete follow-up action.}
- **Relates to:** {AC #N | Task N | section}

## Deviations & feedback

<!-- The feedback loop: what the deviations say about the process, not just the
     code. E.g. "security findings forced a re-plan", "build interrupted twice". -->

- {Observation about the build process worth carrying into future work.}
