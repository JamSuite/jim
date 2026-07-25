---
spec: "spec.md"
status: Active
date: "2026-07-07"
---

# Research: Blueprint-surface approval-gate presentation

Phase 0 local archaeology only. Phase 1 (external) skipped — this is a bug in
jim's own prompt text against the Claude Code harness; no external dependency.

**Alignment.** Directly serves VISION.md's north-star constraints — *"human-in-the-loop
approval at every phase gate"* and *"Not a black box … transparency over automation"* —
by restoring the visibility those gates silently assume. Follows ARCHITECTURE.md →
Plugin Conventions on every count: the § 7a shared-contract-by-reference pattern, the
`references/` progressive-disclosure pattern, and the cross-file textual-invariant test
precedent. No divergence from any locked constraint.

## Anchors

**Gate sites to update (each references the canonical rule; the checked set for AC 6):**

- `skills/blueprint/SKILL.md:140` — Step 5 prompt branch: *"Present the proposed blueprint (or the diff, for an update) and ask …"*. The primary site.
- `skills/blueprint/SKILL.md:124-131` — Step 4a downgrade prompts (itemized `critical`/`high` + Provides downgrade summaries; the shared grading rule Step 5 and U4 both point at).
- `skills/blueprint/SKILL.md:274` — U2a regen branch: *"otherwise present it and wait"*.
- `skills/blueprint/SKILL.md:314` — U4 targeted-diff: *"present the whole diff, ask for confirmation, and wait"*.
- `skills/blueprint/SKILL.md:456` — Retire mode step 2: *"present the proposed retirement, and wait"*.
- `skills/blueprint/SKILL.md:378-380` — M2 map create/update: *"present the full map draft with the scrub reminder … write only on explicit approval"*.
- `skills/blueprint/references/fork-grounding.md:119-154` — U3a violation-fork presentation (batched fork; evidence quoted only in a delimited block; asymmetric bulk actions; *"Wait for every violation's resolution"*).
- `skills/blueprint/references/reconcile-methodology.md:119-136` (findings report) + `:177-205` (issue offer) — reconcile-findings presentation.
- `skills/partition/SKILL.md:113-119` — Step 3 proposal (*"Present the proposal with cited evidence per group"* — evidence tables long by design) + `:121-139` — Step 4 hard gate.

**Model files (patterns to imitate, not edit):**

- `skills/issue/SKILL.md:190-211` — **§ 7a Candidate-batch contract**: the exact template for "define a rule once, reference it by path." Heading: `### 7a. Candidate-batch contract (shared across surfacing skills)`; body calls itself *"the single canonical definition … each surfacing skill carries a brief restatement plus a pointer here rather than a verbatim copy."*
- `tests/jimfile.sh:34-40` (`extract_is_valid_id` helper) + `:911-919` (`case_jimfile_is_valid_id_triplicate_identical`) — the cross-file textual-invariant regression precedent (asserts three copies byte-identical). Second instance: `tests/issues.sh:1476-1493` (`extract_ts_shape` + `case_issues_timestamp_shape_triplicate_identical`, guarding a `# SYNC(ts-shape)` marker).
- `skills/meta-skill/SKILL.md:85-115` (§ 4 Validate) — checklist home; item at `:98` is the exact shape for a new gate-presentation item (*"If the skill carries an end-of-phase candidate batch, it references the canonical fileable bar in `skills/issue/SKILL.md` § 7a …"*).
- `skills/meta-agent/SKILL.md:105-131` (§ 4 Validate) — sibling checklist.

**New file to create:** the canonical rule doc, e.g. `skills/blueprint/references/gate-presentation.md` (home decision is a plan call — see Recommendations).

## Local Patterns

