---
spec: "docs/specs/jim/041-verify-retirement/spec.md"
status: Active
date: "2026-07-08"
---

# Research: Retirement sweep

## Anchors

**Engine script — `skills/verify/scripts/jimverify.sh`**

- Verb dispatch `main()` L981–993 (`parse`/`territory`/`check`/`faces`/`edges`/`contracts-check`/`health`) — the sweep's deterministic hints compose over these.
- `emit_outcome` L306–313 — the single sanitized emission primitive (tab-stripped, 1024-cap) every new fact type must ride.
- `check_pattern` L389–409, `check_structure` L436–443 — **the zombie gap lives here**: a `must-not` whose scope resolves to zero files emits the same `holds` (`no forbidden matches`, L406) as a genuinely-checked clean scope; no file-count field exists in the record grammar. Scoped mode is the one exception: a check intersecting zero listed files emits *nothing* (L386–387, L427–429).
- `cmd_contracts_check` L747–838 — `CROSS-REF` facts fire **only on positive matches** (L801–806); `consumer-ref` absent → abstain, no record (L732–736, L834); `COVERAGE` L783. The sweep's face hints are set logic over this existing output.
- `cmd_faces` L550–622 — 6-field record, criticality in field 4 (provides only). `cmd_edges` L635–658 — 3-field record, no criticality (joined per-edge at L819–834).

**Skill — `skills/verify/SKILL.md`** (297/500 lines)

- VERIFY-OUTCOME grammar L90–111: invariant keys L96, edge keys L107–108 — a retirement record type would be a third additive shape (the 037 precedent).
- Appetite/fan-out/model resolution L137–150; `--appetite` strip L29.
- Issue offer Step 9c L254–263 (`new.sh` + `index.sh`, body via temp file) — reuse verbatim.
- Consume-vs-fresh-run doctrine: `--entries` returns records, caller owns durability (L33, L121–129); grounding only from handed-over blocks (L102, L230).

**Judge — `agents/judge.md`** — claim types L45–54 (invariant; one edge side), tools `Read, Glob, Grep` L15, verdict vocabulary `holds|partial|violated` L77–89. A retirement candidate is a third claim type; the claim section and verdict mapping need extension.

**Dead surface — `skills/verify/references/contracts-methodology.md`** L92–104 — whole-graph-only set logic (no declared edge ∧ no `CROSS-REF`), judge-confirmed candidates, verify-then-trim remedy; report L155–173, counters L183–188.

**Ledger — `skills/review/scripts/jimledger.sh`** — `event <dir> <phase> <event> [k=v…]` L231–244 (free k=v tokens: `tier=project op=…` + counters need **no script change**); `commit-verify <dir>` L223–229 takes any dir, including the specs-root (037 precedent).

**Blueprint data — `skills/blueprint/references/check-authoring.md`** — Invariants table L10–16; `verify-checks` params (`polarity`/`regex`/`scope`/`count`, `exists`/`absent`) L59–79; `contract-checks` (`criticality`/`provider-ref`/`consumer-ref`/`scope`) L123–147, ratchet L161–182.

**Spec corpus (intent source)** — no existing verify-side reader. The pattern is `skills/blueprint/SKILL.md` L59 (glob group spec dirs, read `spec.md`); `jimfile.sh` `cmd_glob` L700–753 emits spec *directories* (caller composes `/spec.md`).

**New files expected** — `skills/verify/references/retirement-methodology.md` (budget headroom argues for a reference doc); new `case_jimverify_*` tests in `tests/jimverify.sh`.

## Local Patterns

- **Facts-not-verdicts (Bash-vs-Prompt):** the script emits facts; classification is skill judgment (dead-surface precedent: set logic in the skill, not the script). Hints should follow — deterministic facts in, candidate selection in the skill, confirmation in the judge.
- **Test template:** `tests/jimverify.sh` — zero-arg `case_jimverify_*` functions auto-discovered by `run_discovered_cases` (L1215); synthetic multi-group fixture builder `contracts_repo` L746–793 (two groups, faces, graph edge, code both sides); scoped-repo builder `verify_repo_scoped` L245–282; assertors `tsv_field`/`faces_field`. Framework: `skills/meta-test/scripts/testlib.sh` (`fixture` L159, `TMP_BASE` mktemp L78); bash+POSIX, `set -uo pipefail`, no third-party deps.
- **Issue offer / ledger / commit:** reuse Step 9c, `event` k=v counters, `commit-verify <specs-root>` — all zero-script-change.

