---
title: "Project-level configuration for jim document paths"
type: feature
group: "platform"
id: "008"
status: approved
---

# 008 Project-level configuration for jim document paths

## Overview
Introduce a project-level configuration file (`jimconf.{ext}`) that lets a project override the hard-coded paths jim uses to locate its strategic and SDLC documents, so jim can be adopted into projects with existing or non-default documentation layouts.

## Problem Statement

Today, jim's skills assume fixed locations for every document they read or produce: `VISION.md`, `ROADMAP.md`, and `ARCHITECTURE.md` at the project root; specs under `docs/specs/`; brainstorms under `docs/brainstorms/`; debug reports under `docs/debug/`. These paths are baked into skill instructions as literal strings.

Two user pains follow from this:

1. **Adoption friction.** A developer dropping jim into an existing project that already has, for example, `architecture/overview.md` or `documentation/specs/` cannot use jim without first reorganizing their tree to jim's conventions. For projects with established conventions or shared docs sites, that's a non-starter.
2. **Inflexibility for jim users.** An existing jim user who wants to reorganize their layout (move ARCHITECTURE.md into a subfolder, rename the specs directory, co-locate docs with source) has no supported path — the only option is forking the plugin or living with the defaults.

A secondary effect, raised during scoping: today's "skip this step if `ARCHITECTURE.md` does not exist" guidance is encoded in skill prompts as natural-language instructions for the LLM to interpret. Once paths become configurable, every skill needs a single, reliable answer to "where is this document, and does it exist?" — which today is duplicated across skills as prose. Solving the configuration problem creates the foundation for addressing this duplication later, but the duplication itself is **not** in scope for this spec.

A third design driver, surfaced during planning: the configuration *file* should be portable and agent-neutral so that future cross-agent support (Codex, Gemini CLI, Cursor, etc.) is not blocked by a Claude-Code-specific config location. The *invocation mechanism* used by jim's current skills (e.g., `${CLAUDE_PLUGIN_ROOT}` substitution inside SKILL.md bodies) is necessarily Claude-Code-specific in v1; cross-agent invocation is a known follow-on concern to be addressed when jim formally adds support for other agents.

## User Stories

- As a developer adopting jim into an existing project with non-default doc locations, I can declare those paths in a `jimconf.{ext}` file at the project root so jim's skills find my existing documents without me reorganizing my tree.
- As an existing jim user who wants to reorganize my project layout, I can update `jimconf.{ext}` to point jim at the new locations so my skills continue to work after the move.
- As a new jim user with a greenfield project, I can use jim with zero configuration and get exactly today's behavior — no `jimconf.{ext}` required.
- As a jim user who only wants to override one path, I can specify only that key in `jimconf.{ext}` and leave the rest defaulted.

## Acceptance Criteria

- [ ] A configurable surface exists for the following document paths, each with a documented default matching today's behavior:
  - Specs directory (default: `docs/specs/`)
  - ARCHITECTURE.md (default: `ARCHITECTURE.md`)
  - VISION.md (default: `VISION.md`)
  - ROADMAP.md (default: `ROADMAP.md`)
  - Brainstorms directory (default: `docs/brainstorms/`)
  - Debug reports directory (default: `docs/debug/`)
  - Pre-commit script (default: `./pre-commit.sh`) — added 2026-05-05 by the file-resolver-conventions refactor (`docs/brainstorms/20260505-file-resolver-conventions-audit.md`). Resolves the path-where-it-would-live; consumers wrap calls in an existence gate at the skill layer, so a missing file is silently skipped.
- [ ] When no `jimconf.{ext}` file exists at the project root, every skill behaves identically to its current behavior — zero-config baseline is preserved.
- [ ] When a `jimconf.{ext}` file exists but only specifies a subset of keys, the specified keys override the defaults and unspecified keys retain the defaults (layered/partial override).
- [ ] Skills that read or produce these documents resolve the path through the configuration layer rather than assuming the default.
- [ ] The configuration layer's contract is **path resolution only** — it returns a path string. Whether that path points to an existing file is the consuming skill's concern, not the config layer's.
- [ ] Documentation explains: how to create a `jimconf.{ext}` file, the supported keys with their defaults, and the rule that *changing a configured path does not move existing files — the user is responsible for moving artifacts manually*.
- [ ] All existing jim self-hosted specs (001–006) continue to work without a `jimconf.{ext}` file present.
- [ ] Before this spec is marked complete, the build phase demonstrates that jim works correctly against at least one non-default layout (e.g., ARCHITECTURE.md relocated to a subdirectory, specs directory renamed). The verification method — manual walkthrough, automated test, or other — is the architect's choice and should align with the testing strategy decided in the Open Questions below.
- [ ] **Amended 2026-05-12 by spec 013 (D7(c)):** Skill bodies call `jimconf.sh get <key>` directly for value-typed config keys (`require_pre_commit`, `require_pre_completion`, `auto_arch_feedback`). jimconf remains the raw-value layer; the file-ops layer (`jimfile.sh`) does not wrap value keys, only path keys. The "skills always call jimfile, never jimconf" rule (per brainstorm D6) is scoped to file operations only.

