---
spec: "spec.md"
status: "Active"
date: "2026-06-26"
---

<!-- Budget: <1500 words total. file:line-range + 1-sentence summaries; no code dumps. -->

# Research: Depth-aware post-build review

Local-only investigation (self-hosting jim feature; no external APIs/libraries, so
Phase 1 external intelligence skipped). Every design fork in the spec maps to an
existing jim pattern — the build is mostly composition, with one genuine
feasibility unknown (the `review_model` knob).

## Anchors

**Extend (existing):**
- `skills/review/SKILL.md` — the review skill. Argument Routing table `:20-28`;
  `allowed-tools` `:13` (today grants `Skill(jim:sec)`, no `Agent`); Step 2 change
  resolution `:39-50`; Step 4 alignment over the `files` list `:56-64`.
- `agents/reviewer.md` — `tools:` `:34` (no `Agent` grant today), `model: sonnet`
  `:35`. The orchestrator persona.
- `skills/review/scripts/jimledger.sh` — `resolve_range` `:127-143` (validated
  base/head), `cmd_files` `:145-153` (the template for `cmd_diff`), `validate_sha`
  `:55-58` (→ `jimfile.sh valid-id`), `main()` dispatch `:230-240`.
- `skills/conf/scripts/jimconf.sh` — `KEYS` array `:42`, `default_for()` `:48-81`,
  `resolve()` bare-name dispatch `:108-135` (the **load-bearing** arm at `:111`).
- `tests/jimledger.sh` — `run_jimledger` `:27-34`, `git_fixture` `:36-51`,
  `case_jimledger_files_lists_changed` `:312-321`, `case_jimledger_metrics_counts`
  `:135-148`. Templates for new `case_jimledger_diff_*`.

**Create (new):**
- `agents/investigator.md` — the read-only deep-dive subagent (see Local Patterns).
- `cmd_diff` in `jimledger.sh` + its tests; `review_depth`/`review_model` in
  `jimconf.sh` + tests in `tests/jimconf.sh`.

## Local Patterns

