---
title: "Script-preamble conformance and invariant restoration"
type: refactor
group: "platform"
id: "006"
status: approved
origin:
  - "docs/issues/20260725-script-preamble-rule-vs-source-inherited-preambles-fix-or-fold.md"
---

# 006 Script-preamble conformance and invariant restoration

## Overview
Bring the three shell scripts that inherit `set -uo pipefail` via `source` into line with jim's house style by setting the preamble directly, then restore the withheld `script-preamble` invariant to platform's blueprint and guard it with a deterministic test so every first-party script self-sets the preamble.

## Refactor Rationale
- **Motivation:** The `script-preamble` invariant is currently withheld (fail-closed) from platform's `000-blueprint`, so a `high` project-wide script rule sits unrecorded and unverified. It returns to the table only once the code conforms — the fork this refactor resolves fix-the-code, not fold-the-intent.
- **Current State:** Three first-party shell scripts — `skills/meta-test/scripts/run.sh`, `tests/jimconf.sh`, `tests/jimfile.sh` — rely on `testlib.sh`'s `set -uo pipefail` reached through `source` rather than setting it themselves, leaving a ~1-line window (the `HERE=$(…)` assignment) that runs before the preamble is active. They are the sole holdouts: 12 of 13 `skills/*/scripts/*.sh`, 8 of 10 `tests/*.sh`, the top-level `scripts/*.sh`, and the meta-test scaffold template (`assets/test-file.sh.tmpl`) all set it directly. The invariant row is absent from platform's blueprint.
- **Desired State:** Every first-party shell script sets `set -uo pipefail` as its own first executable line, matching the scaffold template and the existing majority. The `script-preamble` invariant is restored to platform's `000-blueprint` Invariants table with a `judge` check and the withhold note removed. A deterministic test in platform's meta-test suite asserts the preamble across all first-party shell scripts, so any future non-conforming script fails in the normal build/test loop rather than waiting on a `/jim:verify` run.
- **Affected Systems:** `skills/meta-test/scripts/run.sh`, `tests/jimconf.sh`, `tests/jimfile.sh`; the platform test suite under `tests/`; platform's `000-blueprint/spec.md` Invariants table.

## Acceptance Criteria
- [ ] Every first-party shell script (under `skills/*/scripts/`, `tests/`, and `scripts/`) sets `set -uo pipefail` as its own first executable line — including the three that currently inherit it via `source` (`skills/meta-test/scripts/run.sh`, `tests/jimconf.sh`, `tests/jimfile.sh`).
- [ ] A deterministic test in platform's meta-test suite fails when any first-party shell script omits a directly-set `set -uo pipefail`.
- [ ] The `script-preamble` invariant row is present in platform's `000-blueprint/spec.md` Invariants table with `Check: judge`, and the withhold note that deferred it to an issue is removed.
- [ ] Issue #99 is closed as resolved.
- [ ] Existing tests pass without modification.

## Out of Scope
- Extending `jimverify.sh`'s mechanical floor with a universal per-file (`must-each`) polarity so the invariant could verify as a `pattern` check — a blueprint-group engine change that generalizes across a class of for-all-files invariants; filed as a follow-on issue, not part of this platform fix.
- The `export LC_ALL=C` clause of the invariant — unchanged. The locale-sensitive scripts already export it and the three target files do not need it.
- The retired `docs/specs/jim/000-blueprint` copy of this invariant — its cleanup rides with the retired-group end-of-life issue (#106), not here.
- Any change to the three scripts beyond adding the preamble line (no reformatting, no logic edits).

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the architect — not requirements, not exclusions. Treat each as a starting point to evaluate, not a directive.*

### Insight 1: the blueprint mechanical floor cannot express "every script sets X"

- **Relates to AC:** *"a deterministic test fails when any first-party shell script omits the preamble"* (the mechanical-guard AC).
- **Surfaced as:** the request to restore the invariant "ideally as a mechanical pattern check."
- **Levelled-up requirement (already in the ACs):** the invariant is deterministically guarded across all first-party shell scripts.
- **Deflection reason:** Constraint-Sourcing — a hard limit of the verify grammar, not a preference.
- **Architect note:** `jimverify.sh`'s `check_pattern` with `polarity=must` is existential (holds as soon as the regex matches anywhere in scope — `n > 0`); `must-not` is the only universal polarity, and grep is line-oriented, so no floor `pattern` can assert a per-file property like "the first executable line is `set -uo pipefail`." `count=N` is brittle (breaks on any script add/remove or a comment mentioning the string). Hence the restored row is `judge` and the real teeth are a bash test. The test's home is a plan decision — a new `tests/<name>.sh` (script-hygiene) vs a case in an existing file; scaffold via `/jim:meta-test scaffold`. The sweep is intentionally project-wide (it may include another group's scripts such as top-level `scripts/`): platform is the documented check-holder for project-wide script rules, consistent with how `no-third-party-deps` is framed. The test asserts a directly-set preamble (not one reached via `source`), matching the invariant's "sets" wording.
- **Routing hint:** Architect to decide the test's file home and the exact first-executable-line matcher.

## Open Questions
- [x] ~Should the restored invariant be a mechanical blueprint `pattern` check?~ → No — the floor's `must` is existential and cannot express a per-file property; restored as `judge`, guarded by a deterministic test in platform's suite.
- [x] ~Fix the code or fold the intent?~ → Fix the code; the direct-set preamble is jim's house style (scaffold template + the existing majority).
