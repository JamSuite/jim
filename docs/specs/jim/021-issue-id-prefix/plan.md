---
title: "Configurable issue-id prefix"
spec: "docs/specs/jim/021-issue-id-prefix/spec.md"
type: feature
status: complete
---

# Configurable issue-id prefix — Plan

## Overview
Resolve the issue-id prefix in one deterministic `jimfile.sh` function (`resolve_issue_prefix`) that maps presets and a `{…}`-template escape hatch onto a single renderer, guards the result with a broad-but-bounded `is_valid_id` allowlist, and widens every downstream full-id validator (`cmd_path`, `index.sh`, `render.sh`) so mixed-scheme collections keep working.

## Design Decisions

### 1. Prefix resolution lives in `jimfile.sh` (one function), not the skill layer
- **Chosen:** A new `resolve_issue_prefix` function in `skills/file/scripts/jimfile.sh`; `cmd_next_id issue` calls it for the prefix, then composes `printf '%s-%s' "$prefix" "$slug"`.
- **Why:** AC #10 (External Constraint) requires resolution in deterministic bash, not LLM-composed; keeping it in `jimfile.sh` co-locates it with the slug security boundary and the `LC_ALL=C` preamble.
- **Rejected:** Skill-side assembly from separate `next-id` + `next-num` outputs — would make the skill prompt participate in filename construction, violating AC #10 (research.md Peer Feedback / Recommendation 1).

