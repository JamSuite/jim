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

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/testlib.sh"

FILTER="${1:-}"

for tf in tests/*.sh; do
  [[ -e "$tf" ]] || continue
  source "$tf"
done

run_discovered_cases
