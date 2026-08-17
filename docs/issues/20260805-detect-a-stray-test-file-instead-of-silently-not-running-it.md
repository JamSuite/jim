---
id: 20260805-detect-a-stray-test-file-instead-of-silently-not-running-it
num: 221
title: "Detect a stray test file instead of silently not running it"
status: closed
priority: medium
labels: [000-blueprint, verify, test]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T02:19:12Z
updated: 2026-08-05T10:21:33Z
origin: docs/specs/platform/000-blueprint/spec.md
---

## Description

## Description

The `tests-under-tests` invariant claims "the runner **and** scaffold enforce the
boundary". The scaffold does; the runner does not.

**The scaffold genuinely enforces.** `metatest.sh:47` gates the name against
`^[a-zA-Z_][a-zA-Z0-9_]*$` — no slashes, dots, or leading digits — and `:75`
composes `local target="tests/$name.sh"` from a hard-coded literal with no flag or
env override. The traversal refusal is pinned by
`case_metatest_scaffold_rejects_bad_name_path_traversal`
(`tests/metatest.sh:127`). The create path cannot produce a test outside `tests/`.

**The runner only contains.** `run.sh:54-57` is `for tf in tests/*.sh`. That is
not an overridable default — it genuinely limits what gets loaded — but
containment is not enforcement of a placement rule. A hand-authored test file
dropped under `skills/foo/` is silently **not run**, and nothing anywhere detects
it. `tests/scripthygiene.sh:83` already walks `skills/*/scripts/*.sh` for its
preamble sweep and asks nothing about location, so the one corpus-wide check that
could catch it doesn't look.

A secondary gap compounds it: both mechanisms are **PWD-anchored**, not
`REPO_ROOT`-anchored. `run.sh:24` and `metatest.sh:20-21` state the repo-root
assumption in comments only, and the skill's invocation section never pins the
cwd. Invoked from `skills/meta-test/`, `scaffold widget` writes
`skills/meta-test/tests/widget.sh` — a test file **inside a Claude Code discovery
root** — and neither the name regex nor any test objects.

The other two conjuncts hold cleanly: no test-shaped file exists outside `tests/`
today, and nothing under `tests/` is loaded by Claude Code (`skills/` and
`agents/` are the only discovery roots; `tests/` holds no `.md`, and no agent or
skill references it as an `@`-reference or `!`-injection).

So the current tree is clean and the enforcement machinery has a hole: prevention
on the create path, passive containment on the load path, and **zero detection**
of a violation arriving by any other route.

## Proposed action

Add a case to `tests/scripthygiene.sh` sweeping `skills/` and `agents/` for
test-shaped files — a `case_*` function definition or a `testlib.sh` source —
and failing if any exist. That is the cheapest closure and it reuses a sweep that
already walks the right corpus.

Then either anchor the runner glob and the scaffold target at `REPO_ROOT` rather
than PWD, or state the cwd requirement where the skill tells an operator to
invoke them, so a test cannot land inside a discovery root by being run from the
wrong directory.

## Provenance

`/jim:verify --since 175047c platform` — `tests-under-tests` (medium), judged
`violated` on the enforcement conjunct, `channel=in-change`. Resolved **fix** at
the blueprint update's violation fork.

## Resolution (2026-08-05)

The primary proposed action landed: `tests/scripthygiene.sh` sweeps `skills/` and
`agents/` for test-shaped files — a `case_*` definition or a `testlib.sh` source
— and fails if any exist, fail-closed on an empty corpus. That is the detection
the invariant claimed and did not have.

**The second half was tried both ways, and the anchoring option is wrong.**
Anchoring the runner's glob and the scaffold's target at `REPO_ROOT` looks
strictly safer and breaks the harness: this dispatcher is itself under test, and
those cases scaffold into a temp tree and invoke the runner from it. PWD-relative
resolution is what makes those runs find no test files and return — anchored,
each one loads `tests/metatest.sh` and invokes the runner again, without bound.
Both were reverted, and both now carry the reason at the site, since the next
reader will otherwise make the same correction.

So the cwd risk is closed at the point it actually bites instead: both write
verbs **refuse outright** when the cwd is inside a Claude Code discovery root.
That is the one wrong base the name gate cannot see — the name is valid and only
the base is wrong — and refusing costs the harness nothing, because its sandboxes
are not under `skills/` or `agents/`.

**Deliberately still open:** the `tests-under-tests` invariant's text still says
the runner enforces the boundary, where it contains and the sweep now detects.
That sentence is a `/jim:blueprint` write; it rides the docs pass.
