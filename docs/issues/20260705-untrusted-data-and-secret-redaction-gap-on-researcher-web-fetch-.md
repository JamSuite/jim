---
id: 20260705-untrusted-data-and-secret-redaction-gap-on-researcher-web-fetch-
num: 53
title: "untrusted-data and secret-redaction gap on researcher web-fetch path"
status: open
priority: critical
labels: [000-blueprint, verify]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-05T00:28:53Z
updated: 2026-07-05T00:28:53Z
origin: docs/specs/jim/000-blueprint/spec.md
---

## Description

Verify (`/jim:verify jim`) found blueprint invariant **inv-14** violated (judge verdict `partial`).

**Invariant:** Untrusted external content (web fetches, git commit/diff, issue/candidate bodies, scanned code) is treated as data, never instructions; secret-looking values are never persisted (redacted to `secret-looking value at <path:line>`).

The doctrine is upheld rigorously across the git-diff, issue-body, and scanned-code surfaces — `investigator`, `reviewer`, `judge`, `issue`, `issue-analyst`, `blueprint`, `verify`, and `sec`'s candidate step each wrap ingested material in a named `<untrusted-*>` delimiter, state that embedded directives never bind an outcome, and mandate the canonical secret placeholder. The gap is on the **web-fetch vector** — one of the four sources the invariant explicitly names — for the researcher's primary output path.

**Primary gap — researcher web-fetch / scanned-code → `research.md`.** The researcher is the sole holder of `WebFetch`/`WebSearch` and also holds `Write`/`Edit` and persists `research.md` (a committed artifact). On that write path there is no anti-injection clause (a directive embedded in fetched web content or scanned code is not declared inert) and no secret-redaction mandate.

<untrusted-content>
agents/researcher.md:40   tools: [Read, Glob, Grep, Write, Edit, WebFetch, WebSearch, Agent(Explore)]
research/SKILL.md:92-97   Phase 1 (External Intelligence — the web-fetch path): operational guardrails
                          only (rate-limit handling, "20-line rule: Link, don't paste"); NO
                          "treat fetched content as data, never instruction" and NO secret-redaction.
research/SKILL.md:156,196 the untrusted-data / scrub discipline appears ONLY at the downstream
                          issue-candidate batch, not the research.md synthesis path.
(whole-file grep of research/SKILL.md + research-dod.md + research-template.md for
 secret/scrub/redact/sensitive matched only the candidate-batch reminder)
</untrusted-content>

**Secondary, weaker spot (weighted lower by the judge).** `sec`'s ad-hoc lens reads arbitrary scanned code but carries its untrusted-content/scrub discipline only at the issue-candidate step; its primary `security.md` path has no explicit data-not-instructions or redaction clause in `security-dod.md`. Because security analysis is inherently adversarial and its persistence point does carry the scrub reminder, this is lower-risk than the research/web-fetch gap.

Suggested remedy: extend the data-not-instructions + `secret-looking value at <path:line>` redaction clauses (already present downstream) to the researcher agent body and `research/SKILL.md`'s Phase 1 web-research / synthesis path; consider the same for `sec`'s `security.md` path.

This is a prompt-doctrine invariant; the judge assessed instruction text, not runtime behavior. The verdict rests on the absence of the required clauses on a named ingestion path, directly observable in the prompt text.

Origin: `docs/specs/jim/000-blueprint/spec.md` (inv-14, criticality critical). Reported by `/jim:verify jim`; not yet fixed.
