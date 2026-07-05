---
spec: "docs/specs/jim/037-verify-contracts/spec.md"
reviewed_phases: [spec]
status: Needs Plan Review
date: "2026-07-05"
---

# Security Review: Contract-graph verification

## Summary

**Findings:** 0 Critical · 2 Notable (1 addressed) · 2 Advisory

Spec-phase run (no plan.md yet — requirements-gap lens only). Finding 1 was
folded into spec AC #8 (the one-way ratchet) on 2026-07-05; Findings 2–4
route to Plan and carry forward to `/jim:plan`. The spec
inherits the 035/036 security posture soundly (registry boundary untouched,
read-only engine, VERIFY-OUTCOME provenance, fail-closed precedence,
redaction). The two Notables are new surfaces this spec opens: a two-step
laundering path through the declared-criticality channel (Finding 1), and
consumer-authored check data driving scans and evidence-quoting over
*provider* territory (Finding 2). LINDDUN active on incidental credentials;
all rows N/A / no issues, matching the 036 baseline.

## Coverage

- spec.md — reviewed 2026-07-05 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Faces, territories, code, and evidence — no individual-identifying data by design |
| Credentials | Yes | Incidental only: scanned code on both sides of an edge, face content, and evidence excerpts may contain secret-looking values; redaction discipline applies (AC #17, spec 029/030 lineage) |
| Session data | No | — |
| Internal-only | Yes | Provides/requires faces, territory declarations, the contract graph, per-edge evidence, review.md content, issue bodies |
| Public | No | Artifacts are repo-committed, not published |

## Findings

### 1. A criticality declaration is itself gradable content — declaring or lowering must grade as a downgrade

- **Severity:** Notable
- **Description:** AC #8 lets a provides entry declare a non-default
  criticality that drives both edge appetite and Step-4a autonomy grading.
  The declaration lives in face check-data written through the blueprint
  surface — and under `auto_blueprint`, *additive* changes write unattended.
  A criticality declaration that lowers an entry from the `high` default to
  `medium`/`low` is textually additive (new annotation, guarantee text
  untouched), opening a two-step laundering of exactly what spec 031
  always-prompts on: step 1, an unattended "additive" write annotates the
  entry `criticality=low`; step 2, a later unattended write removes the
  entry — now graded `low`, it auto-writes. The 031/036 laundering-path
  closures (grading, fail-closed precedence) do not cover this channel,
  because the attack rides the *classification input*, not the classifier.
- **Suggestion:** Amend AC #8: **declaring, or lowering, a provides-entry
  criticality below the default grades as a weakening** (always prompts
  under `auto_blueprint`, blast radius attached); raising or removing a
  declaration back toward the default is additive. The one-way ratchet makes
  the relaxation deliberate at the moment it is *introduced*, not merely
  exploited.
- **Route:** Spec
- **Relates to:** AC #8, AC #9; spec 031 Step-4a grading
- **Status:** Addressed — folded into spec AC #8 (one-way ratchet:
  introduce/lower grades as weakening; raise/remove is additive),
  2026-07-05.

### 2. Consumer-authored check data scans provider territory — gate the params, minimize the evidence

