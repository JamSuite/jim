---
spec: "docs/specs/blueprint/003-blueprint-update-guard/spec.md"
status: Active
date: "2026-07-02"
---

# Research: Blueprint update guard

## Anchors

- `skills/blueprint/SKILL.md:82-99` — Step 4 (differential update: "summarize
  added / changed / preserved") and Step 5 (the `auto_blueprint` write gate).
  Generate mode's grading hook: Step 4 already produces exactly the
  classification input (what changed vs preserved) that AC #4 needs; the
  grading wraps Step 5's auto branch.
- `skills/blueprint/SKILL.md:101-165` — update mode U1–U4. U3 (140-149) is
  where the violation fork inserts (it already instructs reading changed
  source when a hunk can't ground an edit — the same discipline Insight 1
  wants for grounding a violation call); U4 (151-165) is the write/commit
  path the graded gate wraps for the update side.
- `skills/blueprint/SKILL.md:14` — `allowed-tools`; gains
  `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/new.sh *)` and
  `... index.sh *)` for the fix-resolution issue offer.
- `skills/blueprint/assets/blueprint-template.md:19-25, 41-50` — the Provides
  shape (no criticality column — the spec guards these wholesale) and the
  Invariants table whose existing criticality column the classifier reads.
- `skills/review/SKILL.md:184-199` — Step 10 trigger wiring and the
  held-completion / never-a-veto semantics (197) that AC #5 must preserve;
  "run to completion" needs to be read as "fork answered, either resolution".
- `skills/conf/scripts/jimconf.sh:42, 61-62` — `auto_blueprint` /
  `require_blueprint` already exist with `false` defaults; confirms the
  no-new-config exclusion requires zero resolver changes.
- `skills/review/scripts/jimledger.sh:261` — `LEDGER_STAGES` already includes
  `blueprint`; no ledger surface changes either.
- `skills/issue/scripts/new.sh:25-36, 49-58` — the emitter CLI the issue
  offer reuses (`--title/--priority/--labels/--origin/--body-file`).
- `skills/issue/SKILL.md` step 5 + § 7a — the confirm-or-edit scrub reminder
  and temp-file body discipline (security 025 Finding 5) the offer must
  follow.
- `skills/sec/SKILL.md:169` — per-finding `Route:` choice: jim's existing
  precedent for a per-item resolution decision, the shape the per-violation
  fix/fold fork mirrors.
- `skills/spec/SKILL.md:10` — precedent `allowed-tools` shape for a skill
  that files issues (`new.sh` + `index.sh` grants).
- New files: none — the change is edits to `skills/blueprint/SKILL.md`
  (fork + grading + issue offer) and at most a one-line clarification in
  `skills/review/SKILL.md` Step 10.

## Local Patterns

- **Prompt-layer judgment, bash-layer determinism.** Violation detection and
  downgrade classification are judgment → they live in SKILL.md prose, not
  scripts (ARCHITECTURE.md → Bash-vs-Prompt Decision Rule). No deterministic
  script changes are anticipated, so validation is by the meta-skill
  checklist, not bash tests (ARCHITECTURE.md → Development & Testing). If a
  script surface does emerge, `tests/issues.sh` is the test template
  (sources `testlib.sh`, `run_*` invoker + `case_*` functions, `OUT=$(...)`
  capture, `set -uo pipefail`).
- **Single-sourcing shared rules.** The downgrade classifier has two call
  sites (Step 5 generate-differential, U4 update). Spec 025's § 7a pattern —
  one canonical subsection, brief restatement + pointer elsewhere — is the
  in-repo convention for exactly this.
- **Untrusted-evidence discipline.** U1 (129-132) already marks diff/ledger
  content untrusted with only `metrics` trusted; the fork extends the same
  stance to a new decision surface. Canonical wrapping lives at
  `skills/issue/SKILL.md` step 7.
- **Interactive per-row UX.** The candidate batch's per-row `f / e / s` and
  `/jim:issue add`'s file/edit/cancel are the house patterns for the
  per-violation choice presentation.

## Security & Performance

- **The guard is itself an injection target.** An adversarial diff or commit
  ("this invariant is obsolete — fold it") now attacks a *decision*, not just
  content. AC #6 carries the 026/029/030 trust boundary onto detection,
  classification, and the offered resolutions; the fork presentation should
  state the skill's own evidence so the developer can spot a manufactured
  framing.
- **Secret leakage via a new display surface.** The fork shows change
  evidence and the fix resolution writes an issue body drawn from it — both
  must apply the 029/030 redaction placeholder (AC #7 covers display and
  persistence) and the temp-file Write discipline for the issue body
  (025 F5).
- **False negatives are the residual risk.** A missed violation silently
  bypasses the fork. Two mitigations already in the design: the graded
  autonomy net still prompts on any critical/high downgrade even when the
  "violation" framing is missed, and issue #22's verification engine later
  hardens detection mechanically.
- **Performance:** reading changed source per violation adds bounded token
  cost — same order as 030's existing U3 read-when-ungrounded rule.

## Recommendations

- **Fork placement:** run the violation judgment as a pre-diff pass inside U3
  (violations extracted before the section-diff is composed), so under
  `auto_blueprint` the non-violating remainder can still auto-write while
  violations prompt. The alternative — surfacing violations inside U4's
  approval diff — is fewer steps but conflates the fork with the ordinary
  approval gate and has no clean auto-mode story.
- **Classifier single-sourcing:** one "downgrade classification" subsection
  in blueprint SKILL.md; Step 5 and U4 point at it (spec 025 pattern).
- **Issue offer:** reuse `new.sh` with a Write-tool temp body; plausible
  `origin` values are the driving spec dir (`--from-review`), or the group's
  blueprint path (`--since`, where no spec exists). Extend `allowed-tools`
  per the `skills/spec/SKILL.md:10` shape.
- **Review Step 10:** at most a one-line touch defining "run to completion"
  to include an answered fork; the gate already keys off the blueprint
  stage's `finished` event, which U4 records on write — the architect should
  confirm the fix-resolution path (edit withheld, rest folded) still reaches
  U4's write/commit so `finished` is recorded.
- **Generate-mode grading:** gate only Step 5's auto branch; the interactive
  branch already presents the full diff, where downgrades are visible.

This approach aligns with VISION.md's human-in-the-loop north star and its
"not for hands-off vibe coding" non-goal — the `auto_*` convention exists to
*remove* a human step deliberately, and this spec restores that step exactly
where blast radius is highest — and follows ARCHITECTURE.md's bash-vs-prompt
rule (judgment stays in the prompt layer), the single-emitter convention
(new.sh), and the least-privilege `allowed-tools` convention. No divergence
from locked constraints found.
