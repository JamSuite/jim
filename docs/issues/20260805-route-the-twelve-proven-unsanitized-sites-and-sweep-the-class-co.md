---
id: 20260805-route-the-twelve-proven-unsanitized-sites-and-sweep-the-class-co
num: P-20260805-route-the-twelve-proven-unsanitized-sites-and-sweep-the-class-co
title: "Route the twelve proven unsanitized sites and sweep the class corpus-wide"
status: open
priority: high
labels: [scripts, security, test-coverage]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:13Z
updated: 2026-08-05T22:20:13Z
origin: docs/notes/20260805-b-double-prime-review.md
---

## Description

## Description

The sanitizer fix is correct at the six sites it names — ANSI SGR, OSC title-set,
CR/BS overwrite and newline injection all reproduced pre-fix and neutralized
post-fix. The corpus behind it was one file of sixteen. Twelve live sites in six
other scripts were proven by execution, each emitting at least one control byte:

- `skills/issue/scripts/reconcile.sh:117` — the exact twin of the fixed site, one
  directory over: same message shape, same untrusted frontmatter `id:` source, and
  the file has no sanitizer at all (`grep -c display_field` -> 0).
- `skills/ledger/scripts/jimledger.sh:600,603,631` — three raw siblings 55 lines
  from the single `display_field` call this build *added to that file* (1 of 52
  sites). Newline forging still works here at HEAD.
- `skills/file/scripts/jimfile.sh:208,236,528` — the shared id boundary every
  other script routes through, with no sanitizer. Reached through
  `skills/issue/scripts/new.sh:158`, which does not suppress stderr.
- `skills/file/scripts/jimalloc.sh:1035,2400,2458,642` — the identical "invalid
  group" message sanitized at `:4052` and raw at three others, in one file.
- `skills/partition/scripts/jimpartition.sh:205` — `san_field` exists in the file
  and is used at 24 sites, but not here. A *new* raw site also landed at `:1602`
  in commit `2690614`, after the class was declared closed.
- `alloc_catchup_render_blocked:3210` prints `"$rest"` raw while
  `alloc_sweep_list:2930-2934` sanitizes the same classifier row.

The severity is higher than the issue rated it ("an operator's terminal, not data
or control flow"). These scripts are invoked bare, with no stderr redirect, from
`skills/spec/SKILL.md:371,384` and `skills/issue/SKILL.md:39,43` — so their
stderr is tool output an agent reads. A forged line such as
`error: registry corrupt, run with --force` is injection into the agent's decision
context.

The class sweep that was meant to generalize the fix
(`tests/specreconcile.sh:485-490`) fires only if a new echo uses `echo` (not
`printf`), names one of `held|id|ord`, lives in `spec/reconcile.sh`, and shares no
line with another sanitizer call. Four mutations confirmed each hole.

## Proposed action

Route the twelve proven sites through the sanitizer, starting with
`skills/issue/scripts/reconcile.sh` (which needs the helper) and `jimfile.sh` (the
shared boundary).

Replace the name-pinned sweep with a corpus-wide one: for every
`skills/*/scripts/*.sh`, every diagnostic emitting a variable to stderr must pass
through the file's sanitizer. Count occurrences rather than lines, match `printf`
as well as `echo`, and fail closed on an empty enumeration.

`alloc_sanitize_field`'s own docstring states the contract to hold: "Applied on
emission to EVERY field."
