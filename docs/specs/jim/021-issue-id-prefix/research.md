---
spec: "spec.md"
status: Active
date: "2026-06-13"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Configurable issue-id prefix

## Anchors

### `skills/file/scripts/jimfile.sh`

**`cmd_next_id` — issue branch** (lines 205–215): dispatches on `"issue"` as the first arg, calls `normalize_slug "$subject"` and `today_yyyymmdd`, then composes the id via `printf '%s-%s\n' "$today" "$slug"`. The prefix generation is this single `printf` line; the new scheme must replace it with a resolved prefix from config.

**`cmd_next_num`** (lines 246–268): scans `"$dir"/*.md` grepping `^num:[[:space:]]*[0-9]+`, extracts the integer, and prints `max+1` (or 1). This is a separate CLI call (`jimfile.sh next-num issue`). `cmd_next_id` does not call it — the two are independent today. The `sequential` preset requires the ordinal at id-resolution time; the architect must decide how `cmd_next_id` obtains it (Option A: `cmd_next_id` calls the same scan logic inline; Option B: the skill layer assembles prefix + slug from two calls).

**`normalize_slug` / `is_valid_slug`** (lines 106–147): `normalize_slug` lowercases, collapses non-alnum to `-`, strips leading/trailing dashes, and caps at 64 chars. `is_valid_slug` enforces `^[a-z0-9][a-z0-9-]*$`. These operate on the **slug** only. The new prefix guard (`[A-Za-z0-9._-]`, no leading `.`/`-`, no `..`) must be a separate `is_valid_prefix` function; it cannot reuse `is_valid_slug` (different charset — uppercase and `.` are valid in a prefix). Adding it to `jimfile.sh` keeps all filename-safety guards in the same file and same `LC_ALL=C` preamble (line 58).

**`cmd_path` — issue branch** (lines 317–328): calls `is_valid_slug "$slug"` then composes `"$dir/$slug.md"`. The slug that arrives here is already the full id (prefix included). The `is_valid_slug` call here would reject any id built from the new prefix (`JIM-`, `2026.06.13-`, etc.) because `is_valid_slug` requires lowercase-alnum-and-dash only. The plan must either relax this guard at the `path issue` callsite or introduce a separate `is_valid_id` validator that passes the broader prefix charset while blocking path separators, `..`, and leading `.`/`-`.

**`export LC_ALL=C`** (line 58): preamble sets `LC_ALL=C` so `tr`, `grep`, and `date` behave deterministically regardless of system locale — a security requirement (ARCHITECTURE.md Finding 11). Any `date +<fmt>` call for the `{date:...}` template or `timestamp` preset must run inside this same shell, so it inherits `LC_ALL=C` automatically.

**`today_yyyymmdd`** (lines 127–129): calls `date +%Y%m%d` — the single source of truth for the current date default. The `date` and `timestamp` presets will need analogous helpers or parameterized calls. The strftime format string from config must be passed as a single quoted argument (`date +"$fmt"`) to prevent word-splitting; see Security & Performance below.

### `skills/conf/scripts/jimconf.sh`

**`resolve()`** (lines 104–131): the dispatch arms are:
1. `require_* | auto_* | "issue_capture" | issue_list_*` — bare-name arm, TOML key == CLI key (line 107). The new `issue_id_prefix` and `issue_id_project` keys must be added here as bare-name keys.
2. Everything else — `toml_key="${cli_key}_path"` (line 117). Path-typed keys.

