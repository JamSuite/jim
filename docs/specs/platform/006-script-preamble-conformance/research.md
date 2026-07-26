---
spec: "spec.md"
status: Active
date: "2026-07-26"
---

# Research: Script-preamble conformance and invariant restoration

## Anchors

**Fix targets (edit — insert `set -uo pipefail` as the first executable line, before the existing `HERE=`):**
- `skills/meta-test/scripts/run.sh:48-49` — computes `HERE=` then `source testlib.sh`; only a *commented* occurrence exists at `:34`.
- `tests/jimconf.sh:16-17` — `HERE=` / `source testlib.sh`.
- `tests/jimfile.sh:17-18` — `HERE=` / `source testlib.sh`.

**Preamble source-of-truth (do not edit):**
- `skills/meta-test/scripts/testlib.sh:64` — the `set -uo pipefail` the 3 holdouts currently inherit through `source`.
- `skills/meta-test/assets/test-file.sh.tmpl:12` — canonical *direct-set* position; ordering is `set` (12) → `HERE=` (14) → `source` (15). New files already conform.

**New guard test (create):**
- `tests/<name>.sh` (e.g. `tests/scripthygiene.sh`) — auto-discovered by run.sh's `tests/*.sh` glob (`run.sh:53-56`); **no registration** — a `case_*` function in the conventional shape is enough.

**Blueprint restore (edit `docs/specs/platform/000-blueprint/spec.md`):**
- Insert the `script-preamble` row between `no-source-eval` (`:93`) and `bash-source-relative` (`:94`) — the ordering the retired `jim/000-blueprint` used.
- Delete the withhold paragraph `:105-108`.
- Leave the `verify-checks` fence `:101-103` untouched (it belongs to `no-third-party-deps`).

**Issue closure:** `docs/issues/20260725-script-preamble-rule-vs-source-inherited-preambles-fix-or-fold.md` (#99).

## Local Patterns

- **Test framework (`skills/meta-test/scripts/testlib.sh`).** Assertion helpers: `assert_eq` (`:101`), `assert_match` (`:115`), `assert_exit` (`:128`), `assert_nonempty` (`:141`) — each sets `CURRENT_FAILED=1` and prints an indented detail line on failure. Discovery is by `case_*` naming via `run_discovered_cases` (`:187-214`, `declare -F | awk '/case_/'`); there is **no** `TESTS=()` registration array. Each test file owns its own `run_*` invoker capturing `OUT`/`ERR`/`RC` (globals at `:83-85`); the sweep test needs no invoker (it greps files, not a script-under-test).
- **Canonical test-file shape** — `assets/test-file.sh.tmpl`: shebang (`:1`), `set -uo pipefail` (`:12`), `HERE=` (`:14`), `source testlib.sh` (`:15`), standalone-runnable tail `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then … run_discovered_cases; fi` (`:58-64`). Scaffold with `/jim:meta-test scaffold <name>`.
- **Cross-file assertion idiom** — best template is `tests/gatepresentation.sh:38-57` (`case_gatepresentation_sites_reference_rule`): loops a list, asserts a per-file textual property, and **embeds the failing file path in the `assert_eq` label** so the reporter names the offender. Companions: `tests/presenttense.sh:45-60`, `tests/provenance.sh:77-92`. **Caveat:** all three enumerate a *hardcoded* `rows=(…)` array — none does a filesystem glob sweep. The file enumeration (`for f in skills/*/scripts/*.sh tests/*.sh scripts/*.sh`) is new for this test; only the reporting idiom is reused.
- **Conforming set:** 24 first-party `*.sh` files across `skills/*/scripts/`, `tests/`, `scripts/`; 21 already set the preamble directly (e.g. `scripts/jim-deps-refs.sh:33`, `skills/conf/scripts/jimconf.sh:37`, `tests/metatest.sh:17`). The 3 holdouts above are the complete violation set (confirmed).

## Security & Performance

- **Correctness trap — the highest-risk detail.** A naive `grep -q 'set -uo pipefail' "$f"` **false-passes `run.sh`** (its only occurrence is the comment at `:34`) and any file that merely mentions the string in prose/comments. The guard **must** match an *anchored* line — `^[[:space:]]*set -uo pipefail` — and ideally evaluate it as the first non-comment/non-blank executable line, not a substring. Getting this wrong makes the test green while the invariant is violated.
- **Behavior-neutral fix.** Adding `set -uo pipefail` (no `-e`) to the 3 files matches what `testlib.sh` already sets after the `source`, so the `OUT=$(…)` capture pattern is unaffected. The only new effect is `-u`/pipefail over the ~1-line `HERE=` window; it references `${BASH_SOURCE[0]}` (always set), so `-u` cannot trip. No network, no untrusted input, no perf concern (a 24-file grep is trivial).

## Recommendations

*(Options for the architect — not decisions.)*

1. **Matcher strictness.** (i) *First non-comment/non-blank line equals `set -uo pipefail`* — faithful to the AC wording ("first executable line"); all 24 conforming files satisfy it. (ii) *An anchored `^set -uo pipefail` line exists* — simpler, still catches all 3 holdouts. **Prefer (i)**; under either, never substring-match (see Security). This is the one decision the plan must pin.
2. **Sharpen the restored invariant wording** to foreclose the exact regression: *"Every script sets `set -uo pipefail` **directly (not solely via a sourced framework)**; locale-sensitive scripts also `export LC_ALL=C` (project-wide script rule)"* — the parenthetical mirrors the `no-source-eval` / `bash-source-relative` neighbors and names platform as the check-holder.
3. **Test home:** a single-purpose `tests/scripthygiene.sh` over folding into `tests/metatest.sh` (which tests a script-under-test, a different shape).
4. **Sweep scope includes top-level `scripts/`** (blueprint territory): platform is the documented check-holder for project-wide script rules (`000-blueprint/spec.md:92`, "the rule binds every group's scripts, platform holds the check"), so a project-wide sweep is correct, not a territory reach.

**Alignment.** Consistent with jim's executable-institutional-memory pillar — restoring a withheld invariant so the blueprint's recorded intent matches the code — and with the mechanical-over-judgment posture (a deterministic guard in the build loop). Follows `CLAUDE.md → Bash scripts` (`set -uo pipefail`, **not** `set -e`) and the testlib conventions. No divergence from VISION.md or ARCHITECTURE.md.