- **Severity:** Notable
- **Description:** AC #6's face check-data means one group's blueprint
  (e.g. a consumer's ref pattern) drives deterministic scans — and
  evidence-quoting — over *another* group's territory. Two exposures: (a)
  the params are the 035 Finding-6 class (EREs/paths handed to grep) arriving
  from a **new authoring surface**, including blueprints regenerated
  unattended; (b) a crafted pattern (e.g. `(api_key|secret).{0,40}`) turns
  the floor into a secret harvester whose matches are quoted as evidence
  into reports, review.md, and issue bodies — redaction (AC #17) is then the
  only guard. In multi-group projects the per-group blueprint author may not
  be the provider-code owner, so this is a real cross-authorship seam even
  inside jim's trusted-developer model.
- **Suggestion:** At plan time: every face-declared check param passes the
  same at-use validation as `verify-checks` params (`valid-relpath` /
  leading-dash reject / `-e` `--` guards; failing param → that check
  `failed`, never executed); floor **fact records stay location-only**
  (`file:line`, the VERIFY-OUTCOME evidence discipline) so a pattern cannot
  exfiltrate matched content through the record channel; excerpts appear
  only in delimited untrusted blocks post-redaction. Add negative fixtures
  (absolute path, `..`, leading-dash, tab-bearing pattern) to the new verb's
  tests.
- **Route:** Plan
- **Relates to:** AC #5, AC #6, AC #17; research Recommendation 1/3

### 3. Boundary-change trigger integrity: absent/stale graph and unattended attributability

- **Severity:** Advisory
- **Description:** AC #9's trigger reads the persisted pre-write graph. When
  no graph section exists, or it is stale, the affected-edge set resolves
  empty and the trigger silently fails open — a Provides downgrade proceeds
  with no engine enrichment (consistent with the declared-data principle,
  but it must be *visible*). Separately, the unattended path's findings —
  floor and judge alike, per the revised AC #9 (full grounding under
  config-controlled spend) — land in a conversational summary; a violation
  nobody saw should remain attributable after the fact (the 031
  guard-outcome lineage). The revision raises this finding's weight: the
  durable record now carries judge outcomes too.
- **Suggestion:** At plan time: the enrichment names its graph basis
  explicitly — `blast radius: … — graph as of <Last reconciled>`, `none
  recorded`, or `no graph section` (the 034 freshness-stamp convention) —
  and never fabricates an edge set; trigger-run outcome counts (including
  the unattended floor's) ride the write's existing `blueprint finished`
  counters or a sibling verify event, so a declined/unattended outcome stays
  attributable.
- **Route:** Plan
- **Relates to:** AC #9, AC #13, AC #15

### 4. Sensor cross-group floor must stay scoped to affected edges

- **Severity:** Advisory
- **Description:** The 036 registry-amplification concern (Finding 3 there)
  recurs one level up: the review-sensor extension (AC #10) adds cross-group
  scanning to every review of a provider group. AC #10's "affected edges"
  language implies the scan is edge-scoped, but nothing pins the floor's
  scope — a whole-graph cross-reference scan per review would tax every
  review with cost the graph was supposed to *target*.
- **Suggestion:** At plan time, scope the sensor's cross-ref floor (and
  judge selection) to the affected edges' consumer territories only —
  whole-graph scanning stays the on-demand run's job (AC #4's grain split,
  applied to the floor).
- **Route:** Plan
- **Relates to:** AC #10; spec 036 security Finding 3

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | No | No issues found — edge records ride the VERIFY-OUTCOME provenance discipline (AC #12, Finding-9 lineage); channel/side classification anchors to trusted inputs (AC #11) |
| Tampering | Yes | Finding 1 (criticality-declaration laundering); Finding 3 (absent/stale graph silently emptying the trigger's edge set) |
| Repudiation | Yes | Finding 3 (unattended trigger outcomes must stay attributable; AC #15's baseline is sound) |
| Information Disclosure | Yes | Finding 2 (pattern-driven evidence harvesting across the group-authorship seam; location-only records + redaction are the guards) |
| Denial of Service | Yes | Finding 4 (per-review cross-group scan amplification); whole-graph judge spend is capped and named (AC #7) |
| Elevation of Privilege | Yes | Finding 1 (unattended-write privilege expanded via the declaration channel); no new executable surface — the floor is grep-only, the 035 registry boundary is unchanged |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | N/A | No data subjects — content is project code and dev artifacts |
| Identifying | N/A | No anonymous-subject data to re-identify |
| Non-repudiation | N/A | No data subjects; attributability is a deliberate audit property |
| Detecting | N/A | No subject-presence inference surface |
| Data Disclosure | No | No issues found beyond Finding 2's guard (incidental secrets in cross-group evidence; AC #17 redaction + location-only records) |
| Unawareness & Unintervenability | N/A | Developer-invoked tooling; unattended paths run under user-owned appetite/fan-out config with summary + durable record (AC #9) |
| Non-compliance | N/A | No personal data; no applicable privacy regime for internal dev tooling |

## Routing Recommendations

### Spec amendments
- ~~Finding 1~~ — applied 2026-07-05 (AC #8: the one-way criticality-
  declaration ratchet).

### Plan amendments
- Finding 2: face-declared check params through the at-use validation gate;
  location-only floor records; delimited redacted excerpts; negative fixtures.
- Finding 3: enrichment names its graph basis (freshness stamp / none
  recorded); trigger-run counters ride the durable record.
- Finding 4: sensor's cross-group floor and judges scoped to affected edges'
  territories; whole-graph stays on-demand.

No findings route to Issue — no candidates this run.
