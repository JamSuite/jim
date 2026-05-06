---
name: conf
description: >
  Inspect jim's resolved configuration paths. Use when the user invokes
  /jim:conf, asks where jim is reading or writing a document, wants to
  debug a jimconf.toml, or wants to inspect a specific config file via
  the `-c <path>` flag. Do not use for setting paths — there is no
  write surface; users edit `jimconf.toml` directly.
argument-hint: "[get <key> | list | path | keys] (optional: -c <path>)"
allowed-tools: Bash(bash *)
---

# /jim:conf

Inspect the resolved jim configuration for the current project.

This skill is a thin wrapper around `skills/conf/scripts/jimconf.sh` —
the same script every other jim skill uses to resolve document paths
via Claude Code's `!`-injection primitive. Output is the script's
stdout, verbatim.

## Examples

- `/jim:conf list` — every key with its resolved value (override or default)
- `/jim:conf get specs` — resolve a single key
- `/jim:conf path` — print the absolute path of the active config, or empty if none
- `/jim:conf keys` — print the valid CLI key list
- `/jim:conf -c jimconf.toml.example list` — inspect the shipped defaults
- `/jim:conf -c .claude/old-jimconf.toml list` — inspect a backup file

## Run

!`bash ${CLAUDE_SKILL_DIR}/scripts/jimconf.sh $ARGUMENTS`
