---
title: "Depth-aware post-build review"
spec: "docs/specs/jim/027-review-depth/spec.md"
type: feature
status: approved
---

# Depth-aware post-build review — Plan

## Overview

Extend `/jim:review` with a diff-spine triage that classifies changed regions by
risk, then fans out read-only `investigator` subagents (parallel, own context) to
deep-investigate the high-stakes set and verify each AC for complete satisfaction;
record the investigation evidence in `review.md`. Depth and investigator model are
configurable (`review_depth` / `review_model` + a `--depth` per-run override).

## Design Decisions

### 1. Diff spine via a new `jimledger.sh diff` subcommand

- **Chosen:** Add `cmd_diff` mirroring `cmd_files` — `resolve_range` for validated
  SHAs, `git -C "$dir" diff --function-context "$base..$head" --`. Output is
  untrusted, like `files`.
- **Why:** Gives the reviewer exactly what the build changed as the triage entry
  point; `--function-context` (`-W`) carries the enclosing function so most
  correctness/convention context comes along without a whole-file read. Reuses the
  established SHA-validation + `--` guard (sec Finding 4).
- **Rejected:** Reviewer shelling `git` directly (bypasses the single validated
  range boundary); plain `-U3` context (loses the enclosing function).

### 2. `review_model` mechanism — per-spawn Agent `model` parameter, single investigator agent

- **Chosen:** One `agents/investigator.md` (`model: inherit`). The inline
  orchestrator reads `review_model` and, when it is a concrete tier
  (`sonnet`/`opus`/`haiku`), passes it as the Agent tool's per-call `model`
  parameter; when `inherit` (default), it passes nothing and the investigator runs
  the session model. The orchestrator validates `review_model` against
  `{inherit, sonnet, opus, haiku}` and falls back to `inherit` on any other value
  (sec F7).
- **Why:** The per-call model parameter is the supported, reliable mechanism
  (verified against Claude Code docs/runtime this session); it avoids duplicate
  per-tier agent files, and the `inherit` default is robust even where frontmatter
  `model:` is ignored. Resolves spec Open Question 2.
