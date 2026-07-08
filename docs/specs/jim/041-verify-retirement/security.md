---
spec: "docs/specs/jim/041-verify-retirement/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-08"
---

# Security Review: Retirement sweep

## Summary

**Findings:** 0 Critical · 4 Notable (all addressed) · 3 Advisory
(all addressed)

Dual-lens re-run 2026-07-08 (plan.md now present). The three spec-lens
findings (1–3) remain addressed in the spec; the four plan-lens findings
(4–7) were folded into the plan on 2026-07-08. The two plan Notables lived in
the plan's chosen mechanics: `scope-census` counting via a `git ls-files --
<untrusted-scope>` pathspec opened git pathspec-magic as a new
semantic-injection surface `safe_path_param` does not neutralize (Finding 4 —
rewritten to the `check_conformance` no-pathspec + `path_under` pattern), and
the new whole-project grain had no stated cross-group bound on judge fan-out
(Finding 5 — now DD 10, run-global cap). Two Advisories pinned the
spec-corpus intent bound and "handed vs roamed" (Finding 6) and the honest
framing of the density guard's evasion boundary (Finding 7). The sweep
introduces no new *executable* surface — hints are inert facts, the registry
is untouched, the judge keeps its capability boundary — and Finding 4's fix
keeps the one new deterministic primitive as non-executing and path-gated as
the floor. LINDDUN active on incidental credentials in scanned content (the
037 classification precedent).

## Coverage

- spec.md — reviewed 2026-07-08 (requirements-gap lens)
- plan.md — reviewed 2026-07-08 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Blueprints, faces, code, spec corpus, evidence — no individual-identifying data by design |
| Credentials | Yes | Incidental only: scanned code, face content, and spec-corpus excerpts handed to judges may contain secret-looking values; redaction discipline applies (AC #11, spec 029/030 lineage) |
| Session data | No | — |
| Internal-only | Yes | Spec-corpus content, blueprints, the contract graph, per-flag evidence, filed issue bodies |
| Public | No | Artifacts are repo-committed, not published |

## Findings

### 1. Retirement is a de-protection channel — evidence-shaping can manufacture "nothing justifies this"

- **Severity:** Notable
- **Description:** Every existing engine mode flags absent or violated
  protection; the sweep recommends *dropping* constraints. An actor who can
  influence the evidence inputs — moving or renaming code so a
  security-load-bearing invariant's scope zero-matches, thinning usage the
  judge would find — manufactures a "no source justifies it" flag for
  exactly the invariant they want gone. Judge confirmation does not defeat
  this: the judge reads the same shaped inputs. Step-4a grading at the
  blueprint surface still prompts on critical/high removal, but that prompt
  now arrives pre-justified by an authoritative-looking engine flag. The
  same signature (many simultaneous zero-matches) also arises innocently
  from a moved territory — indistinguishable at hint level, and a flood of
  judge spend either way.
- **Suggestion:** Two spec-level controls. (a) **Anomaly-density guard:**
  when an anomalous share of a group's checks zero-match at once, the sweep
  reports "territory may have moved / evidence may be shaped" instead of N
  individual flags — the mass event is itself the finding. (b)
  **Criticality-asymmetric framing:** a flag on a `critical`/`high` entry is
  always presented (and filed) with the verify-then-trim framing and the
  searched-and-not-found provenance per source, so a human can spot shaped
  evidence before trusting the flag.
- **Route:** Spec
- **Relates to:** AC #3, AC #4, AC #7; User Story #6
- **Status:** Addressed — anomaly-density guard folded into AC #4;
  verify-then-trim framing + searched-and-not-found provenance folded into
  AC #7 (2026-07-08).

### 2. The retirement confirmation is the engine's highest-value injection target — shape-validate it

- **Severity:** Notable
- **Description:** The judge's polarity inverts here: in verify modes, an
  injection steering a verdict toward "holds" *hides* a violation; in the
  sweep, steering toward "confirmed stale" *initiates constraint removal*.
  Directive text embedded in scanned code, blueprint prose, or spec-corpus
  excerpts (all of which the retirement judge is deliberately handed) has
  more to gain than anywhere else in the engine. AC #11's
  never-binds discipline states the rule but gives the orchestrator nothing
  to *check* — a bare "confirmed" verdict is accepted on faith.
- **Suggestion:** Make confirmations structurally costly: a retirement
  confirmation counts only when it carries per-source examination evidence
  (what was checked for intent, usage, and verification, by location); a
  confirmation missing per-source evidence degrades to `inconclusive` —
  fail-toward-inconclusive as the shape-validation analog of the
  established fail-closed rule, applied in the direction that preserves
  constraints.
- **Route:** Spec
- **Relates to:** AC #4, AC #5, AC #11
- **Status:** Addressed — per-source examination evidence required for a
  confirmation to count, evidence-free confirmations degrade to
  `inconclusive`; folded into AC #5 (2026-07-08).

### 3. Intent-source excerpts in persisted artifacts

- **Severity:** Advisory
- **Description:** The intent source hands spec-corpus excerpts to judges,
  and the disagreement diagnostic (AC #3) narrates "what each source
  showed" — a standing temptation to quote spec prose into filed issue
  bodies, which are committed and long-lived. AC #11's location-only rule
  covers evidence generally but does not name the spec corpus, the one
  input the sweep newly reads.
- **Suggestion:** Extend AC #11 (or #3) explicitly: persisted artifacts
  (issue bodies, report lines) cite intent-source evidence by location
  (spec id / section), never by quotation; quoted excerpts appear only
  in-conversation inside delimited untrusted blocks.
- **Route:** Spec
- **Relates to:** AC #3, AC #11
- **Status:** Addressed — persisted artifacts cite all evidence, including
  spec-corpus evidence, by location only; folded into AC #11 (2026-07-08).

### 4. `scope-census` counts via a git pathspec — untrusted scope reaches git-pathspec magic

- **Severity:** Notable
- **Description:** The plan's Interface Contract counts a scope's tracked
  files with `git ls-files -- <scope>`, where `<scope>` is a blueprint
  `verify-checks scope=` value (untrusted). `safe_path_param` gates it as a
  *filesystem relpath* (no leading dash, no `..`, not absolute) — which is
  sufficient for `grep`/`find` (the existing floor's use), but **not** for a
  git pathspec: git assigns magic meaning to a leading colon (`:(exclude)…`,
  `:/`, `:(glob)`) and those forms can pass a relpath shape check. A crafted
  scope like `:(exclude)*` or `:/` skews the tracked-file count — fabricating
  emptiness to manufacture a stale-invariant hint, or inflating it to *hide*
  a genuinely stale one. This is the first time an untrusted value is handed
  to git as a pathspec; the existing floor only ever greps filesystem paths
  (`check_pattern`) or runs `git ls-files` with **no** pathspec
  (`check_conformance`).
- **Suggestion:** Do not pass the untrusted scope to git as a pathspec.
  Count with the `check_conformance` pattern already in the script: enumerate
  `git ls-files` once (no pathspec), then filter by `path_under "$f"
  "$scope"` in bash — pure string logic over already-shape-gated relpaths, no
  git magic. Amend the scope-census Interface Contract in the plan
  accordingly.
- **Route:** Plan
- **Relates to:** Interface Contracts (`scope-census`); Task 1; spec AC #10/#11
- **Status:** Addressed — the `scope-census` Interface Contract and Task 1 now
  count via the `check_conformance` pattern (no-pathspec `git ls-files` +
  `path_under` bash filter); Task 2 gains a pathspec-magic case (2026-07-08).

### 5. Whole-project grain has no stated cross-group fan-out bound

- **Severity:** Notable
- **Description:** The whole-project grain iterates every blueprint-bearing
  group, turning each group's zero-scope, prose, and unreferenced-edge
  entries into judge candidates. The plan says judges are "appetite-gated +
  fan-out cap (reused knobs)", but `verify_fanout_cap` is documented as a
  per-run bound and the contract mode's precedent is a *single* graph, not N
  per-group iterations. If the whole-project sweep applies the cap per group,
  an M-group repo fans out up to M × cap judges — a cost/latency blowup on
  the developer's own run (a self-inflicted DoS), and the exact cost the
  cost-conscious User Story 2 warns against.
- **Suggestion:** State in the plan/methodology that `verify_fanout_cap`
  bounds the **whole run's total** judge fan-out across all groups
  (highest-criticality-first, cross-group), with the un-judged remainder
  named as in Step 7 — never a per-group cap. This mirrors the contract
  mode's run-global fan-out.
- **Route:** Plan
- **Relates to:** DD 2, DD 9; the Data Flow "appetite gate"; spec AC #5
- **Status:** Addressed — DD 10 added (run-global cross-group fan-out cap,
  highest-criticality-first, remainder named); Task 5 states it (2026-07-08).

### 6. Bound the spec-corpus intent grep; reconcile "handed vs roamed"

- **Severity:** Advisory
- **Description:** The plan hands the judge the group's spec-corpus **file
  paths** and has the judge grep them for intent. Spec AC #5 / Insight 2 lean
  toward "sources handed, not roamed for" — the plan's bounded-path-list is a
  defensible middle path, but two edges are unbudgeted: a large corpus
  balloons judge input (cost) and widens the untrusted-content the judge
  ingests (first-party, but still injectable prose).
- **Suggestion:** Cap the handed corpus (file count and/or per-file matched
  excerpt size around the invariant's subject terms) and state explicitly in
  the methodology that the judge greps **only** the handed path set (bounded,
  not repo-roaming) — closing the AC #5 "handed, not roamed" intent.
- **Route:** Plan
- **Relates to:** DD 6; Interface Contracts (judge retirement claim); spec AC #5
- **Status:** Addressed — the judge Interface Contract and DD 6 now hand a
  bounded corpus (file/excerpt cap) the judge greps only within, not a
  repo-roam (2026-07-08).

### 7. Don't oversell the density guard — the per-candidate defense is the independent intent source

- **Severity:** Advisory
- **Description:** The mass-anomaly guard (DD 8) fires only above a threshold
  (≥3 and ≥50% zero-scope). A targeted evasion — shaping *one* invariant's
  scope, well under the threshold — still produces an individual flag. The
  real protection for that case is not the density guard but the **union
  model**: the judge checks intent (the spec corpus) independently of the
  code scope, so a security invariant with genuine spec-declared intent
  survives a shaped code-scope (the judge finds the intent and returns
  `justified`). Left unstated, the methodology could read as if the density
  guard is the primary defense against shaping.
- **Suggestion:** In the methodology doc, name the density guard as the
  *mass-event* defense and the independent intent-source confirmation
  (AC #5) as the *targeted-shaping* defense — so the two Finding-1 controls
  are not conflated and neither is oversold.
- **Route:** Plan
- **Relates to:** DD 8; spec AC #4/#5; Finding 1
- **Status:** Addressed — Task 5 now directs the methodology to name the
  density guard (mass events) and the independent intent-source confirmation
  (targeted shaping) as distinct defenses (2026-07-08).

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | No | No issues found — on-demand only, no caller hand-over in scope; VERIFY-OUTCOME-shaped text inside untrusted delimiters stays data (036 Finding 9 lineage) |
| Tampering | Yes | Finding 1 (evidence-shaping of scanned inputs); Finding 4 (git-pathspec magic skewing the scope-census count); a forged judge verdict can at most produce a *declinable issue offer* — the no-write property (AC #8) bounds the blast radius |
| Repudiation | N/A | Counters-only durability plus filed issues is the deliberate trail (no-standing-verdict doctrine); declining an offer leaving no state is by design (AC #7) |
| Information Disclosure | Yes | Finding 3 (spec-corpus excerpts in persisted bodies); Finding 6 (unbounded corpus handed to the judge); secret redaction inherited via AC #11 |
| Denial of Service | Yes | Finding 5 (whole-project fan-out with no stated cross-group cap → self-inflicted blowup); Finding 1 (mass zero-match → hint flood, bounded by the density guard) |
| Elevation of Privilege | No | No issues found — no new executable surface: hints are inert facts, registry untouched, judge remains Read/Glob/Grep-only. Finding 4 is a git *pathspec-magic* (count-skew) surface, not code execution — the fix keeps scope-census non-executing |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | N/A | No individual data subjects — artifacts describe code and constraints |
| Identifying | N/A | Same — no personal data processed by design |
| Non-repudiation | N/A | No data subjects with deniability interests |
| Detecting | N/A | No subject-presence inference surface |
| Data Disclosure | Yes | Finding 3; incidental secret-looking values in scanned content — redaction discipline (AC #11) |
| Unawareness & Unintervenability | N/A | Developer-invoked, developer-confirmed; no third-party subjects |
| Non-compliance | N/A | No privacy policy or regulation in scope for repo-internal artifacts |

## Artifact Misalignment

- **Finding 4 — scope-census pathspec:** the plan's Interface Contract
  (`git ls-files -- <scope>`) does not carry the spec's untrusted-input
  discipline (AC #10/#11) to git's pathspec-magic layer; the floor's own
  `check_conformance` already models the safe pattern (no-pathspec enumerate
  + bash filter). Route: Plan.
- **Finding 6 — handed vs roamed:** spec AC #5 / Insight 2 say intent sources
  are "handed, not roamed for"; the plan hands file *paths* the judge greps.
  Defensible, but the plan should make the bound explicit to close the intent.
  Route: Plan.

## Routing Recommendations

### Spec amendments

All applied 2026-07-08:

- Finding 1: anomaly-density guard → AC #4; criticality-asymmetric
  verify-then-trim framing + provenance → AC #7.
- Finding 2: per-source examination evidence required, evidence-free
  confirmations degrade to `inconclusive` → AC #5.
- Finding 3: spec corpus named in the location-only evidence rule → AC #11.

### Plan amendments

All applied 2026-07-08:

- Finding 4 (Notable): `scope-census` Interface Contract + Task 1 rewritten to
  count via `check_conformance`'s no-pathspec enumerate + `path_under` bash
  filter, not `git ls-files -- <scope>`; Task 2 gains a pathspec-magic case.
- Finding 5 (Notable): DD 10 added — `verify_fanout_cap` bounds the whole
  run's total cross-group judge fan-out (highest-criticality-first, remainder
  named); Task 5 states it.
- Finding 6 (Advisory): judge Interface Contract + DD 6 hand a bounded
  spec-corpus (file/excerpt cap) the judge greps only within.
- Finding 7 (Advisory): Task 5 directs the methodology to distinguish the
  density guard (mass events) from the independent intent-source confirmation
  (targeted shaping).
