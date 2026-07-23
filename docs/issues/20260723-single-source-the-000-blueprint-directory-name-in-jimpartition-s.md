---
id: 20260723-single-source-the-000-blueprint-directory-name-in-jimpartition-s
num: 88
title: "Single-source the 000-blueprint directory name in jimpartition.sh"
status: closed
priority: low
labels: [verify, partition, refactor]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-23T06:09:14Z
updated: 2026-07-23T07:11:34Z
origin: docs/specs/jim/049-contracts-check-hardening/review.md
---

## Description

Surfaced by the spec-049 post-build living-intent sensor while judging the
`blueprint-slot-reserved` invariant (verdict: holds).

The `000-blueprint` **directory** name is still hand-built at three sites in
`skills/partition/scripts/jimpartition.sh` — the rename/split/merge
`blueprint-exists` structural probes:

- `jimpartition.sh:962` / `:1057` / `:1218` — `[[ -d "$specs_dir/$old/000-blueprint" ]]`
  (with sibling `emit_check` message strings).

These are **not** a `blueprint-slot-reserved` violation: that invariant governs
the reserved *slot spec.md* path (`.../000-blueprint/spec.md`), which is resolved
only via `jimfile.sh path blueprint <group>`. These three probes construct the
*directory* path instead, and the resolver currently has no directory-yielding
form to route them through — so they are the last direct literal-coupling to the
reserved `000-blueprint` directory name in production code.

**Proposed action:** add a directory-yielding form to the resolver (e.g.
`jimfile.sh path blueprint-dir <group>` → `{specs}/<group>/000-blueprint`,
slug-validated like the existing `path blueprint`) and route the three
`jimpartition.sh` probes through it. This fully single-sources the reserved
directory name and removes the last hand-composition.

Out of scope for spec 049 (which only touched `jimverify.sh`); tracked here as a
low-priority hardening follow-on.

## Resolution (2026-07-23)

Single-sourced the reserved directory name; three probes routed. `jimfile.sh`
and `jimpartition.sh` suites green (116 / 153).

**The proposed action didn't fit — and that's the finding.** The proposal was a
directory-yielding resolver form (`path blueprint <group> dir`) routed into the
three probes. Verification killed it: the probes build on `$specs_dir`, a
**positional argument** to each preflight (`rename-preflight <map> <specs-dir>
<old> <new>`) that bases *every* path in the function (new-collision `:953`,
affected-prefix `:989` / `:1119`, the blueprint probe). Any resolver form roots
at `jimconf_get specs` (`jimfile.sh` slot producer). Routing one probe through it
would make the blueprint check read config while its five siblings honor the
`<specs-dir>` argument — breaking the preflight's contract as a *pure function of
its `<specs-dir>` argument* (which is why it takes the arg instead of reading
config: testability + the config-free-script discipline). In production the two
bases coincide (the skill passes `get specs`), so the bug would be latent — worse,
not better.

**What shipped — name-only single source.** The only real coupling was the bare
segment `000-blueprint`.

- `jimfile.sh`: added `readonly BLUEPRINT_DIRNAME="000-blueprint"`, consumed at
  the slot producer (so the literal lives in one place in code), and exposed it
  via a no-I/O `blueprint-dirname` emitter verb. No `KINDS` change — a directory
  is not a document kind — so `cmd_kinds` / the "7 kinds" test are untouched.
- `jimpartition.sh`: each preflight fetches the name once
  (`bp_name="$(bash "$JIMFILE" blueprint-dirname)"`, mirroring the existing
  `valid-relpath` composition) and composes on `$specs_dir`. Emitted detail
  strings are byte-identical, so the existing preflight cases stay green.
- New test `case_jimfile_blueprint_dirname_emits_reserved_name`.

**Deliberately not touched.** `jimledger.sh:189` embeds `000-blueprint` in a
commit-message string (`docs(blueprint): $mode 000-blueprint`), not a path — not
a resolver candidate. Prose comments that name the value document behavior and
stay. No `path blueprint <group> dir` resolver form was added: nothing consumes a
config-rooted blueprint directory today, so it would be YAGNI surface.
