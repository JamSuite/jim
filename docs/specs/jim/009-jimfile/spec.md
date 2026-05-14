---
title: "File and path utilities for jim's skills and agents"
type: feature
group: "jim"
id: "009"
status: approved
---

# 009 File and path utilities for jim's skills and agents

## Overview
Introduce a project-level utility (`/jim:file`) — a thin user-facing skill backed by a shared script — that replaces in-prose file/path operations across jim's skills and agents with a single deterministic call surface, reducing token cost, eliminating duplicated logic, and making the SDLC pipeline faster and more reliable.

## Problem Statement

Across jim's 11 skills and 5 agents, the same handful of file/path utility operations are repeated as natural-language prose for the LLM to interpret on each invocation. A survey of `skills/` and `agents/` found ~41 distinct prose patterns spanning six categories:

1. **Existence checks** — "if VISION.md exists", "Check for existing ARCHITECTURE.md", "if research.md is missing", etc. (10 occurrences across `spec`, `vision`, `arch`, `roadmap`, `research`, `plan`, `debug`).
2. **Spec ID incrementing** — "Glob `{group}/*/`, find max ID, increment, zero-pad to 3 digits" — duplicated across `spec`, `plan`, `research`, plus context paragraphs in three agents (7 occurrences).
3. **Date-prefixed filenames** — `{YYYYMMDD}-{topic}.md` for debug reports and brainstorms, with the LLM responsible for inserting today's date and slugging the topic (6 occurrences across `brainstorm`, `research`, `debug`, `roadmap`, plus the debug template).
4. **Path generation for new artifacts** — `docs/specs/{group}/{id}-{name}/spec.md`, `docs/debug/{YYYYMMDD}-{topic}.md`, etc. — the canonical path is a function of the artifact type and is currently constructed in prose every time (10 occurrences).
5. **Glob discovery of canonical artifact directories** — "Glob to find existing specs / IDs / debug reports", with parsing logic embedded in prose (8 occurrences).
6. **Most-recent / staleness lookups** — implicit in date-prefixed patterns and "Last updated" timestamps; not yet explicit prose, but emerges naturally when staleness matters (e.g., a plan checking whether research is current).

Three user pains follow:

1. **Token cost on every invocation.** Each skill body re-states the same prose ("Glob to find existing IDs, pick max+1, zero-pad to 3 digits"). Skill bodies load into the LLM's context on every invocation, so this prose is paid for repeatedly across the lifetime of the project.
2. **Inconsistency drift.** LLM-interpreted prose can drift between skills — one skill normalizes a topic slug differently than another, or one handles ID gaps in the sequence while another doesn't. The duplication makes drift hard to police.
3. **Slowness of the SDLC pipeline.** Operations a deterministic script can resolve in milliseconds (existence check, ID increment, date-prefixed filename) require LLM cycles today — Glob calls, parsing, decision-making — that are orders of magnitude slower and more expensive than a script.

The precedent is `/jim:conf` (spec 007). That feature replaced ~20 hardcoded path literals across skills with a single deterministic resolver. This spec applies the same pattern to *operations on paths* — not just resolving where a doc lives, but answering "does it exist?", "what's the next free ID?", and "what's today's debug filename for topic X?".

A secondary concern surfaced during scoping: this is jim's second piece of executable code. ARCHITECTURE.md (updated by 007) already documents a "minimal scripting layer" pattern. Whether the new utility extends that pattern in place or sits alongside it is a design choice deferred to the architect.

## User Stories

- As a jim skill author, I can replace prose like "if ARCHITECTURE.md exists" with a single deterministic call that returns a present/absent answer, so my skill body is shorter and the LLM doesn't have to reason about file existence.
- As a jim skill author writing a new spec/plan/research/debug/brainstorm artifact, I can call `/jim:file` to produce the canonical write path (with correct ID increment or date prefix) so I don't restate the path-construction logic in prose.
- As a jim user invoking `/jim:spec` or `/jim:debug`, the spec ID assignment and debug filename are consistent across runs (no LLM drift on zero-padding, gap handling, slug normalization) because the script — not the prompt — decides.
- As a jim user, I can run `/jim:file` directly to inspect what the resolver would do for a given operation (analogous to `/jim:conf list`), so I can debug a confusing skill behavior without reading the script.
- As a jim contributor reading any skill, I see one consistent calling convention for file/path operations, so cross-skill audits and refactors are straightforward.

## Acceptance Criteria

