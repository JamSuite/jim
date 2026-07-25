---
spec: "spec.md"
status: "Needs PM Review"
date: "2026-06-19"
---

# Research: Post-build review phase

## Anchors

**Reuse — workflow integration**

- `skills/build/SKILL.md:10` — build's `allowed-tools` already declares
  `Skill(jim:arch)` and `Skill(jim:sec)`; adding `Skill(jim:review)` follows the
  same shape. The new offer/auto step also needs `Skill(jim:review)` here.
- `skills/build/SKILL.md:200` and `:206` — **build currently states "do not
  auto-invoke review" / "no auto-review."** This feature overturns that rule (see
  Peer Feedback). The new end-of-build offer/`auto_review` step lands near here.
- `skills/build/SKILL.md:111` (Step 6, completion gate) and the `Skill(jim:arch)`
  refresh substep — closest precedent for a build→skill hand-off and for the
  ledger's "finished" event recording.
- `skills/build/SKILL.md:40-49` / `skills/plan/SKILL.md:39-49` — the
  `require_security`/`auto_security` SET/IF gate. Template for a `require_review`/
  `auto_review` gate (here the offer-by-default form, not a blocking gate).
- `skills/plan/SKILL.md:122-126` — the conversational pre-approval *offer* in
  default mode (`IF require_* != "true" AND auto_* != "true" THEN Offer …`).
  Direct template for build's "Run review now? (`/jim:review`)" offer.
- `skills/sec/SKILL.md:196-208` — routing step: `IF auto_security == "true"`
  auto-edits artifacts, `ELSE` offers conversationally. Template for how
  `/jim:review` routes findings and for the `auto_review` branch.

**Reuse — mechanism**

- `agents/security.md:2,42-44` (`name`/`skills`/`tools: [Read, Write, Edit,
  Glob, Grep]`/`model: sonnet`) — closest agent template for `@reviewer`.
- `agents/issue-analyst.md:13` — `tools: [Read, Bash(bash
  ${CLAUDE_PLUGIN_ROOT}/skills/issue/scripts/render.sh *)]`: the canonical
  *least-privilege, read-mostly* agent (sec Finding 6). `@reviewer` should mirror
  this narrowness (read; write `review.md`; the issue batch; ledger-read script).
- `skills/file/scripts/jimfile.sh:168` — `is_valid_id()` (`^[A-Za-z0-9]
  [A-Za-z0-9._-]*$`, ≤128, no `..`). **Reuse directly to validate a git SHA /
  range token** before interpolation (sec Finding 4). Synced across 3 files —
  honor the SYNC note.
- `skills/file/scripts/jimfile.sh:136-138` — `now`/ISO-8601 UTC helper for ledger
  timestamps (duration deltas). `:127-129` — `today` (YYYYMMDD).
- `skills/conf/scripts/jimconf.sh:48` `default_for()` and `:106-109` `resolve()`
  with the bare-name dispatch arm (`require_*`/`auto_*`/`issue_*`). Extension
  points for `require_review` / `auto_review` (bare-name booleans).
- `skills/issue/SKILL.md:172-177` (the `<untrusted-issue-content>` wrapper) and
  `:182` (the candidate-accumulation untrusted-source rule) — verbatim pattern
  for sec Findings 1 & 2.

**New (to be created)**

- `skills/review/SKILL.md`, `agents/reviewer.md`, `{spec-dir}/review.md`.
- A ledger helper (e.g. `skills/review/scripts/jimledger.sh`) + its test file
  `tests/jimledger.sh`.

## Local Patterns

- **`security.md` is the precedent for the artifact, not a `jimfile` KIND.**
  `/jim:sec` writes `{spec-dir}/security.md` directly (frontmatter + body,
  `reviewed_phases:` array) — it is *not* in `jimfile.sh`'s `KINDS`
  (`:67` = `spec plan research debug brainstorm issue`). `review.md` (and the
  ledger, also a spec-sibling) can follow suit, so the `jimfile.sh` surface stays
  minimal — mainly reusing `is_valid_id`. No new KIND required.
- **Sentinel logic-flow** (ARCHITECTURE.md → Logic-Flow Conventions): config
  gates use `SET x = !\`bash … get key\`` then paren-free `IF x == "true"`.