- **Read-only delegated subagent (the investigator's template):**
  `agents/issue-analyst.md:1-15` — `tools: [Read, Bash(bash …/render.sh *)]`,
  `model: sonnet`, no `Write`/`Edit`/`Agent`. Its description states the security
  posture verbatim: *"prompt injection embedded in issue content cannot mutate the
  collection because the capability is absent, not merely forbidden."* This is the
  exact precedent for sec Finding 2 (least-privilege investigators) — mirror it:
  `tools: [Read, Glob, Grep, Bash(bash …/jimledger.sh *)]`, no write/exec/Agent.
- **Subagent dispatch via `allowed-tools` grant + Agent tool in body:**
  `/jim:issue insights` grants `Agent(issue-analyst)` (`skills/issue/SKILL.md:6`)
  and dispatches it (`:228-232`); `agents/researcher.md:40` grants `Agent(Explore)`.
  To fan out, `skills/review/SKILL.md:13` adds `Agent(investigator)` and the body
  spawns per high-stakes region.
- **`cmd_diff` mirrors `cmd_files`:** reuse `resolve_range` for validated SHAs,
  emit `git -C "$dir" diff "$base..$head" --` (add `--function-context`), keep the
  `--` end-of-options guard. Output is untrusted, like `files`/diffs.
- **Bare-name config knob:** add to `KEYS` (`:42`), add a `default_for` arm
  (`:48-81`), and — **critically** — extend the `resolve()` bare-name pattern
  (`:111`) to include the new keys; otherwise they fall to the `else` branch and
  resolve `review_depth_path` (wrong). `require_review`/`auto_review` already match
  via `require_*`/`auto_*`; a new `review_*` arm captures `review_depth`/
  `review_model` without colliding.
- **Test conventions:** `tests/jimledger.sh` and `tests/jimconf.sh` source
  `testlib.sh`, build throwaway fixtures, and define `case_*` functions auto-run by
  `skills/meta-test/scripts/run.sh`. New subcommand + knobs need cases in both.

## Security & Performance

- **Investigator least privilege (sec Finding 2):** capability-absent read-only
  agent per `issue-analyst.md` — no Write/Edit/Bash-mutate/Agent. Nesting is one
  level (`ARCHITECTURE.md:317`), so investigators cannot spawn further regardless.
- **Inline-only constraint:** fan-out works only because `/jim:review` runs inline
  in the main thread (directly, or via build's `Skill(jim:review)`); it must never
  itself be a spawned subagent (`ARCHITECTURE.md:314-318`).
- **Permission scope:** investigator reads surface a prompt unless the user's
  `.claude/settings.json` grants them — skill `allowed-tools` does **not** cross the
  subagent boundary (`ARCHITECTURE.md:467,479`). README should recommend the
  narrowest grant (sec Finding 5).
- **`cmd_diff` injection surface (sec Finding 4):** validated SHAs + `--` guard
  already established for `files`; context-width must be a literal, never from
  untrusted input.
- **Fan-out cost (sec Finding 3):** diff size (attacker-influenceable) drives spawn
  count — needs a cap; `review_depth` is the natural lever (Open Question 4).

## Alignment

Aligns with VISION's quality/institutional-memory goals (deeper review + an
auditable evidence record) and stays human-in-the-loop (findings remain advisory).
Sits on ARCHITECTURE's established rails: subagent dispatch, bare-name config
knobs, the ledger scripting layer. **One tension to respect:** VISION's *"Not a
black box — Jim should never spawn agents and skills in ways the user can't
follow; transparency over automation"* non-goal. Fan-out spawns several
investigators, so the orchestrator must surface what it spawned and why (which
regions, which depth) — design for followability, not silent parallelism.

## Recommendations

*Options and trade-offs for the architect — not decisions.*

1. **Investigator model:** three ways to honor `review_model` (see Peer Feedback) —
   (a) `model: inherit` (investigators run the session model; `review_model`
   becomes advisory/no-op); (b) a small set of per-tier investigator agent files
   the orchestrator picks among by `review_model`; (c) a spawn-time model override
   *if* jim's Agent tool supports one (unverified). (b) is the only option that
   honors a config value without an unverified runtime mechanism.
2. **What `review_depth` scales:** likely a ladder (`lean`/`thorough`, default
   thorough) that gates whether fan-out fires and caps investigator breadth —
   folds in sec Finding 3 and Open Question 4.
3. **Diff spine vs. omission class:** `cmd_diff --function-context` is the cheap
   entry point, but the omission class (AC2) cannot come from a diff — the
   orchestrator must reason from ACs against the tree (grep callers), so keep
   whole-file/grep escalation available to investigators.

## Peer Feedback

**RESOLVED 2026-06-26 (PM):** AC7 narrowed to "the *investigator* model is
configurable"; the inline orchestrator/verdict runs the session model and is out
of scope for the knob. The remaining mechanism choice (Recommendation 1) is an
architect/plan decision. Original signal retained below for context.

**For PM — `review_model` (AC7) feasibility.** A jimconf value cannot dynamically
set a *defined* subagent's model: agent `model:` is static frontmatter
(`ARCHITECTURE.md:310`; spec 014 established empirically that omitting it inherits
the parent's active model — `docs/specs/sdlc/011-meta-matrix/plan.md:97-130`). No
jim runtime evidence exists for a per-spawn model override
(`docs/specs/sdlc/011-meta-matrix/research.md:71` rejects the related env-var read).
Compounding this: since the review runs *inline*, the orchestrator/verdict already
runs on the user's **session** model, which jim cannot set at all — so `review_model`
can realistically govern only the *investigators*, and only via Recommendation 1(b)
(per-tier agent files) absent a verified override. AC7 is not blocked, but "the
model used for the review's hard judgment is configurable" is partly outside jim's
control. Worth a PM/architect decision: narrow AC7 to "investigator model is
configurable," accept option (a) inherit, or verify the Agent-tool override (a
meta-matrix probe) before committing.