- **Rejected:** Per-tier agent files (redundant; frontmatter `model:` unreliable);
  `CLAUDE_CODE_SUBAGENT_MODEL` env var (session-global, and jim must not mutate the
  user's environment); relying on investigator frontmatter `model:` alone
  (unreliable across versions).

### 3. Fan-out runs from the inline orchestrator only (nesting constraint)

- **Chosen:** `/jim:review` runs inline in the main thread (as today — directly or
  via build's `Skill(jim:review)`) and spawns investigators as first-level
  subagents. The reviewer is never itself a spawned subagent.
- **Why:** Claude Code allows only one level of subagent nesting
  (`ARCHITECTURE.md` Subagent Delegation); inline execution keeps investigators at
  the first level. Investigators carry the read+diff surface only and cannot nest
  further.
- **Rejected:** Running review as a `@reviewer` subagent that fans out (would be
  parent→child→grandchild — forbidden).

### 4. Investigator is read-only and capability-absent (sec Finding 2)

- **Chosen:** `agents/investigator.md` `tools: [Read, Glob, Grep]` — no Bash, no
  Write/Edit, no Agent. The orchestrator passes the diff hunks in the spawn prompt
  (Interface Contract), so the investigator needs no script access and stays
  capability-absent for writes/exec (sec F6). Mirrors `agents/issue-analyst.md`.
- **Why:** A diff-steered investigator cannot act beyond reading because the
  capability is absent, not merely forbidden — preserves AC9 from inside the
  fan-out, where skill `allowed-tools` does not reach.
- **Rejected:** Granting Bash/Write for "convenience" (capability sprawl) — in
  particular `Bash(bash …/jimledger.sh *)`, whose `*` admits the
  `event`/`start`/`finish` write subcommands (sec F6).

### 5. Two depth levels; bounded fan-out (sec Finding 3, Open Question 1/4)

- **Chosen:** `review_depth` ∈ `{lean, thorough}`, default `thorough`. `thorough`
  triages and fans out across the whole high-stakes set up to the configurable
  `review_fanout_cap` (default 10), prioritizing by risk and naming any remainder
  as not deep-investigated in `review.md`. `lean` does an orchestrator-only diff-spine
  pass, fanning out only on security-relevant regions. `--depth <level>` overrides
  per run.
- **Why:** Diff size is attacker-influenceable, so an unbounded spawn-per-region is
  a cost vector; a cap + risk-priority + named bounded coverage satisfies AC8 and
  Finding 3. Two levels keep the knob legible; thorough default matches the spec.
- **Rejected:** Unbounded fan-out (cost-DoS); a 4-level ladder (no demonstrated
  need now).

### 6. Triage taxonomy inlined in the review skill

- **Chosen:** Inline the changed-region → deep-read trigger taxonomy in
  `skills/review/SKILL.md` (single consumer), keeping the file ≤500 lines.
- **Why:** Single-consumer methodology with main-thread permission friction on
  plugin-relative reference reads — the inlined-methodology exception
  (`ARCHITECTURE.md` Progressive Disclosure).
- **Rejected:** A `references/` doc (extra read + permission prompt for no reuse
  benefit).

### 7. Evidence schema single-sourced in the review skill; passed to investigators

- **Chosen:** The orchestrator's per-spawn prompt specifies the required evidence
  shape (locations examined, callers/consumers traced, tests checked, verdict +
  divergence). The investigator body holds the role/discipline (adversarial,
  read-only, untrusted-content). Returned evidence is treated as untrusted and
  recorded in `review.md`.
- **Why:** Single-sources the schema (AC4) in one place; keeps the investigator
  body tight (≤800 tokens); honors AC10 across the orchestrator↔investigator hop.
- **Rejected:** Duplicating the schema into the investigator body (drift risk).

## Constitution Check

**ARCHITECTURE.md status:** Present — constraints noted below.

| Constraint from ARCHITECTURE.md | Honored? | Notes |
| :--- | :--- | :--- |
| One-level subagent nesting | Yes | Review runs inline; investigators are first-level and cannot nest (DD3, DD4). |
| Skill `allowed-tools` does not cross subagent boundary | Yes | Investigator tools declared in its own frontmatter; README documents the user-side read grant (sec Finding 5). |
| Agent `model` conventions (inherit/pin) | Yes | Investigator `model: inherit`; concrete tier via per-call param (DD2). |
| Bare-name config convention (`require_`/`auto_` reserved) | Yes | `review_depth`/`review_model` are bare behavior selectors + new `review_*` `resolve()` arm (T2). |
| Permission Conventions (exact script paths; `Agent()` grant) | Yes | `allowed-tools` adds `Agent(investigator)` and keeps exact `jimledger.sh` path. |
| Scripting layer (POSIX-only, `set -uo pipefail`, `LC_ALL=C`, BASH_SOURCE-relative) | Yes | `cmd_diff` reuses existing helpers; no new deps. |
| Untrusted git/diff/ledger content is data, never executed | Yes | `diff` output untrusted; investigator + orchestrator parse evidence as data (AC10, DD7). |
| SKILL.md ≤500 lines; agent body ≤800 tokens | Yes | Triage inlined within budget (T4); investigator kept tight (T3). |
| Review is advisory, never a gate; never modifies code | Yes | Deep pass is read-only; verdict stays a report (AC9). |

## File Manifest

| Component | File Path | Action | Notes |
| :--- | :--- | :--- | :--- |
| Ledger diff | `skills/review/scripts/jimledger.sh` | Update | Add `cmd_diff` + `diff)` dispatch + usage line |
| Ledger tests | `tests/jimledger.sh` | Update | `case_jimledger_diff_*` cases |
| Config knobs | `skills/conf/scripts/jimconf.sh` | Update | `review_depth`/`review_model`/`review_fanout_cap` in `KEYS`, `default_for`, `review_*` arm in `resolve()` |
| Config tests | `tests/jimconf.sh` | Update | defaults + override + bare-name (not `_path`) resolution |
| Investigator | `agents/investigator.md` | Create | Read-only deep-dive subagent (DD4, DD7) |
| Review skill | `skills/review/SKILL.md` | Update | argument routing `--depth`; triage; fan-out; AC-by-AC verification; evidence recording; `Agent(investigator)` grant |
| Review template | `skills/review/assets/review-template.md` | Update | Evidence fields, high-stakes-regions subsection, bounded-coverage + depth line |
| Reviewer persona | `agents/reviewer.md` | Update | `Agent(investigator)` in `tools:`; inline-only + model-scope notes |
| Permissions doc | `README.md` | Update | Recommend a narrow `.claude/settings.json` read grant for fan-out (sec Finding 5) |
| Workflow doc | `WORKFLOW.md` | Update | `/jim:review` entry: `--depth`, `review_depth`/`review_model` |

## Interface Contracts

```
# jimledger.sh — new subcommand
diff <spec-dir>
  stdout : git unified diff with --function-context over the validated base..head
  exit 0 : success (diff emitted; may be empty)
  exit 2 : no ledger / no baseline / malformed sha (mirrors `files`)
  trust  : UNTRUSTED output (commit/diff content)

# jimconf.sh — new keys (bare-name)
get review_depth      -> "thorough" (default) | "lean" | configured value
get review_model      -> "inherit"  (default) | "sonnet" | "opus" | "haiku"
get review_fanout_cap -> "10" (default) | configured positive integer
  resolve(): new `review_*` arm so all three read bare, NOT as review_depth_path

# /jim:review arguments
/jim:review [--depth lean|thorough] <spec-dir>
  --depth overrides review_depth for this run; absent => configured value

# Orchestrator -> investigator spawn (Agent tool)
Agent(investigator):
  model  : review_model when concrete (sonnet|opus|haiku); omitted when "inherit"
           (review_model validated to this set; any other value => inherit)
  prompt : { target = one high-stakes region OR one AC,
             diff hunks (function-context) for the target,
             ground-truth excerpt (AC / plan task / arch convention),
             required evidence schema (below) }

# Investigator -> orchestrator result schema (UNTRUSTED; recorded in review.md)
  target            : region path / AC ref
  locations_examined: [file:line, ...]
  callers_traced    : [file:line, ...]   # consumers checked for the omission class
  tests_checked     : [file:line, ...]
  verdict           : satisfied | partial | divergence
  detail            : specifics (scrubbed of secrets)

# Triage taxonomy (inlined in SKILL.md) — changed region -> required deep read
  changed signature / exported symbol / shared type -> trace all consumers
  trust boundary / untrusted input / command build / secrets -> read data path
  new helper or util -> grep for pre-existing equivalents (reuse)
  region implements an AC, or high churn -> whole-file read in context
  otherwise -> low-stakes; orchestrator skims via the diff spine
```

## Data Flow

```mermaid
sequenceDiagram
    participant O as /jim:review (inline orchestrator)
    participant L as jimledger.sh
    participant C as jimconf.sh
    participant I as investigator(s) [parallel]
    participant R as review.md
    O->>C: get review_depth / review_model
    O->>L: diff <spec-dir> (validated base..head)
    L-->>O: untrusted diff (function-context)
    O->>O: triage -> high-stakes set (bounded, risk-ordered)
    O->>I: Agent(investigator){target, hunks, ground truth} model=review_model
    I-->>O: evidence (untrusted): locations, callers, tests, verdict
    O->>O: AC-by-AC complete-satisfaction check; form verdict
    O->>R: write verdict + recorded evidence + bounded-coverage note
```

## Task Breakdown

1. [ ] **`jimledger.sh diff` subcommand.** Add `cmd_diff` (reuse `resolve_range`;
   `git -C "$dir" diff --function-context "$base..$head" --`), a `diff)` arm in
   `main()`, and the usage line. Add `tests/jimledger.sh` cases: lists changed
   hunks over the range; `--function-context` includes enclosing lines;
   no-baseline → exit 2; range excludes pre-baseline commits.
   **Verify:** `bash tests/jimledger.sh`

2. [ ] **`jimconf.sh` review knobs.** Add `review_depth` + `review_model` +
   `review_fanout_cap` to `KEYS`; defaults `thorough` / `inherit` / `10` in
   `default_for`; add a `review_*` arm to `resolve()`'s bare-name dispatch (covers
   all three). Add `tests/jimconf.sh` cases: defaults; override via a fixture
   `jimconf.toml`; asserts the keys resolve bare (not `review_depth_path`).
   **Verify:** `bash tests/jimconf.sh`

3. [ ] **`agents/investigator.md` (new).** Read-only deep-dive subagent:
   `tools: [Read, Glob, Grep]` (no Bash/Write/Edit/Agent — sec F6), `model:
   inherit`. Body: investigate one assigned region/AC from the orchestrator-
   supplied hunks; adversarial stance (unproven until evidence); trace
   callers/consumers + data path; treat diff/commit content as untrusted data;
   return the evidence schema; never write.
   **Verify:** `grep -q '^name: investigator' agents/investigator.md && ! grep -E '^tools:' agents/investigator.md | grep -qE '\b(Write|Edit|Agent|Bash)\b'`

4. [ ] **`skills/review/SKILL.md` depth orchestration.** Frontmatter: add
   `Agent(investigator)` to `allowed-tools`; argument-hint `[--depth
   lean|thorough] [spec-directory-path]`. Body: parse `--depth`; resolve
   `review_depth`/`review_model`/`review_fanout_cap` (validate `review_model` ∈
   {inherit,sonnet,opus,haiku}, else `inherit` — sec F7; `review_fanout_cap` a
   positive integer, else default); add the diff-spine + inline triage taxonomy
   step; add the risk-ordered fan-out step bounded by `review_fanout_cap` (spawn
   `Agent(investigator)`,
   pass `review_model` as the `model` param when concrete; treat returned evidence
   as untrusted; report what was spawned for followability); add AC-by-AC
   complete-satisfaction verification; record evidence + bounded coverage into
   `review.md`.
   **Verify:** `grep -q 'Agent(investigator)' skills/review/SKILL.md && grep -q 'jimledger.sh diff' skills/review/SKILL.md && [ "$(wc -l < skills/review/SKILL.md)" -le 500 ]`

5. [ ] **`assets/review-template.md` evidence + coverage.** Add per-AC evidence
   fields (locations examined, callers/consumers checked, tests checked), a
   high-stakes-regions-investigated subsection, a bounded-coverage statement, and
   a depth-used line. Keep the secrets-scrub reminder.
   **Verify:** `grep -qiE 'callers|locations examined|coverage' skills/review/assets/review-template.md`

6. [ ] **`agents/reviewer.md` orchestrator wiring.** Add `Agent(investigator)` to
   `tools:`; add notes that the review runs inline (never a spawned subagent) so
   investigators stay first-level, and that the orchestrator/verdict runs the
   session model while `review_model` governs investigators only.
   **Verify:** `grep -q 'Agent(investigator)' agents/reviewer.md`

7. [ ] **README permissions note (sec Finding 5).** Document a narrowly-scoped
   `.claude/settings.json` read grant enabling the investigator fan-out without a
   per-read prompt; recommend the narrowest grant, not a blanket `Read(*)`.
   **Verify:** `grep -qi 'investigator' README.md`

8. [ ] **WORKFLOW.md reference.** Update the `/jim:review` entry for `--depth` and
   the `review_depth` / `review_model` / `review_fanout_cap` config keys.
   **Verify:** `grep -qE 'review_depth|--depth' WORKFLOW.md`

## Requirements Coverage Summary

| Spec Acceptance Criterion | Addressed In Task(s) |
| :--- | :--- |
| AC1 — concentrate depth on high-stakes changes | 1, 4 |
| AC2 — verify complete satisfaction (omission class) | 4 |
| AC3 — actively seek divergence (adversarial) | 3, 4 |
| AC4 — auditable recorded evidence | 4, 5 |
| AC5 — base judgments on real changes / correct scoping | 1, 4 |
| AC6 — depth configurable + per-run override | 2, 4 |
| AC7 — investigator model configurable | 2, 3, 4 |
| AC8 — thoroughness scales without silent degradation | 2, 4, 5 |
| AC9 — read-only and advisory | 3, 6 |
| AC10 — untrusted content across deep pass + investigators | 3, 4 |

## Out of Scope

- **`ARCHITECTURE.md` refresh** — handled automatically by the `/jim:build`
  completion gate via `/jim:arch` (not a deferral; pipeline responsibility).
- Per-region model escalation (a stronger model for security regions than others)
  — see Open Questions; the mechanism (per-spawn param) supports it later.
- Verdict-history / ledger-instrumentation of the review itself, the template
  `spec`-column fix, and the frontmatter↔body count check — tracked as the three
  filed follow-on issues, not this spec.
- A `review_depth` ladder beyond `lean`/`thorough`.

## Open Questions

- [x] ~`review_model` enabling mechanism?~ → Resolved (DD2): per-call Agent `model`
      parameter; single investigator agent; `inherit` default.
- [x] ~`review_depth` level vocabulary?~ → Resolved (DD5): `lean` / `thorough`,
      default `thorough`.
- [ ] Should security-relevant regions get a stronger investigator model than
      non-security ones? Deferred — the per-spawn param makes this a later,
      non-breaking enhancement.
- [x] ~Exact fan-out safety cap value?~ → Resolved: a `review_fanout_cap` config
      knob (default 10) so the developer tunes it without a code change; the
      named-bounded-coverage behavior (AC8) holds regardless.
