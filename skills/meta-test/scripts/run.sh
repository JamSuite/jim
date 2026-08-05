#!/usr/bin/env bash
#
# skills/meta-test/scripts/run.sh — Aggregate runner for jim's plain-bash test suite.
#
# WHAT THIS FILE DOES
#   Sources sibling testlib.sh, then sources every tests/*.sh in the project's
#   tests/ directory (each of which defines `case_*` functions for one
#   script-under-test), then runs all discovered cases through the shared
#   reporter.
#
# HOW TO RUN
#   bash skills/meta-test/scripts/run.sh             # every case, every test file
#   bash skills/meta-test/scripts/run.sh defaults    # only cases whose name contains "defaults"
#   bash skills/meta-test/scripts/run.sh jimfile     # only the jimfile cases (substring match)
#
#   You can also use /jim:meta-test run [pattern] which wraps this script.
#
# Per-script test files are also runnable on their own from the repo root:
#   bash tests/jimconf.sh             # only jimconf cases
#   bash tests/jimfile.sh             # only jimfile cases
#   bash tests/metatest.sh            # only metatest cases
#
# WORKING DIRECTORY
#   Invoke from the repo root. The test-file glob is `tests/*.sh` (PWD-relative).
#
# EXIT CODE SEMANTICS
#   0   every selected test passed
#   1   at least one test failed
#   2   runner setup error (mkdir/mktemp failure during testlib sourcing)
#
# HOW TO ADD A NEW TEST FILE  (use /jim:meta-test scaffold <name>, or by hand:)
#   1. Create `tests/<name>.sh`. First content lines:
#        #!/usr/bin/env bash
#        set -uo pipefail
#        HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#        source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"
#   2. Define a per-script invoker (`run_<name>() { ... }`) and your
#      `case_<name>_*` functions. Each case begins with a `# AC: <spec
#      acceptance criterion>` comment.
#   3. Add a standalone-runnable tail:
#        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#          FILTER="${1:-}"
#          run_discovered_cases
#        fi
#      Then `chmod +x tests/<name>.sh`. This runner picks it up automatically.
#

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/testlib.sh"

FILTER="${1:-}"

# PWD-relative, and deliberately so — do NOT anchor this at REPO_ROOT. Two
# independent reasons, either one sufficient:
#
#   1. REPO_ROOT is the PLUGIN's root, resolved BASH_SOURCE-relative. Installed
#      as a plugin, an anchored glob would discover and run jim's own tests
#      instead of the tests of the project the developer is standing in. The
#      test corpus is the consuming project's content, not the plugin's.
#   2. This runner is itself under test. tests/metatest.sh has cases that invoke
#      it from a sandbox directory, and the PWD-relative glob is what makes
#      those runs find no test files and return. Anchored, each would load
#      tests/metatest.sh and invoke the runner again, without bound.
#
# The distinction that resolves this against the BASH_SOURCE rule: that rule
# governs the plugin locating its OWN parts, which every sibling resolution here
# does. Where a path names the consuming project's content, PWD is correct.
#
# The placement rule this leaves unenforced — a test file authored outside
# tests/ is silently not run — is detected by tests/scripthygiene.sh instead,
# which sweeps for test-shaped files under the discovery roots.
for tf in tests/*.sh; do
  [[ -e "$tf" ]] || continue
  source "$tf"
done

run_discovered_cases
