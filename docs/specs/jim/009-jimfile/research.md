---
spec: "docs/specs/jim/009-jimfile/spec.md"
status: Active
date: "2026-05-04"
---

# Research: File and path utilities for jim's skills and agents

## Anchors

**Precedent — `/jim:conf` (007), the implementation template:**

- `skills/conf/scripts/jimconf.sh:1-211` — single script, six-section discipline (header → constants → parsing → handlers → dispatch → impl-notes). `set -uo pipefail`. Pure `grep | head | sed`; never `source`.
- `skills/conf/SKILL.md:1-33` — user-facing wrapper. No `agent:`, body is one `!`-injection of `${CLAUDE_SKILL_DIR}/scripts/jimconf.sh $ARGUMENTS`.
- `tests/run.sh:1-376` — plain-bash runner; section banners, per-case `# AC:` comment, heredoc fixtures, `mktemp` sandbox, `$1` filter.

**Existing consumer files (where new `!`-injection calls land):**

- `skills/spec/SKILL.md:44, 116, 128` — specs glob, ID assignment, write path. Prose: *"Glob `…/{group}/*/` to find IDs. Pick max+1, zero-pad to 3 digits."*
- `skills/debug/SKILL.md:35, 49, 52, 62, 67` — debug filename `{YYYYMMDD}-{topic}.md`; topic = *"2-4 word kebab-case."*
- `skills/brainstorm/SKILL.md:32` — brainstorm filename; slug = *"lowercase, hyphens, no spaces."*
- `skills/research/SKILL.md:39, 54-56` — standalone research path; greenfield Glob/Grep audit-trail prose.
- `skills/plan/SKILL.md:41, 58-63, 97` — research-existence check, plan-existence check, plan write path.
- `skills/{vision,roadmap,arch}/SKILL.md` — strategic-doc existence prose ("if exists" / "Check for existing").
- `skills/{meta-skill,meta-agent}/SKILL.md:22` — specs glob (already migrated to jimconf.sh).
- `agents/{pm,architect,researcher,coder,meta}.md` — context-only path docs; no I/O.

