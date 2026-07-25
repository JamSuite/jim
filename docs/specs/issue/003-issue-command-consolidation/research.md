---
spec: "docs/specs/issue/003-issue-command-consolidation/spec.md"
status: Active
date: "2026-06-03"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Issue Command Consolidation — subcommand surface

## Anchors

### 1. `jimconf.sh` — KEYS array, `default_for()`, `resolve()` dispatch

`/mnt/src/jim/skills/conf/scripts/jimconf.sh` L42: the `KEYS` array has 20 entries; the next two list-view config keys (`issue_list_group`, `issue_list_sort`, `issue_list_cols` or similar) go here.

`/mnt/src/jim/skills/conf/scripts/jimconf.sh` L48–72: `default_for()` is a `case` statement; each new key needs one `casename)  echo "value" ;;` arm.

`/mnt/src/jim/skills/conf/scripts/jimconf.sh` L99–125: `resolve()` branches on `require_*`, `auto_*`, or the bare `"issue_capture"` literal (L102), then appends `_path` to everything else. A new bare-name boolean follows the same special-case pattern; a new path-typed key gets the `_path` suffix treatment automatically.

Convention: `auto_*` prefix means "removes a human step"; bare names mean "human-in-the-loop default". New list-view keys are neither toggles nor path-shaped — they likely take a bare-name form analogous to `issue_capture` (one explicit OR arm) or a new `list_*` prefix family. Architect decides, but the dispatch arm in `resolve()` must be updated to match whatever form is chosen.

Tests for new keys: add to `tests/jimconf.sh` `case_no_config_returns_defaults` (L39) and `case_full_config_returns_overrides` (L70) following the existing pair-per-key pattern.

### 2. `jimfile.sh` — `next-id issue`, `path issue`, `is_valid_slug`

`/mnt/src/jim/skills/file/scripts/jimfile.sh` L200–216: `cmd_next_id` branches on `"issue"` first; returns `YYYYMMDD-<normalized-slug>`. The `num:` max-scan would live here (new branch or a helper) or in `index.sh`; this is the natural place to add `next-num issue` if the architect wants a script-side ordinal resolver.

`/mnt/src/jim/skills/file/scripts/jimfile.sh` L288–299: `path issue <slug>` — calls `is_valid_slug` then composes `<issues_dir>/<slug>.md`. This is the safe path composition surface for `show`'s resolution step; the `show` resolver must match a slug against the known set first, then call `path issue` only for the winner.

`/mnt/src/jim/skills/file/scripts/jimfile.sh` L131–147: `is_valid_slug` — the AC-C7 validation function (`^[a-z0-9][a-z0-9-]*$`). The `show` subcommand must route any argument through this (or an analogous check) before composing a path. Pure-integer arguments should be identified before the slug check and dispatched as ordinal lookups.

`/mnt/src/jim/skills/file/scripts/jimfile.sh` L57–58: `export LC_ALL=C` preamble — any new helper functions in the same script inherit this; a new script must replicate it.

### 3. `index.sh` — frontmatter field set, `relations:` parser, atomic write, origin-lint

`/mnt/src/jim/skills/issues/scripts/index.sh` L260–305: main loop parses `status`, `priority`, `title`, `origin`, `labels`, `created` — no `num:` field. The plan adds `num:` parsing here: `meta_num[$slug]="$(parse_simple_field "$fm" num)"`. The Issues section row (L415–420) must emit `num:` when present.

`/mnt/src/jim/skills/issues/scripts/index.sh` L116–145: `parse_relations()` — `awk` 2-space-indent state machine; not affected by `num:` addition.

`/mnt/src/jim/skills/issues/scripts/index.sh` L434–471: atomic `tmp + mv` write with `trap`-based cleanup. The `num:` backfill must replicate this pattern per-file (security.md Finding 4).

`/mnt/src/jim/skills/issues/scripts/index.sh` L362–387: origin-lint second pass (spec 018). New `num:` parsing is a third pass or can be folded into the main loop alongside the existing field reads at L290–297.