- [ ] A utility surface exposes, at minimum, the following operations:
  - **Existence check** for a given path. Returns a deterministic indication of present/absent.
  - **Configured-path resolution** (`get <key>`) — added 2026-05-05 by the file-resolver-conventions refactor (`docs/brainstorms/20260505-file-resolver-conventions-audit.md`). Delegates to `jimconf.sh get <key>` so skills and agents have a single entry point and never need to call jimconf directly.
  - **Next spec ID** for a given group, in 3-digit zero-padded form, computed from the canonical specs directory.
  - **Canonical artifact path** for a new spec, plan, research, debug, or brainstorm — with date prefix or ID injected as required by the artifact type.
  - **Topic slug normalization** — given a free-form topic string, produce the kebab-case slug used in date-prefixed filenames.
  - **Glob discovery** for the canonical artifact directories (specs by group, debug reports, brainstorms) — returns a list of paths.
- [ ] The utility honors paths configured via `/jim:conf` — when a project relocates its specs or debug directory, `/jim:file` resolves operations against the configured location, not the default.
- [ ] When called from a skill body, the resolved value (path, ID, etc.) lands in the prompt before the LLM reads it — same composition pattern as `/jim:conf`.
- [ ] A user-facing `/jim:file` slash command exists for human inspection and debugging, mirroring the `/jim:conf` user-facing pattern.
- [ ] The utility is path-and-name resolution only — it does not read file content, write file content, mutate files, or delete files. Whether to act on a returned path is the calling skill's concern.
- [ ] Deterministic, documented edge-case behavior for: gaps in spec ID sequences, slug collisions on the same date, missing target directories, and slug normalization rules.
- [ ] Zero third-party dependencies — implementable with bash + standard POSIX tools, matching the precedent established by `jimconf.sh`.
- [ ] Skills and agents that today use prose for any of the six categories listed in the Problem Statement become *eligible* to migrate to `/jim:file`. Whether all of them migrate in the same PR sequence is the architect's call (this spec does not mandate full migration in v1).
- [ ] All existing self-hosted specs (001–007) and current jim behavior continue to work whether or not `/jim:file` adoption has happened — migration is purely additive and reversible.
- [ ] Tests live alongside jim's existing test infrastructure (`tests/`), follow the same zero-dependency and strict-documentation conventions established by 007, and verify the full operation surface plus its edge cases.