- **Shared-rule-by-reference (§ 7a).** The precedent is a *section inside a SKILL.md*, referenced from other skills as `` (`skills/issue/SKILL.md` § 7a) ``. Two reference phrasings already in-tree: *"the shared § 7a contract (`skills/issue/SKILL.md`)"* (partition `:187`) and *"Render the batch per the candidate-batch contract (`skills/issue/SKILL.md` § 7a)"* (reconcile-methodology `:182`). The gate-presentation rule follows the same "single canonical definition + pointer" discipline.
- **Progressive-disclosure references.** Skills point at a `references/*.md` with *"… live in `references/X.md`; read it before running."* (blueprint `:350`, `:417`; partition `:27-29`). Reading a reference needs no `allowed-tools` grant — it is a plain `Read`. So a new `gate-presentation.md` costs nothing in permissions.
- **Test template.** `tests/jimfile.sh` (sourced `testlib.sh`, `case_*` functions, `assert_eq`/`assert_nonempty`, `extract_*` helpers). The triplicate-identical cases are the direct model: a helper greps the invariant out of each target file, and a `case_*` asserts presence/consistency. A gate-presentation regression case greps each enumerated gate-site file for the canonical-rule reference token and asserts it is present.
- **Scratchpad working files.** Precedent exists: partition writes its territories-file *"to the session scratchpad — a working file, never committed"* (`skills/partition/SKILL.md:97-98`). The reviewable-file mechanism reuses this convention.
- **Decline discipline (current).** Blueprint/partition gates say *"On decline, write nothing"* (e.g. `:457`, partition `:131`). A pre-approval reviewable-file write is a new artifact this discipline must now account for (AC 4).
- **Secret-scrub / untrusted-content rules.** Blueprint scrubs secret-looking values to `secret-looking value at <path:line>` (`skills/blueprint/SKILL.md:83-85`) and quotes untrusted evidence only inside delimited blocks. A reviewable file written for a gate inherits these — the draft-to-file step must not become a secret-exfiltration or injection bypass.

## Security & Performance

- **Safety, not feature.** These gates *are* jim's hard human-gate safety property; the bug is that the safety is only as real as what renders. The fix's own risk surface:
  - **Decline cleanup (AC 4).** A pre-approval file write must be removed on decline, or "nothing written before approval" silently weakens to "nothing *committed*."
  - **Empty/truncated commit (AC 5).** The observed session committed an empty `spec.md` from a cleared temp file. Mitigations to weigh: keep the approved draft in context (so a vanished file can't empty the write); `test -s` guard before any file-sourced ledger/commit.
  - **No new leak/injection path.** The reviewable file must honor the existing secret-scrub and untrusted-evidence-delimiting rules; the summary preserves load-bearing content verbatim but not secrets.
- **Performance:** negligible — one extra file write + a summary per gate; no hot path.

## Recommendations

Options/trade-offs for the architect (not decisions):

1. **Rule home.** (a) A standalone `skills/blueprint/references/gate-presentation.md` — matches the progressive-disclosure references pattern, is cleanly referenceable from the two reference docs and from partition, and keeps the SKILL.md bodies short (meta-skill `:95` caps SKILL.md ≤500 lines). *Recommended.* (b) A `§`-section inside `skills/blueprint/SKILL.md` — closer to the literal § 7a precedent, but a section is awkward to cite from sibling reference files and grows the SKILL.md. Blueprint is the natural owner either way (partition materializes every write through the blueprint surface).
2. **Reviewable-file location** (spec Insight 1). Scratchpad (safer default; needs decline cleanup) vs. target-path-in-place (clean when nothing commits until approval — true for blueprint generates — but decline must delete). Scratchpad has in-tree precedent (partition territories-file).
3. **Regression check** (AC 6). A `tests/*.sh` `case_*` modeled on `case_jimfile_is_valid_id_triplicate_identical`: for each enumerated gate-site file, grep for the reference token (e.g. the `gate-presentation.md` path string) and assert present. Decide the test's home (a new `tests/gate-presentation.sh`, or fold into an existing file) and the exact token.
4. **Threshold wording** (spec Insight 2). ~20 lines traces to the observed AskUserQuestion preview truncation; the architect fixes the exact trigger phrasing.

## Peer Feedback

Signals for the architect to weigh at planning (no plan exists yet to invalidate — status stays `Active`):

- **Grep-test vs. "prompts are checklist-validated."** `CLAUDE.md` steers prompt validation to checklists, not bash assertions. Frame the AC-6 test narrowly as a **mechanical textual invariant** ("the reference string is present at each site") — exactly what the triplicate-identical cases already do over script text — *not* as semantic prompt validation. That keeps it consistent with the codebase's testing doctrine; the semantic "is this rule followed well" stays with the meta-skill/meta-agent checklist item (AC 7). Worth an explicit note in the plan so the test's scope isn't over-read.
- **ARCHITECTURE.md convention entry.** No prior harness-rendering/gate-presentation doctrine exists anywhere in `skills/` or `docs/`. Once this lands, the new doctrine belongs in `ARCHITECTURE.md` → Plugin Conventions. Per project convention that document is maintained via `/jim:arch`, so schedule it as a **post-build** step, not a hand-edit inside this spec's build.
