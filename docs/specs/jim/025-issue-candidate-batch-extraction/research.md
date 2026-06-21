---
spec: "spec.md"
status: Active
date: "2026-06-20"
---

# Research: Issue candidate-batch mechanics extraction

## Anchors

**Surfacing-skill candidate-batch blocks (the duplication target):**
- `skills/spec/SKILL.md:178-240` — full block; template-write sub-step ~205-215.
- `skills/research/SKILL.md:133-195` — write ~160-170.
- `skills/plan/SKILL.md:131-193` — write ~158-168.
- `skills/build/SKILL.md:135-199` — nested under Step 6.3; write ~164-174.
- `skills/brainstorm/SKILL.md:72-134` — write ~99-109.
- `skills/debug/SKILL.md:65-127` — write ~92-102.
- `skills/sec/SKILL.md:223-293` — variant: severity→priority `230-234`, label derivation `240-241`, `Route` logic `248-250`, write ~256-266.

**Three filters — byte-identical peers, NO canonical source today** (the AC4 target): `spec:195-199`, `research:150-154`, `plan:148-152`, `build:154-158`, `brainstorm:89-93`, `debug:82-86`, `sec:246-250`.

**Untrusted-content precedent (the single-source-plus-pointer model to follow):**
- Canonical: `skills/issue/SKILL.md:167-182` (Step 7).
- Pointer string each skill carries: `` See `skills/issue/SKILL.md` Step 7 for the canonical `<untrusted-issue-content>` wrapping pattern. ``

**`/jim:issue add` — second write site + the stricter gate:**
- Write: `skills/issue/SKILL.md:140-151` (Write tool + `index.sh` regen).
- Actionability gate: `skills/issue/SKILL.md:44-52` ("already-shipped → point-of-encounter doc" framing).

**Output target (what the shared mechanism must emit / compose):**
- Template asset: `skills/issue/assets/issue-template.md:1-20` (spec-017 frontmatter + body shape).
- `jimfile.sh` composables: `next-id issue` ~247-252, `path issue` ~528-539 (validates id via `is_valid_id`), `now` ~243-245, `next-num issue` ~320-329.
- `skills/issue/scripts/index.sh` — regen, invoked post-write.
- **NEW:** a template-write helper does **not** exist today — skills write via the Write tool. This is the net-new deterministic surface.

**Guard to update:** `skills/meta-skill/SKILL.md:98` — checklist item requiring the pipeline-ownership filter; it explicitly says "re-validate when the candidate-batch convention changes."

**Test templates:** `tests/issues.sh` (2043 lines; `run_index`, `write_issue` helper at 66-78 — closest model for a new issue-write script), `tests/jimfile.sh` (901 lines; `run_jimfile` + `assert_*` if the helper lands in jimfile.sh), shared lib `skills/meta-test/scripts/testlib.sh` (`assert_exit`/`assert_eq`/`assert_nonempty`, fixtures).

## Local Patterns

- **Single-source-plus-pointer is already proven.** The untrusted-content rule lives once in `/jim:issue` Step 7; each skill carries a one-line pointer. AC4/AC5 follow the same shape — a brief inline restatement plus a pointer, **not** a runtime file read (which is the permission prompt specs 018/024 avoided).
- **Scripting layer = "single resolver, many consumers"** (ARCHITECTURE.md → Scripting Layer). Skills call `jimfile.sh`/`index.sh` via `!`-injection and the Bash tool; no script writes a templated file yet. The new mechanism composes existing helpers (`next-id`, `path`, `now`, `next-num`) and emits the template.
- **Bash conventions** (CLAUDE.md): `set -uo pipefail`, no third-party deps, never `source`/`eval` user data, `BASH_SOURCE`-relative inter-script paths.
- **Test template:** `tests/issues.sh`'s `write_issue` helper + `run_*` invokers is the closest existing model for exercising a new write mechanism.

## Security & Performance

- **Untrusted body.** The issue `body` is user/LLM-authored and may carry directive-style framing or secrets. The mechanism must persist it via `printf '%s'`, never interpolate it into an eval'd context — consistent with the no-`source`/no-`eval` rule. The scrub reminder (AC-C2) and untrusted-content wrapping stay in the prose layer; the script only writes bytes.
- **No new path surface.** The mechanism must resolve its target through `jimfile.sh next-id`/`path` (which validate via `is_valid_id`), never composing a path from raw title input — mirroring `render.sh show`'s discipline (security 019 Finding 1).
- **Performance net-neutral.** Same write count + one `index.sh` regen per batch. Moving template instantiation into bash also removes ~50 lines of prose per skill from skill-load context — a small token win.

## Recommendations (options for the architect — not decisions)

1. **Write-mechanism home.** A new subcommand under `skills/issue/scripts/` (peer to `index.sh`) keeps issue-file concerns in the issue skill's script dir and leaves `jimfile.sh` as the path/slug/time resolver it composes. Multi-line untrusted body is cleaner via stdin or a temp file than as a CLI arg. (Open: exact form — spec Open Question / Handoff Insight 2.)
2. **Filters.** Single-source the three-filter block to one canonical location (a section in `skills/issue/SKILL.md` alongside Step 7 is the natural home). While editing, fix the stale intro **"apply two filters" → "three"** — a byte-identical bug across all 7 skills since spec 024 added the third filter without updating the count.
3. **Fileable bar.** Define one canonical bar = {Resolution, Actionability, Pipeline-ownership} and express `/jim:issue add`'s "already-shipped" test as a facet of Actionability — or document the divergence (spec Open Question 2). Preserve current filing behavior either way (AC7).
4. **sec variant.** Keep sec's severity→priority / STRIDE-label / `Route` derivation in sec's prose; it produces fields and calls the same shared write mechanism. Do not collapse the derivation.
5. **Guard.** The plan must update/preserve `meta-skill/SKILL.md:98` — it asks to re-validate when the candidate-batch convention changes, and this refactor changes it.

## Alignment

Aligns with ARCHITECTURE.md → Scripting Layer ("single resolver, many consumers") and the Bash-vs-Prompt Decision Rule (deterministic template-write → bash; judgment/interactive flow → prompt). Consistent with VISION's convention-over-configuration and compounding institutional-memory goals — it removes drift across eight sites without adding workflow surface. It respects the locked constraints in specs 018/024: it does **not** pursue the runtime-read shared doc, the `Skill(jim:issue-batch)` sub-skill, or the `$ARGUMENTS`-passed candidate list those specs rejected. No divergence from any locked constraint.