- **Bash-vs-prompt split** (ARCHITECTURE.md → Bash-vs-Prompt Decision Rule):
  deterministic work (diff scoping, git metric extraction, ledger append/parse,
  SHA validation) → `jimledger.sh`; judgment (alignment verdict, drift severity,
  finding text) → the reviewer prompt.
- **Test harness:** `skills/meta-test/scripts/testlib.sh` (asserts/fixtures);
  template per-script test `tests/jimfile.sh` (invoker captures OUT/ERR/RC) and
  multi-script `tests/issues.sh`. Scaffold a new file via `/jim:meta-test
  scaffold jimledger`. `set -uo pipefail`, bash+POSIX only, no `git`-as-dep
  beyond the system binary.

## Security & Performance

- **Net-new territory: jim scripts do not currently shell out to git
  operationally.** The only `git` call in the codebase is a read-only
  `git status` advisory in `skills/issue/scripts/migrate.sh:154`. `jimledger.sh`
  / review would be the *first* component to read git history for data — so the
  CLAUDE.md "never `source`/`eval`; parse with grep/sed/cut" rule and SHA
  validation (sec Finding 4) are the load-bearing guardrails. Use plumbing
  (`git rev-list --count`, `git diff --shortstat`, `git log --format=…`) with
  `--` end-of-options guards and validated SHA inputs.
- **Untrusted content** (sec Findings 1, 2): commit messages / diffs / ledger
  text are attacker-influenceable; wrap per `skills/issue/SKILL.md:172-177` and
  keep the verdict judgment-based.
- **Disclosure into a committed, soon-public artifact** (sec Finding 3): prefer
  counts/locations over raw diff content in `review.md`/ledger.
- **Performance:** git plumbing over a large history and ledger parsing are
  cheap and bounded; the reviewer's LLM pass dominates cost. Bulk codebase
  reading (alignment-vs-architecture) can delegate to `Agent(Explore)` as
  `/jim:research` does, keeping the main reviewer context lean.

## Recommendations

*(Options for the architect — not decisions.)*

1. **Artifact as spec-sibling (mirror `security.md`)** — write `review.md` and
   the ledger directly into `{spec-dir}`; avoid adding a `jimfile` KIND. Smallest
   blast radius; `jimfile.sh` change is limited to reusing `is_valid_id`.
2. **Config: two bare-name booleans** `require_review` / `auto_review` in
   `default_for()` + the `resolve()` bare-name arm, mirroring `*_security`.
   Default both `"false"` (offer-by-default).
3. **Reviewer agent: least-privilege**, modeled on `issue-analyst.md` narrowness
   plus a `Write`/`Edit` for `review.md` and the issue-batch scripts; optional
   `Agent(security)` delegation for the regression lens.
4. **Ledger: committed append-only event log** (brainstorm decision) — a shared
   `jimledger.sh append <spec> <phase> <event> [k=v…]`, line-oriented, written by
   build, read by review. Interruption = dangling `started`; re-run = repeated
   pairs; durations = timestamp deltas.
5. **Diff scoping: recorded baseline SHA** (`base..head`), validated via
   `is_valid_id`; NOT `Spec:` trailers.

## Peer Feedback

- **For PM/Architect — a behavioral rule must be overturned, not just extended.**
  `skills/build/SKILL.md:200` ("do not auto-invoke review") and `:206` ("no
  auto-review") are explicit current prohibitions. Spec AC #1 (build offers
  review by default; `auto_review` runs it) directly changes these lines. This is
  feasible and parallels `auto_security`, but it is a *coordinated edit to an
  existing hard rule*, not a pure addition — call it out in the plan so the
  change is intentional and the "no auto-ship" half of `:206` is preserved.
- **For PM — strategic sequencing.** `ROADMAP.md` "Now" is v2.0-RC1
  (docs/release) and "Next" is v2.0 feedback; a new SDLC phase is not currently
  sequenced (closest fit: "Later"). The feature aligns strongly with the VISION
  north star (institutional memory; the spec/plan/review archive) and jim's
  human-in-the-loop / transparency non-goals — but consider whether it lands in
  this release or a 2.x bucket, and update the roadmap accordingly.