**New files (paths are architect's call):** resolver script (e.g., `skills/file/scripts/jimfile.sh`), user-facing `skills/file/SKILL.md`, new test cases appended to `tests/run.sh`.

## Local Patterns

- **Script discipline (mandatory).** Mirror `jimconf.sh`: file header docblock, named section banners, per-helper docblocks, `main "$@"` dispatch, impl-notes at file end, no `set -e`, no `source`/`eval` of user data.
- **Test runner discipline (mandatory).** Mirror `tests/run.sh`: `# AC:` per case, inline heredoc fixtures, `mktemp` sandbox, no shared FS state, `$1` filter, PASS/FAIL reporter.
- **Skill consumption pattern.** Consumer skills declare `allowed-tools: Bash(bash *)` and call `` !`bash ${CLAUDE_PLUGIN_ROOT}/skills/conf/scripts/jimconf.sh get <key>` ``. Output replaces the placeholder before the LLM reads. The user-facing skill itself uses `${CLAUDE_SKILL_DIR}` for its own bundled script.
- **Slug normalization is prose, with two slightly different specs.** `brainstorm` says *"lowercase, hyphens, no spaces."* `debug` says *"2-4 word kebab-case."* No collapse-runs, no trim, no path-traversal rejection. This is the inconsistency drift the spec calls out.
- **Spec ID prose is uniform** across `spec/SKILL.md:116` and three agent context paragraphs: "max + 1, zero-padded to 3 digits, start at 001 if empty."
- **`${CLAUDE_PLUGIN_ROOT}` vs `${CLAUDE_SKILL_DIR}`** (per `code.claude.com/docs/en/plugins-reference#environment-variables`): PLUGIN_ROOT is plugin-wide, SKILL_DIR is per-skill. Both substitute at content-render time, before bash runs. **Co-location does not affect cross-skill invocation.**

## Prior Art

### Tier 1 — Study Closely

- **`docs/prior-art/20260504-research-plugin-interoperability.md`** — comprehensive matrix of nine coding agents and a "2026 Portability Recipe." Load-bearing claims for this spec:
  - The `skills/` folder travels everywhere; `plugin.json` and `agents/*.md` do not (§Executive Summary).
  - Cross-agent path convention is `.agents/skills/` (project) and `~/.agents/skills/` (user); symlink covers most targets in one move (§4 Recipe step 2).
  - **Sandboxed IDEs run bash without a TTY.** Interactive `read`, `isatty()`, color escapes break. Test under `bash -c '<script>' < /dev/null` (§4 step 6).
  - **YAML frontmatter must be the very first content of a SKILL.md** — Gemini silently skips files with leading H1s (§4 step 9).
  - `agents/*.md` is the only part that doesn't travel; SKILL.md itself rarely needs changes between targets.

- **`docs/specs/jim/007-jimconf/research.md`** — primary local prior art. Establishes the script-as-deterministic-resolver pattern, `${CLAUDE_PLUGIN_ROOT}` substitution, no-`source` security model, and test-runner conventions. **The new utility is a direct sibling.**

| File | What It Is | Why It Matters |
|------|-----------|---------------|
| `skills/conf/scripts/jimconf.sh` | Reference script | Shape, discipline, parse strategy, exit-code semantics |
| `skills/conf/SKILL.md` | Reference user-facing skill | Wrapper shape; `${CLAUDE_SKILL_DIR}` usage |
| `tests/run.sh` | Reference test runner | Conventions for new test cases |
| `docs/prior-art/20260504-research-plugin-interoperability.md` | Cross-agent baseline | Portability constraints to honor in v1 |

### Tier 2 — Specific Patterns

- **Anthropic `plugin-settings` skill** (007 research) — bash YAML-frontmatter parse via `sed -n '/^---$/,/^---$/{ /^---$/d; p; }'`. Relevant if v2 needs frontmatter reads (e.g., spec-status filtering). Not v1.
- **Anthropic `skills` repo** — 84% Python / 1.9% Shell. Confirms executable code in skills is normalized; bash is a minority-but-legitimate choice.

### Tier 3 — Reference Only

- **stoml** (shell TOML parser) and **bats-core** — both avoidable; zero third-party deps remains the rule per 007.

## Libraries

None. Bash + POSIX (`grep`, `sed`, `cut`, `tr`, `printf`, `date`, `find`, `sort`, `head`). Confirmed against `jimconf.sh` and `tests/run.sh`. No library-sprawl risk.

## Security & Performance

- **Slug-injection is the load-bearing security concern.** Free-form topics flow into filenames. The slug normalizer must reject `..`, `/`, leading `-`, control chars, and empty results — at the **script** layer, not delegated to the LLM. Today's prose addresses none of this. The most likely real-world exploit if missed: `/jim:debug ../../../../etc/passwd` writing outside the configured debug directory.
- **No-TTY constraint** (cross-agent interop §4 step 6). No `read -p`, no `isatty`, no terminal colors. `jimconf.sh` already follows this.
- **`!`-injection re-runs.** Each call invokes the script. At human-typing scale, irrelevant. A skill body composing 3-4 calls runs in <100ms total. No caching needed (007's finding holds).
- **Filesystem-state guarantees.** Read-only — `find`/`stat` only, never `mkdir`/`mv`/`rm`. Calling skills retain responsibility for creating directories before writing.
- **`allowed-tools` enforcement is documented but buggy** (007's research; Anthropic issues #14956, #18837, #37683). Treat `Bash(bash *)` as documentation, not security. Not new exposure.

## Recommendations

Decisions belong to the architect; this section frames trade-offs.

### Operation surface — three groupings

- **(A) Verb-first** — `exists <path>`, `next-id <group>`, `dated-name <kind> <topic>`, `path <kind> [args]`, `glob <kind> [filter]`, `slug <topic>`. Sibling style to `jimconf.sh`.
- **(B) Noun-first by kind** — `spec next-id <group>`, `debug path <topic>`, etc. More readable; ~3× the test surface.
- **(C) Flat single-purpose** — `jimfile-spec-next-id`, etc. Rejected as YAGNI.

**Read:** (A) is the natural sibling; (B) defensible if architect prefers readability over surface size.

### Composition with `/jim:conf`

- **(a) Pass resolved paths as arguments.** Two `!`-injections per call site. Zero coupling; noisier; multiplies `!`-injection count.
- **(b) `jimfile.sh` shells out to `jimconf.sh`.** Clean call sites; runtime dependency; tests need both scripts.
- **(c) `jimfile.sh` parses `jimconf.toml` directly.** Standalone; duplicates parse logic.

**Read:** (b) is cleanest co-located. (a) is most cross-agent-portable (PLUGIN_ROOT doesn't apply in `.agents/skills/`). (c) is duplication.

### Co-location

- **`skills/conf/scripts/jimfile.sh`** (co-located): minimal ARCHITECTURE.md churn; `/jim:file` skill body uses `${CLAUDE_SKILL_DIR}/../conf/scripts/jimfile.sh` (works, layout-coupled).
- **`skills/file/scripts/jimfile.sh`** (independent): clean; small additive ARCHITECTURE.md update.
- **`skills/_scripts/`**: rejected — out of step with convention.

**Read:** `skills/file/` is the cleaner long-term shape.

### Edge-case rules

- **Slug normalization.** Suggested pipeline: `tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/-/g; s/-\+/-/g; s/^-//;s/-$//'`. Reject empty, `.`, `..`; length cap ~64 chars. **Script must enforce — security boundary, see Peer Feedback.**
- **Slug collisions same date.** Append `-2`, `-3`, … recommended over silent overwrite or hard reject.
- **Missing target directory.** Return the path; calling skill creates the dir (already today's prose).
- **Spec ID gaps.** Simple "max + 1" — already in spec Out of Scope.

### "Most recent X" helper

Defer to follow-on spec. Needs additional framing (mtime? filename date? frontmatter field?). Scope creep risk.

### Migration strategy

Bundled PR sequence (007 pattern) — but consider phasing: date-prefix consumers (debug, brainstorm, research) → ID/glob consumers (spec, plan, meta-skill, meta-agent) → existence-check consumers. 19 candidate files; phasing lowers per-PR regression risk.

### Test runner

Extend `tests/run.sh` with `case_jimfile_*` prefix so `bash tests/run.sh jimfile` selects them via the existing filter. Reject a parallel runner.

### ARCHITECTURE.md update

`skills/file/`: one-line tree addition + one-paragraph Scripting Layer extension. Co-located: single sentence. Either smaller than 007's update.

### Cross-agent portability hygiene (constraint, not feature)

Non-interactive bash (`bash -c '...' < /dev/null`); no PLUGIN_ROOT inside script body (call sites substitute); SKILL.md leads with YAML frontmatter; no `agent:` binding; skill survives copy to `.agents/skills/` unchanged.

## Alignment

- **VISION.md.** Reduces drift, lowers token cost, tightens institutional memory (one tested codepath replaces 41 prose patterns). Honors "Not a black box" — `/jim:file` is a slash command, fully introspectable. Cross-agent hygiene aligns with Phase 3 trajectory without claiming to deliver it.
- **ARCHITECTURE.md.** All constraints honored. Skills directory pattern preserved. Test conventions preserved. No-write-to-protected-paths preserved. Scripting Layer subsection (added by 007) extends naturally.

No locked constraints violated. No `plan.md` exists yet for 009 (no plan-invalidation check needed).

## Peer Feedback

→ **For Architect:** All 11 spec Open Questions are addressable by this research. The four highest-leverage decisions: (1) co-location, (2) composition with `/jim:conf`, (3) operation-surface grouping, (4) slug normalization algorithm and collision rule. The remaining seven have clear defaults flagged above.

→ **For Architect:** **Slug normalization is a security boundary, not a stylistic choice.** Today's prose ("lowercase, hyphens, no spaces") doesn't address path traversal. The plan must enforce the algorithm at the script layer — `..`, `/`, control chars, empty results all rejected. Don't delegate to the LLM.

→ **For Architect:** **Composition choice (b) degrades the cross-agent story.** `${CLAUDE_PLUGIN_ROOT}` doesn't apply in `.agents/skills/` layouts (cross-agent interop §4 step 2). `jimfile.sh` calling `jimconf.sh` requires a known sibling layout. (a) is more portable; weigh against today's coupling cost.

→ **For PM (advisory, not blocking):** Spec Out of Scope and the five portability-hygiene bullets accurately reflect 2026 cross-agent reality and need no further refinement.