### 2. Presets are named templates over one renderer
- **Chosen:** `resolve_issue_prefix` dispatches: (a) blank → `date` (jimconf already defaults it); (b) exact known preset → its canonical form (`date`→`{date:%Y%m%d}`, `timestamp`→`{date:%Y%m%dT%H%M%S}`, `sequential`→`{seq:04}`, `project`→the `issue_id_project` literal); (c) value containing `{` → treated as a template; (d) any other bare word → **unknown preset** → malformed (Decision 5). All non-literal forms flow through a single `render_template` helper.
- **Why:** Collapses presets + escape hatch into one code path (AC #2/#3); the `{`-vs-bare-word split lets a typo'd preset (`sequental`) be caught as malformed (AC #8) instead of silently becoming a static prefix.
- **Rejected:** Separate per-preset code branches — more surface, and a bare-word fallthrough that silently treats `sequental` as a literal prefix would defeat AC #8's "unknown preset name" case.

### 3. Sequential prefix projects the existing ordinal (`num`), via a shared helper
- **Chosen:** Extract the `num:`-scan in `cmd_next_num` into `issue_next_num <dir>`; both `cmd_next_num` and the `{seq}` token call it. The `sequential` preset renders `{seq:04}` → the zero-padded ordinal.
- **Why:** AC #4 / spec Option A — the id's number *is* the display ordinal (`#42` ↔ `0042-slug`), not a second counter. One scan, one source of truth.
- **Rejected:** An independent prefix counter — spec rejected it (silent divergence from `num`).

### 4. One broad `is_valid_id`; keep `is_valid_slug` for the slug segment
- **Chosen:** Add `is_valid_id` — `^[A-Za-z0-9][A-Za-z0-9._-]*$`, no `..` substring, length ≤ 128 — as the validator for the **resolved prefix** and for **full ids** at every consumer callsite (`jimfile.sh cmd_path`, `index.sh` ×3, `render.sh`). `is_valid_slug` (`^[a-z0-9][a-z0-9-]*$`) stays as the slug-segment guard and gains a defensive call on the normalized slug inside `cmd_next_id issue`. The three `is_valid_id` copies are hand-synced (jim's self-contained-script convention); a `tests/` consistency check (task 13) asserts they stay byte-identical so drift fails CI rather than review (security.md Finding 5).
- **Why:** AC #7 deliberately broadens the id charset beyond the slug allowlist (uppercase `JIM`, dotted dates, `T`) while staying a positive allowlist (no leading `.`/`-`, no traversal); the slug invariant is still wanted for the slug part. The defensive call gives `is_valid_slug` a live caller (no dead code) and hardens slug generation.
- **Rejected:** Relaxing `is_valid_slug` itself — would weaken the strict slug invariant the rest of jim relies on. A separate `is_valid_prefix` + `is_valid_id` pair — redundant; one charset covers both.

### 5. Malformed config informs via stderr and falls back to `date`; blank is silent
- **Chosen:** When the resolved prefix fails `is_valid_id`, exceeds the length cap, a `{date:…}` render exits non-zero, or `project` has an empty `issue_id_project`, `resolve_issue_prefix` writes a **one-line notice to stderr** and returns the `date` default. A blank/absent `issue_id_prefix` resolves to `date` upstream (jimconf) and emits **no** notice. `cmd_next_id`'s stderr surfaces through `skills/issue/SKILL.md` step 4 to the developer.
- **Why:** AC #8 (inform on malformed, never silently apply a wrong scheme) vs. AC #9 (absent/blank is zero-config, silent). stderr is the natural carrier; filing still succeeds.
- **Rejected:** Refusing to file on malformed config — harsher than the spec's graceful-fallback intent. Silent fallback for malformed — AC #8 forbids it.

### 6. strftime format passed as a single quoted `date` argument, exit-checked
- **Chosen:** `{date:FMT}` renders via `out=$(date +"$FMT") || fail`; the format is never concatenated/`eval`'d, runs under the inherited `LC_ALL=C`, and a non-zero exit (or output failing `is_valid_id`) routes to the Decision-5 notice path.
- **Why:** security.md Finding 3 + AC #9/#10 — keep the developer-supplied format as data, not code.
- **Rejected:** Pre-validating the format against a strftime-token allowlist — more complex than capturing `date`'s own exit code and validating its output (research Recommendation 2b).

## Constitution Check

**ARCHITECTURE.md status:** Present — constraints noted below.

| Constraint from ARCHITECTURE.md | Honored? | Notes |
| :--- | :--- | :--- |
| Bash + POSIX only; no third-party deps | Yes | `render_template` uses bash string ops, `sed`, `date` only. |
| Never `source`/`eval` user-supplied data | Yes | Template parsed with bash/`sed`; `date` format passed as a quoted arg (Decision 6). |
| `set -uo pipefail`; `export LC_ALL=C` | Yes | New functions live in existing scripts and inherit the preamble. |
| Inter-script composition via `BASH_SOURCE` | Yes | Unchanged; `jimfile.sh`→`jimconf.sh` path already established. |
| Slug pipeline is the security boundary; never delegate to the LLM | Yes | Resolution + `is_valid_id` live in `jimfile.sh` bash (AC #10). |
| `allowed-tools` mirrors call sites | Yes | No new bash call shape added to any SKILL.md; `jimfile.sh`/`index.sh` already permitted in `skills/issue` frontmatter. |
| jimconf key conventions (bare-name vs `_path`) | Yes | `issue_id_prefix` / `issue_id_project` added as bare-name keys (Decision per research). |

## File Manifest

| Component | File Path | Action | Notes |
| :--- | :--- | :--- | :--- |
| Config keys | `skills/conf/scripts/jimconf.sh` | Update | `KEYS` += 2; `resolve()` bare-name arm; `default_for()` (`date` / empty). |
| Prefix resolver | `skills/file/scripts/jimfile.sh` | Update | `is_valid_id`, `render_template`, `issue_next_num`, `resolve_issue_prefix`; wire `cmd_next_id issue`; `cmd_path issue` → `is_valid_id`; defensive `is_valid_slug` call. |
| Indexer | `skills/issue/scripts/index.sh` | Update | Broaden the 3 `is_valid_slug` id-callsites (stem L303, relation target L353, wikilink L373) to `is_valid_id`. |
| Renderer | `skills/issue/scripts/render.sh` | Update | `render_issue_file` guard (L453/L462) → `is_valid_id`. |
| Issue skill | `skills/issue/SKILL.md` | Update | Step 4: surface `next-id` stderr notice; validation checklist L199 generalize. |
| Issue template | `skills/issue/assets/issue-template.md` | Update | `id:` placeholder/comment reflects configurable scheme (doc-only). |
| Example config | `jimconf.toml.example` | Update | Document `issue_id_prefix` / `issue_id_project`; backfill missing `issue_list_closed`. |
| Architecture doc | `ARCHITECTURE.md` | Update | "twenty-five"→"twenty-seven" keys; enumerate new keys; update `next-id issue` description. |
| jimfile tests | `tests/jimfile.sh` | Update | Preset / template / fallback / `path issue` cases; `is_valid_id` triplicate-identity case. |
| jimconf tests | `tests/jimconf.sh` | Update | `_default` + `_overridden` cases for both new keys. |
| issue-script tests | `tests/issues.sh` | Update | Index + show acceptance of new-scheme ids. |

## Interface Contracts

```bash
# --- skills/file/scripts/jimfile.sh (new/changed functions) ---

# is_valid_id <id>
#   rc 0 iff <id> matches ^[A-Za-z0-9][A-Za-z0-9._-]*$, contains no ".." run,
#   and length <= 128. Else rc 1 + stderr. Broad-but-bounded allowlist for the
#   resolved prefix AND full ids (AC #7, AC #11). Mirrored verbatim in index.sh
#   and render.sh — keep the three copies in sync.
is_valid_id() { ... }

# issue_next_num <issues_dir>
#   Print max(num:) + 1 across <issues_dir>/*.md, or 1. Extracted from
#   cmd_next_num; called by both cmd_next_num and the {seq} token (AC #4).
issue_next_num() { ... }

# render_template <template> <ordinal>
#   Expand a prefix template to stdout:
#     {date:FMT} -> date +"FMT"   (quoted single arg; rc 1 on date failure)
#     {seq} | {seq:W} -> <ordinal> zero-padded to width W (default from preset)
#     literal text -> passthrough
#   rc 1 if any {date:…} render fails. Does NOT validate charset (caller does).
render_template() { ... }

# resolve_issue_prefix
#   Read issue_id_prefix (+ issue_id_project) via jimconf; dispatch per
#   Decision 2; render via render_template; validate via is_valid_id + length.
#   On success: print resolved prefix (stdout).
#   On malformed (bad preset/template, date failure, charset/length, empty
#   project): one-line notice to stderr + print the `date` default (AC #8).
#   Blank/absent config -> `date`, no notice (AC #9).
resolve_issue_prefix() { ... }

# cmd_next_id issue branch:
#   slug=$(normalize_slug "$subject") || return 1
#   is_valid_slug "$slug" || return 1            # defensive (Decision 4)
#   prefix=$(resolve_issue_prefix)               # stderr notice flows to caller
#   printf '%s-%s\n' "$prefix" "$slug"

# cmd_path issue branch:  is_valid_id "$slug"  (was is_valid_slug)
```

```toml
# --- jimconf.sh keys (defaults) ---
issue_id_prefix  = "date"   # date | sequential | project | timestamp | <template>
issue_id_project = ""        # static tag used only by the `project` preset
```

## Data Flow

```mermaid
flowchart TD
    Cfg["jimconf: issue_id_prefix\n(+ issue_id_project)"] --> Disp{dispatch}
    Disp -->|blank / 'date'| Tdate["{date:%Y%m%d}"]
    Disp -->|preset| Tpre["canonical template\n(timestamp/sequential/project)"]
    Disp -->|contains '{'| Ttpl["template string"]
    Disp -->|bare word, not preset| Bad
    Ord["issue_next_num"] --> Render["render_template"]
    Tdate --> Render
    Tpre --> Render
    Ttpl --> Render
    Render -->|date rc!=0| Bad["malformed:\nstderr notice + date default"]
    Render --> Guard{"is_valid_id\n+ length <= 128"}
    Guard -->|pass| Pre["resolved prefix"]
    Guard -->|fail| Bad
    Bad --> Pre
    Pre --> Id["id = prefix + '-' + slug"]
    Id --> Path["cmd_path issue (is_valid_id)"]
    Id --> Idx["index.sh / render.sh (is_valid_id)"]
```

## Task Breakdown

1. [x] **jimconf keys.** Add `issue_id_prefix` (default `date`) and `issue_id_project` (default ``) to `jimconf.sh` `KEYS`, the `resolve()` bare-name arm condition, and `default_for()`. Add `_default` + `_overridden` cases for both in `tests/jimconf.sh` (mirror the `issue_list_*` pattern).
   **Verify:** `bash tests/jimconf.sh issue_id`

2. [x] **Ordinal helper.** Refactor the `num:`-scan out of `cmd_next_num` into `issue_next_num <dir>`; `cmd_next_num` becomes a thin wrapper. No behavior change.
   **Verify:** `bash tests/jimfile.sh next_num`

3. [x] **Preset resolution.** Add `is_valid_id`, `render_template`, `resolve_issue_prefix` (presets `date`/`timestamp`/`sequential`/`project` only, per Decisions 2–4), wire `cmd_next_id issue` to it, and add the defensive `is_valid_slug` call. Default (no config) stays byte-identical. Cases: default == `YYYYMMDD-slug` (AC #1), `sequential` == zero-padded ordinal (AC #3a/#4), `project` tag (AC #3b), `timestamp` sub-day (AC #3c). *Depends on tasks 1, 2.*
   **Verify:** `bash tests/jimfile.sh next_id_issue_preset`

4. [x] **Template escape hatch.** Extend `resolve_issue_prefix` so a value containing `{` routes to `render_template` (Decision 2c): custom date format (AC #3d) and a combined `JIM-{date:%Y%m%d}-{seq:03}` template. *Depends on task 3.*
   **Verify:** `bash tests/jimfile.sh next_id_issue_template`

5. [x] **Malformed/fallback.** In `resolve_issue_prefix`, route out-of-allowlist results, over-length (AC #11), `{date:…}` failures, empty-`project`, and unknown bare-word presets to a one-line **stderr** notice + `date` fallback (AC #8); confirm blank config → `date` with empty stderr (AC #9). *Depends on task 3.*
   **Verify:** `bash tests/jimfile.sh next_id_issue_fallback`

6. [x] **Path guard.** In `cmd_path issue`, replace `is_valid_slug "$slug"` with `is_valid_id "$slug"` (the arg is the full id). Cases: `path issue JIM-wire-consumers` → rc 0 + path; `../escape`, `-flag`, `a..b` → rc 1. *Depends on task 3 (is_valid_id).*
   **Verify:** `bash tests/jimfile.sh path_issue`

7. [x] **Indexer guard.** In `index.sh`, broaden the three id-validating `is_valid_slug` callsites (filename stem L303, relation target L353, wikilink L373) to an `is_valid_id` copy matching jimfile.sh (with a "keep in sync" comment). Cases: a `JIM-foo.md` issue is indexed (not skip-warned); a relation/wikilink to a new-scheme id becomes an edge. *Depends on task 3 (charset contract).*
   **Verify:** `bash tests/issues.sh index`

8. [x] **Renderer guard.** In `render.sh`, broaden the `render_issue_file` guard (L453/L462) to the `is_valid_id` copy. Case: `show` on a new-scheme id renders the file. *Depends on task 3.*
   **Verify:** `bash tests/issues.sh show`

9. [x] **Issue skill.** In `skills/issue/SKILL.md`: (a) step 4 — instruct surfacing any stderr notice from `next-id issue` to the developer (AC #8); (b) confirm the collision discriminator note is scheme-agnostic (AC #6); (c) generalize validation-checklist L199 from the hardcoded `YYYYMMDD-<slug>.md` to "the configured prefix scheme (default `YYYYMMDD-<slug>.md`)".
   **Verify:** `grep -q 'configured prefix scheme' skills/issue/SKILL.md && grep -q 'stderr' skills/issue/SKILL.md && echo OK`

10. [x] **Issue template doc.** Update the `id:` placeholder/comment in `skills/issue/assets/issue-template.md` to reflect the configurable scheme (doc-only; does not drive naming).
    **Verify:** `grep -q 'scheme' skills/issue/assets/issue-template.md && echo OK`

11. [x] **Example config.** Add a commented `issue_id_prefix` / `issue_id_project` block to `jimconf.toml.example` documenting the presets + template.
    **Verify:** `grep -q issue_id_prefix jimconf.toml.example && grep -q issue_id_project jimconf.toml.example && bash skills/conf/scripts/jimconf.sh -c jimconf.toml.example get issue_id_prefix | grep -qx date && echo OK`

12. [x] **Architecture doc.** In `ARCHITECTURE.md`: "twenty-five configurable keys" → "twenty-seven", add `issue_id_prefix` / `issue_id_project` to the key enumeration, and update the `next-id issue` description to note the configurable scheme.
    **Verify:** `grep -q 'twenty-seven' ARCHITECTURE.md && grep -q issue_id_prefix ARCHITECTURE.md && echo OK`

13. [x] **Validator consistency.** Add a `tests/jimfile.sh` case that extracts the `is_valid_id` function body from `skills/file/scripts/jimfile.sh`, `skills/issue/scripts/index.sh`, and `skills/issue/scripts/render.sh` and asserts all three are byte-identical, so drift between the hand-synced copies fails CI (security.md Finding 5). *Depends on tasks 3, 7, 8.*
    **Verify:** `bash tests/jimfile.sh is_valid_id_triplicate`

14. [x] **Backfill `issue_list_closed` example.** Add the missing `issue_list_closed` documentation entry to `jimconf.toml.example` (it is in `jimconf.sh` `KEYS`/`default_for` but absent from the example). Pre-existing gap, folded in per developer request.
    **Verify:** `grep -q issue_list_closed jimconf.toml.example && echo OK`

15. [x] **Full suite.** Run the aggregate test runner; all `tests/*.sh` green.
    **Verify:** `bash skills/meta-test/scripts/run.sh`

## Requirements Coverage Summary

| Spec Acceptance Criterion | Addressed In Task(s) |
| :--- | :--- |
| AC #1 — default unchanged (`YYYYMMDD-slug`, zero-config) | 3 |
| AC #2 — presets + template selectable in jimconf.toml | 1, 3, 4 |
| AC #3 — four shapes (sequential / project / timestamp / alt date) | 3 (a–c), 4 (d) |
| AC #4 — sequential prefix = `num` projected; `num` persists | 2, 3 |
| AC #5 — forward-only; mixed-scheme collection functional | 6, 7, 8 (consumers); forward-only by construction (no migration code) |
| AC #6 — collision discriminator still applies | 9 (existing skill-side `-2/-3`, confirmed scheme-agnostic) |
| AC #7 — bounded allowlist; can't escape / be parsed as a flag | 3, 5, 6, 7, 8, 13 |
| AC #8 — present-but-malformed informs, never silently applied | 5, 9 |
| AC #9 — missing/empty/whitespace → silent `date` default | 1, 3, 5 |
| AC #10 — resolved in deterministic bash, not the LLM | 3 (whole design); Constitution Check |
| AC #11 — resolved prefix length-bounded | 3, 5 |

## Out of Scope

- **Migration / re-deriving existing ids** to a new scheme — forward-only; tracked as issue `#7` (`20260613-re-derive-existing-issue-ids-to-active-prefix-scheme`).
- **Configurable sequential zero-pad width** and template tokens beyond `{date}` / `{seq}` — future; `sequential` is fixed at width 4 (`%04d`) here.
- **Changing `num` semantics or the slug pipeline** — `num` stays the decentralized display ordinal; the slug guard is unchanged.
- **A `/jim:conf` write surface** — config is edited directly, per existing convention.

## Open Questions

- [x] ~~Ordinal access for `sequential`~~ → shared `issue_next_num` helper (Decision 3).
- [x] ~~Preset typo vs. literal static prefix~~ → `{`-vs-bare-word dispatch; bare non-preset word is a malformed unknown preset (Decision 2).
- [x] ~~strftime safety~~ → quoted single-arg `date`, exit-checked, output re-validated (Decision 6).
- [x] ~~`is_valid_slug` callsites that reject new-scheme ids~~ → widened to `is_valid_id` at all full-id callsites (Decision 4; tasks 6–8).

None blocking — all design decisions resolved during planning.