`/mnt/src/jim/skills/issues/scripts/index.sh` L442–465: the four rendered sections (`## Summary`, `## Issues`, `## Graph`, `## Integrity Warnings`). `list` and `stats` verbs parse these sections; adding a `## Num` section or extending `## Issues` rows with `num:` data is the integration point.

Confirmed: **no existing issue file carries a `num:` field** — the six live issues (`docs/issues/*.md` and `INDEX.md`) have none.

### 4. `render.sh` — current structure, INDEX.md parsing pattern

`/mnt/src/jim/skills/issues/scripts/render.sh` L1–200: current render is ~200 lines — summary parse (L90–96), cluster by origin + label (L99–149), blocking by out-degree (L153–187), integrity warnings passthrough (L190–197). Each section is an `awk` or `grep` parse over `INDEX.md`.

`/mnt/src/jim/skills/issues/scripts/render.sh` L47–48: `INDEX_SCRIPT="$HERE/index.sh"` — defensive regen call (L77–80). If scripts relocate from `skills/issues/scripts/` to `skills/issue/scripts/`, this relative reference must be updated.

`render.sh` today owns the full stats view (clusters + blocking). For spec 019: `stats` is essentially the current `render.sh` output minus trend analysis; `list` is a new per-issue enumeration over the `## Issues` section; `show` resolves one issue and formats its frontmatter + body. The architect should decide whether `render.sh` becomes a multi-subcommand dispatcher (`case "$1"`) or is replaced by a new `dispatch.sh`.

### 5. `skills/issue/SKILL.md` and `skills/issues/SKILL.md` — frontmatter and capture flow

`/mnt/src/jim/skills/issue/SKILL.md` L1–7: frontmatter — `agent: pm`, `argument-hint: "[subject]"`, `allowed-tools` names `jimfile.sh`, `jimconf.sh`, `skills/issues/scripts/index.sh`, `mkdir`, `Read`, `Write`, `Edit`.

`/mnt/src/jim/skills/issue/SKILL.md` L19–88: the capture flow steps 1–6. Step 7 (L109–124) is the untrusted-content wrapping discipline — must be preserved in the consolidated `add` subcommand.

The Validation Checklist (L130–137) currently has no `num:` field check. After consolidation it needs: `num:` is present in the frontmatter, value is a positive integer.

`/mnt/src/jim/skills/issues/SKILL.md` L1–58: the `issues` skill — 4 steps, no `agent:`, read-only. This entire skill is removed; its behavior migrates into the consolidated `issue` SKILL.md under `list`, `stats`, `show`, and help subcommands.

### 6. Seven 018 batch-protocol skills — `/jim:issues` references and `index.sh` path references

**`/jim:issues` string** appears in these locations (grep across `skills/*/SKILL.md`):

| File | Line | Content |
|---|---|---|
| `skills/issues/SKILL.md` | 3 | `description:` field — "Use when the user invokes /jim:issues" |
| `skills/issues/SKILL.md` | 9 | `# /jim:issues` heading |
| `skills/issues/SKILL.md` | 39 | subordinate-discipline note mentioning `/jim:issues lint` |
| `skills/sec/assets/security-template.md` | 109–113 | `### Candidate issues` comment mentions "see `/jim:issues`" |

The spec 019 AC requires updating the "review later" pointer. The seven batch protocols say `"See INDEX.md."` (not `/jim:issues`) in their summary lines — **no direct `/jim:issues` mention appears in the seven surfacing skills' batch steps**. The pointer to update is the `auto_issue_file` comment in `jimconf.toml.example` (L108: "review happens later via /jim:issues") and `skills/sec/assets/security-template.md` L113.

**`skills/issues/scripts/index.sh` path** appears in `allowed-tools` and body call sites across all seven surfacing skills plus `skills/issue/SKILL.md`:

| File | Line(s) | Context |
|---|---|---|
| `skills/build/SKILL.md` | 10, 172, 191 | `allowed-tools`; auto-file path; bulk "file all" |
| `skills/brainstorm/SKILL.md` | 11, 107, 126 | same |
| `skills/plan/SKILL.md` | 11, 166, 185 | same |
| `skills/debug/SKILL.md` | 11, 100, 119 | same |
| `skills/sec/SKILL.md` | 16, 264, 283 | same |
| `skills/spec/SKILL.md` | 10, 213, 232 | same |
| `skills/research/SKILL.md` | 11, 168, 187 | same |
| `skills/issue/SKILL.md` | 6, 101 | `allowed-tools`; step 6 regen call |