> **Note (added by spec 007):** The shared `testlib.sh` and aggregate `run.sh` referenced above have moved into `skills/meta-test/scripts/` per spec 007's lib-location decision. The per-script test file `tests/jimfile.sh` stays in `tests/` and sources the relocated lib via a `BASH_SOURCE`-relative path. Run with `bash skills/meta-test/scripts/run.sh` (or `/jim:meta-test run`); future test additions should be scaffolded via `/jim:meta-test add jimfile <case_name>`. See `docs/specs/jim/007-meta-test/` for canonical conventions.
- [ ] Documentation explains the operation surface, the user-facing inspection commands, the contract (resolution only, no I/O), and the migration story for existing skills.
- [ ] Before this spec is marked complete, the build phase demonstrates that at least one consuming skill has migrated end-to-end (e.g., `/jim:spec` ID assignment, or `/jim:debug` filename construction) and produces correct output. The verification method is the architect's choice.
- [ ] **Amended 2026-05-12 by spec 013 (D2); re-amended 2026-05-13 by spec 011 (D2-revised):** `get <key>` returns the configured path *if it exists on disk*, else the literal string `NOT_FOUND`. Existence-checking is performed inside `cmd_get` (`test -e`). Unknown-key exit-1 and malformed-invocation exit-2 are preserved. `NOT_FOUND`-result is exit-0; directive-vocab callers compare via `IF <name> != "NOT_FOUND" THEN`. The original D2 path-or-empty shape (and D8's empty-slot no-op contract) are no longer load-bearing — superseded by the 2026-05-13 amendment to spec 011 to close the EXISTS-trap defect (`docs/brainstorms/20260513-directive-vocab-exists-trap.md`).
- [ ] **Amended 2026-05-12 by spec 013 (D3):** `path <key>` (single-arg form) returns the configured path *regardless of existence* — the write-target use case for `arch` / `vision` / `roadmap`. `cmd_path` dispatches by arity: one argument → key form (delegates to `jimconf.sh get`); two-or-more arguments → existing kind form (`path spec <group> <id> <name>`, `path debug <topic>`, etc.). The only `KINDS`∩`KEYS` overlap is `debug`: `path debug` (no further args) takes the key form; `path debug <topic>` continues to the kind form.

## Out of Scope

- **File content reads.** `/jim:file` does not read file bodies. Skills consume content via the platform's `Read` tool.
- **File content writes or mutations.** `/jim:file` returns a path string; writing is the calling skill's job.
- **File deletion or move.** No destructive operations.
- **Refactoring all existing skill prose in this spec.** The utility's existence makes migration *possible*; deciding which skills migrate first and how aggressively is the architect's call (and may be staged across multiple PRs). This spec scopes the utility itself and its user-facing skill, not the full migration.
- **Replacing `/jim:conf`.** `/jim:file` is a sibling utility, not a replacement. `/jim:conf` resolves *where* a configured doc lives; `/jim:file` performs *operations* against those locations.
- **General-purpose filesystem operations** beyond jim's documented artifact types (e.g., a generic "list all markdown files in X"). The surface is bounded to jim's known artifact set: spec, plan, research, debug, brainstorm, plus their containing directories.
- **Spec ID gap reclamation.** If `001`, `003`, `005` exist, the next ID is computed by the simple "max + 1" rule (likely `006`). Filling `002` or `004` is explicitly excluded.
- **Cross-agent (Codex/Gemini/Cursor/Windsurf/Cline/Junie/Roo) consumption.** No jim-side code is written to integrate with other agents in v1. However, this spec assumes the script will eventually need to be reachable from non–Claude-Code hosts (see `docs/prior-art/20260504-research-plugin-interoperability.md`), so the implementation should avoid Claude-Code-only mechanics where a portable equivalent is just as cheap. Concrete portability hygiene to honor in v1 (no extra features, just don't paint into a corner):
  - Non-interactive, no-TTY-assumed bash. Test under `bash -c '<script>' < /dev/null`.
  - No reliance on `${CLAUDE_PLUGIN_ROOT}` semantics inside the script body itself; the calling skill substitutes the path before invocation, which is already 007's pattern.
  - Skill content (`SKILL.md`) under `skills/` only — no Claude-Code-specific frontmatter (`agent:`, `context: fork`) carries logic the script depends on.
  - YAML frontmatter as the very first content of any new SKILL.md (Gemini CLI silently skips files with leading H1s).
  - Skill body and description survive being copied to `.agents/skills/` without modification.
- **Multi-project / monorepo / nested-config behavior.** Inherits the same single-root assumption as `/jim:conf`.
- **Caching across invocations.** Inherits `/jim:conf`'s no-cache policy — each call re-runs the script.
- **Strict-mode validation of inputs.** A malformed argument (e.g., an unknown artifact type) should fail predictably, but this spec does not require fancy diagnostic behavior beyond what 007 established.
- **Replacing existence-check prose with deterministic helpers wholesale.** This spec makes the helper available; rewriting every "if it exists" prose pattern across the codebase is a follow-on refactor concern (and was already deferred by 007's Out of Scope).
- **Most-recent / staleness lookup helpers.** Deferred to a follow-on spec per `plan.md` Out of Scope. Needs additional framing (mtime vs filename date vs frontmatter field) before scoping.

## Open Questions

All deferred questions resolved by `research.md` and `plan.md` for this spec. Each is annotated with the agent who answered and a pointer to where the resolution lives.

- [x] ~~**(researcher)** What prior art exists in other Claude Code plugins or coding agents (Codex, Gemini CLI, Cursor, Windsurf, Cline, Junie, Roo) for deterministic file/path utility scripts? Are there idiomatic CLI shapes worth adopting? `docs/prior-art/20260504-research-plugin-interoperability.md` is the starting reference.~~
  → `research.md` Prior Art (Tier 1: plugin-interoperability research; 007 research). No idiomatic cross-agent CLI shape to inherit; `jimconf.sh` is the local precedent.
- [x] ~~**(researcher)** How are other plugin authors solving the "shared script invoked from multiple skills" problem in cross-agent layouts (`.agents/skills/`, `.codex/skills/`, etc.) where `${CLAUDE_PLUGIN_ROOT}` doesn't apply? Note any portable patterns worth borrowing now to keep future cross-agent work cheap.~~
  → `research.md` Anchors §`${CLAUDE_PLUGIN_ROOT}` vs `${CLAUDE_SKILL_DIR}`; Peer Feedback (composition portability). `BASH_SOURCE`-relative resolution inside the script is portable; `${CLAUDE_PLUGIN_ROOT}` is kept at call sites only.
- [x] ~~**(researcher)** Are there platform constraints on how many `!`-injection calls a single skill body can compose, or on how their results are interleaved with prose? `/jim:conf` typically uses one or two per skill — `/jim:file` may push that count higher when a skill needs both a path resolution and an existence check or ID increment.~~
  → `research.md` Security & Performance §`!`-injection re-runs — 3–4 calls run in <100ms total; no platform cap hit. No caching needed.
- [x] ~~**(architect)** Composition with `/jim:conf` — does the new script shell out to `jimconf.sh` to resolve base paths, parse `jimconf.toml` independently, or accept resolved paths as arguments from the calling skill? Trade-offs on coupling, testability, and call-site verbosity.~~
  → `plan.md` Decision 2 — option (b), `BASH_SOURCE`-relative shell-out to `jimconf.sh`. Clean call sites; both scripts ship together so the relative path travels with the plugin.
- [x] ~~**(architect)** Co-location — does the new script live alongside `jimconf.sh` under `skills/conf/scripts/`, in its own `skills/file/scripts/`, or in a shared `skills/_scripts/` directory? Implications for the corresponding user-facing skill location.~~
  → `plan.md` Decision 3 — `skills/file/` (own skill directory). Matches one-skill-per-directory convention.
- [x] ~~**(architect)** CLI shape and naming — single-binary subcommand surface, or split between read-side and generative subcommands? Naming should remain mnemonic for skill authors who will see these calls scattered across SKILL.md bodies.~~
  → `plan.md` Decision 1 — verb-first subcommands: `exists`, `slug`, `date`, `next-id`, `path <kind> ...`, `glob <kind> [filter]`, `kinds`. Sibling style to `jimconf.sh`.
- [x] ~~**(architect)** Edge-case behaviors: slug collisions for date-prefixed filenames; slug normalization algorithm; missing target directory.~~
  → `plan.md` Decision 4 (slug pipeline `tr | sed | cut -c1-64`; reject empty/`.`/`..` at the script layer as a security boundary) and Decision 5 (collision: append numeric suffix `-2`, `-3`, …). Missing-dir behavior unchanged from spec Out of Scope: return path anyway; calling skill creates the directory before writing.
- [x] ~~**(architect)** Whether "find most recent X" / staleness-detection helpers are in v1 scope or deferred. The survey found this is implicit in current usage but not explicit prose.~~
  → `plan.md` Out of Scope — deferred to a follow-on spec; needs additional framing (mtime vs filename date vs frontmatter field).
- [x] ~~**(architect)** Migration strategy — should skill updates land in the same PR sequence as the script (the 007 pattern), or as a follow-on refactor spec? Migration risk and rollback story.~~
  → `plan.md` Decision 7 — three consumers migrated in v1 (`debug`, `brainstorm`, `spec`); remaining 7 (`vision`, `roadmap`, `arch`, `plan`, `research`, `meta-skill`, `meta-agent`) deferred to a follow-on refactor PR.
- [x] ~~**(architect)** Test runner — extend the existing `tests/run.sh` (currently dedicated to `jimconf.sh`) or create a parallel runner? Implication for the zero-dep convention and the strict-discipline doc rules established in 007.~~
  → `plan.md` Decision 9 — extend `tests/run.sh` with `case_jimfile_*` cases (filter via `bash tests/run.sh jimfile`). Inherits 007's zero-dep convention.
- [x] ~~**(architect)** Whether ARCHITECTURE.md needs updating again in this PR set, or whether the existing "Scripting Layer" subsection (added by 007) already covers a second script with at most a small additive note.~~
  → `plan.md` Decision 10 — bundled in this PR set, additive: project-tree block for `skills/file/`, plus one paragraph extending the Scripting Layer subsection to note the second script and the inter-script `BASH_SOURCE`-relative composition.
- [x] ~~**(architect)** Cross-agent portability hygiene — confirm the v1 implementation avoids the cross-agent landmines listed in `docs/prior-art/20260504-research-plugin-interoperability.md` §4 (non-TTY bash, no leading-H1 SKILL.md, no Claude-Code-only frontmatter carrying logic, etc.). This is constraint-shaping, not a feature — the goal is "don't paint into a corner," not "ship cross-agent support."~~
  → `plan.md` Decision 11 — all five constraints honored: non-interactive bash (smoke-tested via `bash -c '...' < /dev/null`); no `${CLAUDE_PLUGIN_ROOT}` inside the script body; YAML frontmatter is the very first content of `SKILL.md`; no `agent:` binding; skill survives copy to `.agents/skills/` unchanged.
