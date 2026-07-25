---
spec: "docs/specs/sdlc/007-build-hooks/spec.md"
status: Active
date: "2026-05-07"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Configurable build hooks — per-commit and pre-completion gates

## Anchors

**`skills/conf/scripts/jimconf.sh`** — the three extension points the plan must touch:

- `KEYS` array, line 42: `readonly KEYS=(specs architecture vision roadmap brainstorms debug pre_commit)`. The three new short keys (`pre_completion`, `require_pre_commit`, `require_pre_completion`) must be appended here.
- `default_for()`, lines 48-59: one `case` arm per key returning its documented default. New arms: `pre_completion) echo "./pre-completion.sh"`, `require_pre_commit) echo "false"`, `require_pre_completion) echo "false"`.
- `parse_value()` regex, lines 73-81: `grep -E "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\""` — unchanged; it matches any top-level `KEY = "value"` line. The new TOML keys (`pre_completion_path`, `require_pre_commit`, `require_pre_completion`) fit the existing regex without modification.
- `resolve()`, lines 83-98: assembles `toml_key="${cli_key}_path"`. This works for `pre_completion` → `pre_completion_path`, but `require_pre_commit` and `require_pre_completion` are not path keys — their TOML names are the same as their CLI names. The plan must decide whether `resolve()` is extended or whether a parallel lookup path handles the boolean flags. This is the one structural divergence in the existing flow. See Peer Feedback.

**`skills/file/scripts/jimfile.sh`** — `cmd_get`, lines 135-142: a one-liner that calls `jimconf_get "$cli_key"`, which shells out to `jimconf.sh get <key>`. No changes to `jimfile.sh` needed if `jimconf.sh` handles all three new keys; all consumers calling `jimfile.sh get pre_completion` (or `require_pre_commit`, `require_pre_completion`) will work identically.

**`tests/jimconf.sh`** — existing `pre_commit` test cases the plan must mirror:

- `case_pre_commit_default()`, lines 188-193: `cd` into `empty_dir`, runs `bash "$SCRIPT" get pre_commit`, asserts `./pre-commit.sh`. Mirror pattern: `case_pre_completion_default()`, `case_require_pre_commit_default()`, `case_require_pre_completion_default()`.
- `case_pre_commit_overridden()`, lines 195-201: uses `fixture` helper to write a TOML snippet, asserts override value via `-c`. Mirror pattern: three `case_*_overridden()` functions.
- `case_no_config_returns_defaults()`, lines 39-55: iterates `"key:expected"` pairs. New pairs needed: `pre_completion:./pre-completion.sh`, `require_pre_commit:false`, `require_pre_completion:false`.
- `case_full_config_returns_overrides()`, lines 59-75: fixture with all keys; add three new TOML lines and three new `run -c ... get ...; assert_eq` lines.
- `case_list_outputs_all_keys()`, lines 97-112: hardcoded `assert_eq "list line count" "7"` must become `"10"`. Add three new `assert_match` lines.
- `case_keys_outputs_valid_keys()`, lines 115-121: hardcoded expected string lists all 7 keys; must add the three new keys in declaration order.
- `case_malformed_lines_are_ignored()`, lines 142-158: hardcoded `"7"` line count must become `"10"`.
- No dedicated `-c <path>` test for `pre_commit` specifically — the general `case_dash_c_reads_specified_file()` (lines 169-174) covers the flag. New keys do not need individual `-c` cases beyond the override pattern.

**`skills/build/SKILL.md`** — the two locations the plan rewrites:

- **Step 5 completion gate, lines 89-97** (full block): the existing `IF (...get pre_commit...) EXISTS THEN DO: / 1. Run it via Bash. / 2. Show the full output. / DONE` block. This entire block is replaced by the pre-completion gate using `get pre_completion`, plus the `require_pre_completion` halt path.
- **Step 3 TDD loop, lines 46-78** — the Commit sub-section at lines 67-69 names the three commit types (`test:`, `feat:`/`fix:`, `refactor:`). The per-commit gate must be inserted here as a new step before or after Commit. The plan must pick a position (before commit, so a fail prevents the commit from landing) and express it as a `THEN DO:` block.

**`jimconf.toml.example`** — new keys land after line 29 (after `pre_commit_path = "./pre-commit.sh"`). Lines 25-29 are the `pre_commit` block: a 2-line comment explaining the existence-gate pattern, then the key. Mirror that comment style for the three new keys — one group of two `#` lines per key, keeping the existing column alignment.

**`ARCHITECTURE.md` Scripting Layer** — the configurable-paths sentence is on line 261: `"... seven configurable paths (specs_path, architecture_path, vision_path, roadmap_path, brainstorms_path, debug_path, pre_commit_path). Missing file or missing keys silently fall through to defaults..."`. The plan extends this to ten keys, adding `pre_completion_path`, `require_pre_commit`, `require_pre_completion` to the parenthetical.

## Local Patterns

**`IF (X) EXISTS THEN DO:` multi-step block usage across skills:**

The build skill's existing step 5 gate (lines 91-95 of `skills/build/SKILL.md`) is the only instance in the codebase that wraps a script execution + output display inside a `THEN DO:` block — making it the canonical prior art for the new per-commit and pre-completion gates. Other skills use the idiom exclusively for doc reads:

