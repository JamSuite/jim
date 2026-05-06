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
allowed-tools: Bash(bash *)
---

# /jim:file

Run jim's file/path resolver:

!`bash ${CLAUDE_SKILL_DIR}/scripts/jimfile.sh $ARGUMENTS`

## Examples

- `/jim:file exists docs/specs/jim/008-jimfile/spec.md` — `yes` or `no`
- `/jim:file get vision` — resolved path for the configured vision doc
- `/jim:file get pre_commit` — resolved path for the configured pre-commit script
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

**Skills and agents always call `jimfile.sh`, never `jimconf.sh` directly.**
`jimfile.sh` chains internally to `jimconf.sh` for any operation that needs
a configured path (`get`, `next-id`, `path`, `glob`). The user-facing
`/jim:conf` skill remains for human inspection of the underlying config —
it is not a programmatic surface for skill bodies.

For existence-gated reads and executes, wrap `jimfile.sh get …` calls in
the BASIC-flavored gate idiom (see `ARCHITECTURE.md` → Plugin Conventions).

## Notes

- The script honors `/jim:conf` overrides automatically — it shells out to
  `jimconf.sh` for every configurable path (`specs`, `architecture`,
  `vision`, `roadmap`, `brainstorms`, `debug`, `pre_commit`).
- Path-and-name resolution only — the script never reads, writes, or
  deletes files. Whether to act on a returned path is the calling skill's
  concern.
- Slug normalization is the security boundary. Path-traversal-style topics
  collapse safely; `.`, `..`, and empty results are explicitly rejected.