If scripts are relocated from `skills/issues/scripts/` to `skills/issue/scripts/`, all these references (15 `allowed-tools` clauses + 15 body call sites = 30 occurrences across 8 files) must be updated. If scripts stay in place, no path churn occurs — only `skills/issues/SKILL.md` is deleted.

### 7. Tests — `tests/issues.sh`, `tests/jimfile.sh`, `tests/jimconf.sh` structure

`/mnt/src/jim/tests/issues.sh` L1–888: 30 `case_issues_*` functions covering `index.sh` (happy path, status counts, relations, wikilinks, fences, absorption, integrity, origin-lint, atomic write) and `render.sh` (summary, clusters by origin/label, blocking order, warnings passthrough, read-only guarantee, header). Fixture helper `write_issue <dir> <slug> <fm> [<body>]` at L47.

New test file needed: `tests/issue.sh` (or extend `tests/issues.sh`) for the consolidated script's subcommand dispatch, `num:` parsing, `show` resolution, `list` filtering, `stats` output. A second new file — or section — is needed for the backfill script.

`/mnt/src/jim/tests/jimfile.sh` L493–612: 12 `case_jimfile_*` functions for `path issue` and `next-id issue`. New cases needed for `next-num issue` (max-scan) if the ordinal lookup goes through `jimfile.sh`.

`/mnt/src/jim/tests/jimconf.sh` L39–67: `case_no_config_returns_defaults` tests all 19 current keys as a flat list. New list-view config keys must be added here and in `case_full_config_returns_overrides` (L70).

Test conventions: `case_<file>_<behavior>()` naming; `run_<file>` per-invoker; `assert_eq`, `assert_match`, `assert_exit`, `assert_nonempty` helpers from `testlib.sh`; `fixture` and `empty_dir` for scratch setup; standalone-runnable tail using `[[ "${BASH_SOURCE[0]}" == "${0}" ]]`.

### 8. `jimconf.toml.example` and `agents/pm.md`

`/mnt/src/jim/jimconf.toml.example` L24: `issues_path = "./docs/issues/"` — unchanged. New list-view keys appear after the existing issue-tracking section (after L111). The `auto_issue_file` comment at L108 mentions `/jim:issues` and must update to `/jim:issue list`.

`/mnt/src/jim/agents/pm.md` L38: `skills: [spec, spec-check, vision, roadmap, brainstorm, issue]` — `issue` is already listed; `issues` is not listed. No change needed if `issues` skill is simply deleted.

## Local Patterns

**Subcommand dispatch in bash scripts** (`jimfile.sh` L447–461, `jimconf.sh` L196–207): `case "$subcmd" in ... esac` with `cmd_<verb>` handler functions. `render.sh` growing into the same pattern is the natural extension.

**Frontmatter parsing convention** (`index.sh` L100–109): `parse_simple_field` via `grep -E "^${field}:"` + `head -n 1` + `sed` strip. New `num:` field uses the exact same function with `field="num"`.

**Atomic write** (`index.sh` L434–471): `mktemp` + `trap 'rm -f "$tmpfile"' EXIT INT TERM` + final `mv`. The backfill must use the same per-file pattern (security.md Finding 4).

