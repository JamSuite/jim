---
name: file
description: >
  Inspect jim's file/path resolver: existence checks, slug normalization,
  today's date, next spec ID, canonical artifact paths, and glob discovery.
  Use when the user invokes /jim:file, asks what jim would name a new file,
  wants to audit a slug or ID assignment, or wants to list existing
  artifacts. Do not use for setting paths — there is no write surface;
  users edit `jimconf.toml` directly via /jim:conf.
argument-hint: "<exists|get|slug|date|next-id|path|glob|kinds> [args]"
allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/jimfile.sh *)
---

# /jim:file

Run jim's file/path resolver:

!`bash ${CLAUDE_SKILL_DIR}/scripts/jimfile.sh $ARGUMENTS`

## Examples

- `/jim:file exists docs/specs/jim/008-jimfile/spec.md` — `yes` or `no`
- `/jim:file get vision` — configured vision-doc path *if the file exists on disk*, else empty
- `/jim:file get pre_commit` — configured pre-commit script path *if it exists*, else empty
- `/jim:file path vision` — configured vision-doc path regardless of existence (write-target form)
- `/jim:file slug "Auth Token Expiry"` — kebab-case slug
- `/jim:file date` — today as `YYYYMMDD`
- `/jim:file next-id jim` — next zero-padded spec ID for the `jim` group
- `/jim:file path spec jim 008 jimfile` — canonical spec path
- `/jim:file path debug "auth bug"` — date-prefixed debug path (collision-resolved)
- `/jim:file glob specs jim` — every spec in the `jim` group
- `/jim:file glob debug` — every existing debug report
- `/jim:file kinds` — valid artifact kinds (no I/O)
- `/jim:file -c jimconf.toml.example path debug "auth bug"` — inspect a specific config

## Convention for skill and agent authors

**Skills and agents call `jimfile.sh` for file operations (existence checks,
path resolution, glob discovery) and `jimconf.sh` directly for raw config
values (`require_pre_commit`, `require_pre_completion`, `auto_arch_feedback`).**
`jimfile.sh` chains internally to `jimconf.sh` for path-typed keys; value-typed
keys go to `jimconf.sh` directly because they're flags, not paths, and
existence-checking them is meaningless.

For path keys, `jimfile.sh get <key>` returns the configured path *only if
the file exists on disk*, else empty string. Use `jimfile.sh path <key>`
(single-arg form) when you want the configured path regardless of existence
— the write-target use case for `arch` / `vision` / `roadmap`.

The user-facing `/jim:conf` skill remains for human inspection of the
underlying config; the programmatic surface for value keys is
`jimconf.sh get <key>` invoked inline in skill bodies.

For existence-gated reads and executes, wrap `jimfile.sh get …` calls in
the directive vocabulary (see `ARCHITECTURE.md` → Plugin Conventions →
Logic-Flow Conventions).

## Notes

- The script honors `/jim:conf` overrides automatically — it shells out to
  `jimconf.sh` for every configurable path (`specs`, `architecture`,
  `vision`, `roadmap`, `brainstorms`, `debug`, `pre_commit`).
- Path-and-name resolution only — the script never reads, writes, or
  deletes files. Whether to act on a returned path is the calling skill's
  concern.
- Slug normalization is the security boundary. Path-traversal-style topics
  collapse safely; `.`, `..`, and empty results are explicitly rejected.
