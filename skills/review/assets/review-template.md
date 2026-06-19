---
spec: "{relative/path/to/spec.md}"
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
build_runs: "{n}"
build_interruptions: "{n}"
duration_seconds: "{n, or empty}"
phase_coverage: "{comma-separated artifacts present, e.g. spec,research,security,plan,ledger}"
plan_deviations: "{n — reviewer judgment}"
security_regressions: "{n — reviewer judgment}"
alignment: "{aligned | minor-drift | major-drift}"
date: "{YYYY-MM-DD}"
---

<!-- Budget: findings are specific and actionable. Record references, counts, and
     locations — never raw secrets or sensitive diff content (scrub before write). -->

# Review: {Title}

## Summary

**Alignment:** {aligned | minor-drift | major-drift} · **Findings:** {N} · **Plan deviations:** {N} · **Security regressions:** {N}

{1–2 sentences: what was reviewed, the build range, and the headline verdict.
Note any instrumentation gaps — e.g. "no ledger; metrics unavailable, alignment
assessed over the working tree."}

## Alignment

<!-- Where the implementation diverges from each ground truth. "Met" rows are fine
     to summarize collectively; spell out every divergence. -->

### vs. Spec acceptance criteria
- {AC #N — met | drift: what diverged}

### vs. Plan tasks
- {Task N — done | not done | scope creep beyond the plan}

### vs. ARCHITECTURE.md
- {convention — respected | violated: what and where}

## Metrics

<!-- From the trusted jimledger.sh metrics channel. Omit rows that were
     unavailable and say so in the Summary. -->

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | {n} ({t}/{f}/{x}/{r}) |
| Files changed · insertions · deletions | {n} · {+n} · {-n} |
| Build runs · interruptions | {n} · {n} |
| Duration | {n}s |
| Phase coverage | {spec,research,security,plan,ledger} |

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
