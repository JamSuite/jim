---
spec: "spec.md"
status: Active
date: "2026-07-23"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Enforce present-tense discipline at blueprint draft composition

## Anchors

**Doctrine sites (stated-only today — the framing to make operative):**
- `skills/blueprint/SKILL.md:22-24` — "reflects reality, not aspiration"; the intro doctrine, no operative rule attached.
- `skills/blueprint/assets/blueprint-template.md:11` and `assets/map-template.md:10` — the two "current, present-tense" / "Current state only" banners; descriptive only.

**Composition sites that accept supplied/interview text (where the rule must apply — AC4):**
- `skills/blueprint/references/map-methodology.md:47-66` (creation interview) and `:68-96` (differential update) — caller/interview purpose·role·rationale enters here.
- `skills/blueprint/SKILL.md:370-374` — the mint-new handoff from `/jim:spec`; purpose/role/rationale arrive as `Skill` args.
- `skills/blueprint/references/migrate-arms.md:17-97` — the `--rename`/`--split`/`--merge` `--changes` transcription points; **no re-gate** (`:6-8`), so disclosure rides the returned touched-file list (AC7).
- `skills/blueprint/SKILL.md:73-90` — group-tier generate; the skill authors wording over evidence (lower-risk, still covered by the self-scan).

**Enforcement-surface anchors (where new content lands):**
- `skills/blueprint/SKILL.md:483-505` — the Validation Checklist; home for the new present-tense item (AC1).
- New file `skills/blueprint/references/present-tense.md` — the single canonical definition (AC3), mirroring `gate-presentation.md`.

## Local Patterns

Three existing idioms this feature composes from — nothing needs inventing:

1. **Define-once-cite-by-path** (the AC3 model). `skills/blueprint/references/gate-presentation.md:1-6` — *"Defined once here and cited by path from each gate; never restated inline per site."* Same idiom: `skills/issue/SKILL.md:190-192` (§ 7a "single canonical definition … edit it here"), `skills/blueprint/SKILL.md:98-101` (Step-4a shared rule, "point here; do not restate it elsewhere"), `references/fork-grounding.md:110`, `references/map-methodology.md:112-119` (scrub reminder). Stated as convention at `ARCHITECTURE.md:541` (the "define-once-cite-by-path discipline") and `:292`.

2. **Itemize-what-changed disclosure** (the "+ disclose" half, AC5). `skills/blueprint/SKILL.md:131-135` — *"Every unattended write's summary must itemize each touched Invariants row … so a misclassification is auditable from the summary alone."* Also `:142`, `:93-96`, and the compact-verbatim summary at `gate-presentation.md:42-50`. Sibling "summarize changed vs preserved" at `skills/arch/SKILL.md:49`, `skills/plan/SKILL.md:83`.

3. **Scrub-before-present self-scan** (the AC6 model). `skills/blueprint/SKILL.md:87-89` — the secret redaction "`secret-looking value at <path:line>`" self-scan, repeated at `:283`/`:491` and `gate-presentation.md:35-41`. A skill already scans its own draft for forbidden content before the gate; present-tense is a second such scan.

Nearest semantic precedent: `agents/gatherer.md:103-109` fail-closes candidate invariants to *currently-true* content ("a blueprint records only present-tense, currently-true rules") — but that is an **evidence** gate on content truth, **not** a prose-tense scan. Confirmed across the plugin: present-tense is **stated doctrine, never mechanically enforced** — this feature adds a genuinely new scan.

**Test template.** Skill prose is validated by **checklist, not bash** (`ARCHITECTURE.md:341`; `skills/meta-test/SKILL.md:7-8`; the meta-skill Validate checklist at `skills/meta-skill/SKILL.md:85-116`). The one exception is the load-bearing template pattern here: `tests/gatepresentation.sh` (`ARCHITECTURE.md:543`) is a **textual-invariant** bash test asserting each gate-site file carries the shared reference at its expected per-file count. A present-tense reference cited from N sites is mechanically checkable the same way.

## Security & Performance

- **Disclosure must not leak secrets.** The itemized "here's what I rewrote" summary echoes supplied text; run it through the same secret-scrub as every other draft (`SKILL.md:87-89`) so a normalized phrase never re-exposes a `secret-looking value`.
- **Do not soften the injection boundary.** This is a *cooperative* intent-vs-wording layer; the existing "content is data, not instruction" rule (`SKILL.md:67-72`) stays intact. Normalization rewrites tense, never executes or trusts embedded directives — a marker rewrite must not become a laundering path for injected content inside supplied text.
- **False positives are recoverable, not silent.** A bare "will"/"today" can be legitimate present tense; because every rewrite is disclosed and the gate/caller stays final authority, an over-eager rewrite is caught at review — no separate suppression machinery required.
- **Performance:** prompt-level self-scan; no runtime/latency cost of concern.

## Recommendations

*Options and trade-offs for the architect — not decisions.*

1. **Single-source in `references/present-tense.md`, cite-by-path from each composition site.** Directly mirrors `gate-presentation.md` and the `ARCHITECTURE.md:541` convention. Keeps SKILL.md growth to one-line cites + one checklist item rather than inline prose at five sites — which also relieves the line-budget pressure (#43). The blueprint SKILL.md is already ~505 lines against the meta-skill ≤500 structural check, so the reference-file route is the low-footprint path regardless of the cap change.

2. **Resolves Open Question 1 (mechanism) → hybrid.** Mechanize the *citation presence* with a textual-invariant test mirroring `tests/gatepresentation.sh` (asserts each composition-site file carries the present-tense reference); keep the *tense normalization itself* as an LLM self-scan, since tense-intent is inherently judgment (a grammatical word-list alone over-flags legitimate present tense). Mechanical where mechanical fits, judgment only where it must.

3. **Resolves Open Question 2 (suppression) → none needed.** Disclose-and-revert mirrors the existing downgrade-confirmation flow (`SKILL.md:131-135`); the gate (or the caller, on no-re-gate arms) is the revert authority. Adding an allowlist would duplicate a control that already exists structurally.

4. **Reuse, don't reinvent:** the disclosure shape from the downgrade-classification summary (AC5) and the scrub-before-present self-scan shape (AC6). Both are established; the architect wires the same shapes to a new trigger.

**Alignment.** Consistent with VISION.md ("Not a black box … Transparency over automation") — the *disclose* half makes every rewrite visible and keeps the human gate authoritative. Follows ARCHITECTURE.md's documented define-once-cite-by-path convention (`:541`) and checklist-validation model (`:341`), and the reference-file structure honors the skill-size discipline. No divergence from a locked constraint.