## Out of Scope

The following are deliberately excluded from this spec to keep v1 tight. Several may be revisited in future specs once the foundation lands.

- **Agent augmentation via config.** Letting a project add or modify agent instructions through `jimconf` is a future extension; v1 is paths only.
- **Template overrides via config.** Letting a project supply its own `spec-template.md`, `plan-template.md`, etc. is a future extension; v1 is paths only.
- **Configurable spec-group conventions.** The `{group}/{00X}-{name}/` convention inside the specs directory remains fixed in v1.
- **Configurable model preferences, tool allowlists, or agent skill bindings.** Out of scope.
- **Automatic file migration on config change.** If a user changes a configured path, jim does not move, copy, or rewrite existing files. This is documented as a user responsibility.
- **Strict-mode validation.** A malformed or partial `jimconf.{ext}` does not fail loudly; missing keys fall through to defaults. (Sensible diagnostics for clearly-malformed files may be addressed in the plan, but strictness is not a goal.)
- **A general-purpose path/file helper skill** (e.g., a hypothetical `/jim:file spec group=... id=next` or `/jim:file exists ARCHITECTURE.md`). This was raised during scoping as a possible companion concern but is its own feature and belongs in a separate spec.
- **Refactoring existing skill prompts** to replace natural-language existence checks with deterministic helpers. The configuration layer makes this *possible*; doing it is a follow-on refactor spec.
- **Multi-project / monorepo / nested config** behavior. v1 reads one `jimconf.{ext}` at the project root.

## Open Questions

The following questions are deliberately deferred to `/jim:research` and `/jim:plan`, per the user's framing during scoping. Each is a HOW question, not a WHAT question, and should not gate spec approval.

- [x] ~~Config file format.~~ → **Resolved in plan (Decision 2):** TOML, flat top-level `KEY = "value"` lines. Valid TOML (real parser will accept) AND parseable with `grep | cut | tr` — zero external dependencies.
- [x] ~~Config file naming — visibility and extension.~~ → **Resolved in plan (Decision 2):** `jimconf.toml` at project root. Visible file, single extension, no dots in the base name. See `docs/specs/platform/002-jimconf/plan.md`.
- [x] ~~Prompt-to-config interface.~~ → **Resolved in plan (Decisions 1 + 3):** option (c) — a single bash script at `skills/conf/scripts/jimconf.sh` invoked from each consuming skill via Claude Code's `` !`<command>` `` injection primitive. A standalone `/jim:conf` skill exists as a thin user-facing wrapper for inspection/debugging.
- [x] ~~Whether jim should introduce executable code at all.~~ → **Resolved in plan (Decision 8 + Constitution Check):** yes, a minimal scripting layer is admitted. ARCHITECTURE.md L181/L183 ("pure markdown — no build step, no dependencies, no package manager") is updated as part of the same plan PR sequence (Task 17) to reflect the new "markdown + minimal scripting layer" reality.
- [x] ~~Prior art survey.~~ → **Resolved in `research.md`:** comprehensive survey of Anthropic-shipped plugins (`plugin-settings`, `commit-commands`, `feature-dev`), community plugins (`claude-mem`, `arc-kit`, `anilcancakir/claude-code-plugins`), cross-agent landscape (Codex, Gemini CLI, Cursor, Cline, Aider, AGENTS.md), and bash/TOML parsing patterns. See `docs/specs/platform/002-jimconf/research.md`.
- [x] ~~Config resolution timing and caching.~~ → **Resolved in plan (Decision 6):** no caching. Each `!`-injection re-runs the script. Consistency within a single skill run is guaranteed by `!`-injection's once-per-invocation execution model.
- [x] ~~Automated testing strategy for jim's first executable code.~~ → **Resolved in plan (Decision 4):** plain-bash test runner at `tests/run.sh` with **zero third-party dependencies** (no bats, no shunit2, no pytest). Run via `bash tests/run.sh`. Tests live in `tests/` at repo root and are inert at runtime — Claude Code only loads `skills/` and `agents/`. Strict documentation discipline enforced: file header docblock, named section banners, per-helper docblocks, per-test-case AC mapping comments, no clever bash, maintenance notes block.

> **Note (added by spec 007):** The shared `testlib.sh` and aggregate `run.sh` referenced above have moved into `skills/meta-test/scripts/` per spec 007's lib-location decision. The per-script test file `tests/jimconf.sh` stays in `tests/` and sources the relocated lib via a `BASH_SOURCE`-relative path. Run with `bash skills/meta-test/scripts/run.sh` (or `/jim:meta-test run`); future test additions should be scaffolded via `/jim:meta-test add jimconf <case_name>`. See `docs/specs/platform/001-meta-test/` for canonical conventions.
- [x] ~~Strategic-alignment confirmation — ROADMAP placement of configuration work~~ → User has decided to pull configuration support forward from the **Later** bucket. ROADMAP.md should be updated separately (via `/jim:roadmap`) to reflect the new sequencing.