## Security & Performance

- **Hint false positives are the design risk:** a moved territory or renamed path makes *every* scope zero-match at once — a mass-hint event. The spec's burden inversion (AC #4: hints never flag alone; judge confirms; unconfirmable → inconclusive) is the guardrail; the plan should also consider a sweep-level sanity note when hint density is anomalous (e.g. >half a group's checks zero-match → report "territory may have moved", not N flags).
- **Cost:** the whole-project grain implies a whole-graph `contracts-check` (consumer×provider greps) plus per-candidate judges. Existing appetite + `verify_fanout_cap` gate the judges; the floor cost matches an existing whole-graph contract run — no new cost class.
- **Untrusted content:** face params/EREs and invariant text stay untrusted (existing `--`/`-e` and delimited-block discipline); evidence remains location-only; the judge's third claim type inherits the injection-resistant capability boundary (`Read`/`Glob`/`Grep` only). No new trust surface is created if hints stay inside `jimverify.sh`'s existing execution gates (`safe_path_param`).

## Recommendations

1. **Zombie-invariant hints need one new deterministic fact.** The record grammar cannot express "scope resolved to zero files" (Anchors: `check_pattern`). Options: (a) an additive scope-resolution fact emitted by `check` (e.g. a `SCOPE`-class record carrying the file count) — keeps the one execution gate, additive like 037's edge records; (b) a small new verb the sweep calls per check; (c) skill-side globbing — weakest, re-implements scope semantics outside the gate. (a) looks cleanest; architect decides.
2. **Face hints are pure composition.** Stale-requires is the complement cell of dead-surface over the *same* `contracts-check` output: declared edge ∧ no `CROSS-REF` (∧ consumer-ref abstain) → stale-requires candidate; no declared edge ∧ no `CROSS-REF` → dead surface (existing). No new primitives.
3. **The whole-project sweep should *contain* its engine pass, not consume history.** The no-standing-verdict doctrine means **no durable per-invariant/per-edge outcomes exist anywhere** — the ledger carries counters only. The "verification dependency" source therefore must come from a contained fresh run (floor always; judges per appetite), which also satisfies one-opinion-per-edge naturally. Consume-first applies only if a caller ever hands records in (not in scope: the sweep is on-demand only).
4. **Judge: extend, don't sibling.** Add the third claim type to `agents/judge.md` L45–54 with an explicit verdict mapping — note the polarity inversion (here a confirming verdict *flags* the entry; `partial`-equivalent should map to inconclusive, mirroring 035's cautious mapping).
5. **Intent packaging needs a bound.** Corpus = `jimfile.sh glob specs <group>` + per-dir `spec.md`; hand the judge titles plus grep-matched excerpts around the invariant's subject terms, not whole specs.
6. **Methodology to `references/retirement-methodology.md`** (SKILL.md at 297/500; contracts-methodology precedent).

## Peer Feedback

**For PM (wording nuance, not feasibility — resolved 2026-07-08):** AC #5 handed the judge "the engine's recorded outcomes" as the verification-dependency source, but nothing durable records per-entry outcomes (by 034/035 doctrine — counters only). AC #5 now reads "the containing run's engine outcomes"; no other spec assumption is invalidated.

## Alignment

Aligns with VISION's human-in-the-loop north star (flags inform; retirement stays a developer act through the blueprint surface) and ARCHITECTURE's established patterns: the Bash-vs-Prompt facts/judgment split, the capability-backed read-only judge, the no-standing-verdict doctrine, operator-owned execution boundaries (untouched — hints add no executable surface), and the counters-only ledger channel. No divergence found.