- `skills/plan/SKILL.md`, lines 53-57: architecture doc read with ELSE branch (multi-step block + ELSE)
- `skills/arch/SKILL.md`, lines 37-41 and 45-49: vision read with ELSE; differential-update detection with ELSE
- `skills/vision/SKILL.md`, lines 27-31 and 35-39: architecture + VISION.md reads with ELSE branches
- `skills/roadmap/SKILL.md`, lines 27-31 and 41-45: vision read and ROADMAP read with ELSE branches
- `skills/spec/SKILL.md`, lines 33-35 and 37-39: inline single-action form (no ELSE, no THEN DO)
- `skills/research/SKILL.md`, lines 99-101 and 103-105: inline single-action form

The two-gate pattern (per-commit + pre-completion, each with a `require_*` halt path) will require a `THEN DO:` block with more steps than any current instance. ARCHITECTURE.md §Logic-Flow Conventions (lines 316-320) warns that anything with "more than ~3 numbered steps" should use a named subsection in English — the plan should check whether each gate fits within that bound or needs to become a named subsection.

**`resolve()` function assumption:** The current `resolve()` builds `toml_key="${cli_key}_path"` and calls `parse_value` with that TOML key. `require_pre_commit` and `require_pre_completion` are not path keys — their TOML name equals their CLI name (no `_path` suffix). The plan must handle this without changing the `resolve()` contract for existing keys. Options: (a) special-case in `default_for()` + a separate lookup branch in `cmd_get`; (b) treat them as path keys with the documented TOML name `require_pre_commit` (would parse `require_pre_commit_path =` which is wrong); (c) add a `resolve_flag()` sibling to `resolve()`. This is the only non-trivial structural decision in `jimconf.sh`.

**Test framework template** — `tests/jimconf.sh` is the authoritative model. Key conventions:
- `fixture <name>.toml '<content>'` writes a temp TOML file and returns its path
- `empty_dir <label>` creates a temp dir with no `jimconf.toml`
- `run <args...>` captures stdout → `$OUT`, stderr → `$ERR`, exit code → `$RC`
- `assert_eq`, `assert_exit`, `assert_match`, `assert_nonempty` are the four assert helpers
- Each `case_*` function starts with a `# AC: ...` comment mapping to a spec acceptance criterion
- No TESTS=() registration — discovery is by `declare -F | awk '$3 ~ /^case_/'`

## Security & Performance

**Script execution at every commit:** The per-commit gate runs the `pre_commit_path` script before every Red, Green, and Tidy commit — typically 3+ invocations per plan task. A slow `pre_commit_path` script will multiply directly into build time. This is the user's responsibility (the script is theirs), but the skill body should not add delay beyond the Bash call itself.

**`require_*` flag as string boolean:** The spec mandates `"true"` / `"false"` as double-quoted strings. The parser (`parse_value`) returns the inner string verbatim — correct. The skill must compare the resolved string to `"true"` literally. The plan should make the comparison instruction explicit in the skill body to avoid LLM drift (e.g., treating `"1"` or `"yes"` as truthy).

**No new security surface:** The new keys are consumed identically to `pre_commit_path` — resolve the path, gate on existence, run via Bash. The config file is not a shell-execution authority (it stores paths, not shell strings). This is a known-safe pattern per the 008/009 architecture.

## Recommendations

**`resolve()` divergence for `require_*` keys:** The simplest approach is a `resolve_flag()` function in `jimconf.sh` that skips the `_path` suffix and calls `parse_value` with the CLI key name directly, then falls through to `default_for`. The architect should decide whether `resolve()` is extended or whether a parallel function is introduced. The coder needs an explicit call pattern before touching `jimconf.sh`.

**`THEN DO:` block size budget:** Each gate (per-commit and pre-completion) needs at minimum: (1) run the script, (2) show output, and a separate halt branch for the `require_*=true` + absent script case. That's more than ~3 steps total per gate. ARCHITECTURE.md recommends named subsections for blocks beyond that size. The architect should decide whether the gates become named subsections in build/SKILL.md or stay as `THEN DO:` blocks, before the coder touches the skill body.

**Test case count:** Adding three new keys to the full-coverage tests (`case_no_config_returns_defaults`, `case_full_config_returns_overrides`, `case_list_outputs_all_keys`, `case_keys_outputs_valid_keys`, `case_malformed_lines_are_ignored`) requires updating hardcoded counts and key lists in five existing test cases. The plan should list these as explicit edit tasks to avoid the coder missing them.

## Peer Feedback

**For Architect — `resolve()` structural decision needed before coding:** The plan's jimconf.sh task must specify which of the three resolution approaches to use for `require_pre_commit` and `require_pre_completion` (they have no `_path` suffix). The coder cannot safely implement `jimconf.sh` without this decision — an ambiguous task here risks either changing the `resolve()` contract for existing keys or writing unreachable code.

**For Architect — gate block size vs. ARCHITECTURE.md §Logic-Flow Conventions:** Each gate has two branches (script present vs. absent + `require_*` flag). The full two-branch pattern may exceed ARCHITECTURE.md's "~3 numbered steps" guidance for `THEN DO:` blocks. The plan task for rewriting build/SKILL.md step 5 (and the new per-commit gate) should explicitly state whether named subsections are used, so the coder doesn't invent a variant of the BASIC idiom.

**From fork analysis (`docs/notes/fork_drift.md`):** The fork's PR #6 notes that "silent fallback is a footgun — typo a key and configuration is silently ignored." The `require_*` keys are especially risky here: a typo in `require_pre_commit` in the user's TOML silently resolves to `"false"` (the default), meaning enforcement is off without any signal. This is a known limitation of the existing jimconf.sh architecture (spec 008 explicitly chose no strict mode). The spec has accepted this trade-off per its Out of Scope. No action needed, but worth noting for teams relying on `require_*=true` enforcement.