The whitespace-trim + all-whitespace-fallthrough logic (lines 119–128) applies to all arms. A blank `issue_id_prefix = ""` must silently fall through to the `date` default (AC #9) — this is already the behavior of the trim+fallthrough for any bare-name key.

**`KEYS` array** (line 42): the current list has 25 keys. Adding `issue_id_prefix` and `issue_id_project` brings it to 27. Every place that iterates `KEYS` (`cmd_list`, `cmd_keys`, `default_for`) automatically picks up new entries when they are added to this array and to `default_for`. The ARCHITECTURE.md "twenty-five configurable keys" count (line 307) must be updated to "twenty-seven" as part of the architectural doc maintenance.

**`default_for()`** (lines 49–77): `issue_id_prefix` default is `"date"` (the zero-config preset); `issue_id_project` default is `""` (empty — only used with the `project` preset). The whitespace-trim ensures an empty TOML value falls through to the empty-string default for `issue_id_project` and to `"date"` for `issue_id_prefix`.

### `skills/issue/SKILL.md`

**Step 4 — id resolution** (lines 91–113): makes three sequential Bash calls:
1. `jimfile.sh next-id issue "<subject>"` → returns the full id (currently `YYYYMMDD-<slug>`).
2. `jimfile.sh next-num issue` → returns the display ordinal.
3. `jimfile.sh path issue <id>` → returns the file path.

The skill then performs collision detection (append `-2`, `-3` on existing path). This is the composition site. After spec 021, call 1 must return the fully-resolved, scheme-aware id. Call 2 remains separate; the `sequential` preset must obtain the ordinal inside `jimfile.sh next-id issue` if Option A is taken. If Option B (skill-side composition), the skill assembles `<prefix><slug>` from two separate outputs, but this requires the skill prompt to participate in filename construction — conflicting with the External Constraint (AC #10) that resolution stays in bash.

**Validation checklist** (lines 196–208): line 199 hardcodes `"Filename uses the date-prefixed format YYYYMMDD-<slug>.md"`. This check must be generalized (or removed and replaced) when the scheme is configurable — it is the skill-layer documentation that will need updating alongside the bash changes.

**`assets/issue-template.md`** (lines 1–21): the `id:` field value is `{YYYYMMDD}-{slug}`. This is a template placeholder filled by the LLM after step 4 resolves the real id — it does not drive file naming. The shape description (`{YYYYMMDD}-{slug}`) is documentation-only; it must be updated to reflect the configurable scheme, but it does not constrain the implementation.

### `skills/issue/scripts/index.sh`

**`is_valid_slug`** (lines 77–81): mirrors `jimfile.sh` — enforces `^[a-z0-9][a-z0-9-]*$` on the **filename stem**. With new prefix schemes, a filed issue may have a stem like `JIM-wire-consumers` or `0042-wire-consumers`, which this validator would reject, causing the file to be skipped during indexing with a "Skipped: filename is not a valid slug" warning. The plan must extend this validator to accept the broader prefix charset — or introduce a separate id-level validator and use it in the filename acceptance check. Both validators need to stay in sync.

**`parse_scalar_fields`** (lines 113–134): extracts `id`, `num`, `title`, `status`, `priority`, `labels`, `created`, `origin` in a single awk pass. The `id:` field is extracted and stored as-is — no shape assumptions. Confirmed **opaque**: id parsing does not assume `YYYYMMDD-` shape.

### `skills/issue/scripts/render.sh`

**`cmd_show` — resolution tiers** (lines 482–530): resolves `<id>` argument against indexed slugs as: ordinal (numeric match) → exact slug → prefix match → substring match. The prefix-match tier at line 508–510 iterates `"${slugs[$i]}" == "$id"*`. With a shared static prefix (e.g., every issue is `JIM-*`), any `show JIM` call hits every issue in the collection. Security finding 4 in security.md identifies this as a usability regression — multiple matches degrade predictably (the script already reports "Multiple issues match … Re-run with a more specific id" at lines 522–527). This behavior is already correct for degradation; no code change is needed for the multi-match case, only plan-level documentation that it is the expected degradation path.

**`is_valid_slug`** (lines 453–457): same `^[a-z0-9][a-z0-9-]*$` guard used in `render_issue_file` before composing `"$dir/$slug.md"`. Same extension requirement as `index.sh`.

## Local Patterns

**Bare-name key addition pattern** (`jimconf.sh:107`): to add `issue_id_prefix` and `issue_id_project` as bare-name keys, extend the `if` condition in `resolve()` and add cases to `default_for()`. Mirror the `issue_list_*` arm — one new `|| "$cli_key" == "issue_id_prefix" || "$cli_key" == "issue_id_project"` clause, plus entries in `KEYS` and `default_for`.

**Existing test template**: `tests/jimfile.sh` is the TDD template for `jimfile.sh` additions. It sources `testlib.sh` via BASH_SOURCE-relative path (line 18), defines `run_jimfile()` to capture stdout/stderr/rc (lines 27–32), and names cases `case_jimfile_<scenario>()`. New prefix cases follow this exact shape. `tests/jimconf.sh` is the template for `jimconf.sh` additions; each new key gets at minimum a `_default` case and an `_overridden` case (see the `issue_list_closed` cases at the end of `tests/jimconf.sh` for the most recently added pattern). Both files use `fixture` and `empty_dir` helpers from `testlib.sh` for isolation; fixtures get unique names to avoid cross-test collision.

**Collision discriminator**: the existing `-2`, `-3` discriminator logic for debug/brainstorm paths (jimfile.sh lines 345–360) is skill-side in `SKILL.md` step 4, not in `jimfile.sh` itself. The same pattern will apply to issue collision resolution.

**Aggregate test runner**: `bash skills/meta-test/scripts/run.sh` — discovers and runs all `tests/*.sh` automatically; per-file filter via `bash tests/jimfile.sh <substring>`.

## Security & Performance

**Finding 3 (security.md) — strftime injection via `date`**: the `{date:<fmt>}` token feeds a developer-supplied format string to `date`. The plan must specify: (a) the format string is passed as a single quoted argument (`date +"$fmt"`, never concatenated or evaled), (b) `LC_ALL=C` is already active in `jimfile.sh` preamble so output is deterministic, (c) a `date` exit code != 0 routes to the AC #8 malformed-config notice rather than propagating `date`'s error text into the id. Pattern: capture in a subshell, check exit code, fall through on failure.

**Finding 4 (security.md) — shared-prefix substring ambiguity in `show`**: confirmed that `render.sh cmd_show` already emits a multi-match list and prompts for a more specific id (lines 522–527). No code change needed; the plan should document this as the accepted degradation path for shared-prefix schemes.

**Prefix allowlist guard location**: the new `is_valid_prefix` function belongs in `jimfile.sh` alongside `is_valid_slug`, guarded by `LC_ALL=C`. It must cover all three input paths: preset expansion, `issue_id_project` literal, and `{date:...}`/template expansion output. The guard runs on the resolved prefix, not the raw config string.

**Length bound (AC #11)**: the plan must specify the concrete limit. The slug is capped at 64 chars; a prefix cap of ~64 chars would ensure `prefix + "-" + slug` stays under 130 chars, well within the 255-byte filesystem limit. An over-length resolved prefix routes to the AC #8 notice and falls back to `date`.

**`is_valid_slug` in `cmd_path issue`** (jimfile.sh line 323) and in `index.sh` (line 81): both must be updated or replaced with a broader `is_valid_id` check to avoid false rejections of ids built with the new prefix. These are separate call sites that must be updated in sync.

## Recommendations

These are options for the architect — not decisions.

1. **Ordinal access for `sequential` preset**: Option A (preferred by spec insight 2) is for `cmd_next_id issue` to call the same ordinal-scanning logic `cmd_next_num` uses inline, returning a fully-assembled id in one call. This keeps the security boundary (prefix guard + slug guard) in one bash function. Option B (skill-side assembly from two calls) requires the skill prompt to participate in filename construction, which violates AC #10.

2. **`{date:<fmt>}` format string validation**: two sub-options: (a) validate the format string against a bounded allowlist of strftime tokens before calling `date` (safe but complex); (b) run `date +"$fmt"` in a subshell, check exit 0 and that output passes the prefix allowlist, treat failure as malformed config. Option (b) matches the existing bash-only dependency constraint and is simpler to implement correctly.

3. **`is_valid_slug` callsites**: the `cmd_path issue` guard in `jimfile.sh` and the filename acceptance check in `index.sh` both need updating. Options: (a) replace both with `is_valid_id` (broader `[A-Za-z0-9._-]`, no leading `.`/`-`, no `..`, cap at ~128 chars); (b) keep `is_valid_slug` for the slug segment and add a separate pre-composition prefix guard. Option (a) is simpler and covers mixed-scheme collections; it must be applied consistently to both callsites.

4. **ARCHITECTURE.md maintenance**: the "twenty-five configurable keys" phrase appears at ARCHITECTURE.md line 307 and must be updated to "twenty-seven" when `issue_id_prefix` and `issue_id_project` are added. The `next-id issue` description in line 308 must also be updated to describe the configurable scheme.

## Peer Feedback

**For the Architect — `cmd_path issue` uses `is_valid_slug` today; this will reject new-scheme ids**: `jimfile.sh` line 323 calls `is_valid_slug "$slug"` where `$slug` is the full id (prefix + slug). After spec 021, ids like `JIM-wire-consumers` or `0042-wire-consumers` will fail this check with exit code 1 and a stderr message. The plan must explicitly address this callsite — it is not covered by the spec's focus on `next-id`, but it is in the direct issue-filing path (`path issue <id>`).

**For the Architect — `index.sh` will warn-skip new-scheme issue files**: `index.sh` line 303 calls `is_valid_slug "$(basename "$f" .md)"` and adds a skip warning for any file whose stem fails. Existing issues with `YYYYMMDD-` prefix pass because digits and dashes are in `[a-z0-9-]`. A filed `JIM-wire-consumers.md` or `0042-wire-consumers.md` would be skipped and appear as an integrity warning rather than being indexed. This is a silent regression unless the validator is updated in the same change.

**For the Architect — `issue_list_closed` is in `jimconf.sh` KEYS but not in `jimconf.toml.example`**: observed during investigation. Unrelated to spec 021 but worth noting — `jimconf.toml.example` ends at `issue_list_order` and is missing the `issue_list_closed` entry that appears in `KEYS` (line 42) and `default_for()` (line 74). This should be addressed in a separate cleanup commit.