**BASH_SOURCE-relative inter-script refs** (`render.sh` L47–48, `jimfile.sh` L64): `HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then compose paths relative to `$HERE`. Any new dispatcher or relocated script must use the same form.

**`allowed-tools` format** (`ARCHITECTURE.md` L430–443): exact `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/path/to/script.sh *)` per script. Two Bash clauses needed when a skill calls two distinct scripts.

**Test template**: `tests/issues.sh` is the template for the new test file — same source path, same `run_*` pattern, same `write_issue` helper, same standalone tail.

## Security & Performance

**Path traversal in `show`** (security.md Finding 1): `show <id>` must resolve the argument against the indexed set of known slugs/ordinals/ids before composing any filesystem path. The `is_valid_slug` check at `jimfile.sh` L131–147 is necessary but not sufficient — it rejects structurally invalid slugs but does not confirm the slug is a known issue. Resolution must happen against INDEX.md's slug set or via a directory scan, not by `test -e` on the raw argument.

**Deterministic rendering** (security.md Finding 2): `list`, `stats`, `show` must not pass issue body content through the LLM for formatting. If any verb uses the LLM, the `<untrusted-issue-content>` wrapper (SKILL.md L113–120) is mandatory.

**`list` filter injection** (security.md Finding 3): the filter argument must be validated against the closed set `{open, closed, critical, high, medium, low}` before use in any `grep`/`awk` pattern. The same closed-set validation applies to configurable column values.

**Backfill atomicity** (security.md Finding 4): per-file `tmp + mv` mirrors `index.sh` DD #12. A crashed mid-backfill leaves all untouched files intact and already-written files with valid frontmatter — idempotency then completes the rest on retry.

**Duplicate ordinals**: per the spec they are non-fatal. The `show` resolver must handle the ambiguous case (list matches, ask to disambiguate) rather than silently picking one.

**Scale**: max-scan for `num:` reads frontmatter from every issue file at `add` time. For hundreds of issues this is acceptable (no subprocess-per-file — one `grep` or `awk` pass suffices). The backfill is a one-shot write so its cost is also acceptable.

## Recommendations

**Script location decision** (Insight 3): leaving `index.sh` and `render.sh` in `skills/issues/scripts/` avoids 30-occurrence path churn across 8 SKILL.md files. The directory becoming a scripts-without-a-SKILL-file is slightly untidy but matches how `skills/conf/scripts/` and `skills/file/scripts/` work — they each have a SKILL.md, but the scripts are the primary artifact. If scripts relocate, all 30 occurrences must be updated atomically. Recommend the architect evaluate tidiness vs. churn; the research surfaces both counts precisely.

**`num:` scan placement**: `index.sh` already reads every file's frontmatter in its main loop (L275). Adding `meta_num[$slug]` there costs nothing additional per-scan. A separate `next-num issue` operation (for `add`) can either re-scan all `meta_num` values after `index.sh` has run, or be a standalone function in a new helper. Architect decides the owning script.

**Backfill trigger**: the spec leaves the trigger open. Options: (a) auto-trigger on first `list`/`stats`/`show` invocation when any issue lacks `num:`; (b) explicit one-shot subcommand (`/jim:issue backfill`). Option (a) is invisible but writes to existing files without announcement; option (b) is explicit and lets the developer review the commit separately. The open question in the spec maps directly to this decision.

**Dispatcher structure**: `render.sh` as the `case`-dispatcher is the least-churn path (already parses INDEX.md for all three views). A new `dispatch.sh` that imports or calls `render.sh` functions is cleaner but requires a new script and an `allowed-tools` update everywhere.

## Peer Feedback

**For Architect:** The "review later" pointer the spec describes as a batch-protocol `POSTCONDITIONS` update (AC consolidation) is in practice `"See INDEX.md."` in the seven SKILL.md files — not a literal `/jim:issues` mention. The actual `/jim:issues` string lives in `jimconf.toml.example` L108 and `skills/sec/assets/security-template.md` L113, and the description field of `skills/issues/SKILL.md`. These are the three specific files to update; the seven SKILL.md batch steps do not need the pointer text changed (they say `See INDEX.md.` already).

**For Architect:** The `allowed-tools` clause in all seven surfacing skills and `skills/issue/SKILL.md` currently names `skills/issues/scripts/index.sh`. If the script moves, 30 strings across 8 files change. The spec tags this as an implementation choice, but the research makes the scope precise: 8 files, 30 occurrences (confirmed by grep). The architect should factor this into the task breakdown.

**For PM (Open Question confirmation):** The spec's open question on numeric-slug collision (`show 401`) is real. The existing test corpus has no purely numeric slugs, but the `is_valid_slug` regex (`^[a-z0-9][a-z0-9-]*$`) allows `401` as a slug. The proposed resolution (pure-int always means ordinal) is reasonable and consistent with the spec's resolution-precedence order. Recommend formalizing this in the spec before planning.
