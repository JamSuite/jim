#!/usr/bin/env bash
#
# tests/gatepresentation.sh — Tests for the spec-040 gate-presentation rule wiring
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# HOW TO RUN
#   bash tests/gatepresentation.sh              # every case in this file
#   bash skills/meta-test/scripts/run.sh        # this file alongside every other tests/*.sh
#
# Unlike sibling test files there is no script under test: the invariant is a
# *textual* one over jim's skill/reference prose (spec 040 AC 6). Every
# blueprint-surface approval gate must reference the one canonical
# gate-presentation rule. A bare presence check would pass even if one of
# blueprint/SKILL.md's six inline gate pointers were dropped, so each file is
# asserted against an expected *minimum count* (sec Finding 4).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

RULE_DOC="$REPO_ROOT/skills/blueprint/references/gate-presentation.md"
TOKEN="skills/blueprint/references/gate-presentation.md"

# token_count <abs-file>
#   Print how many times the reference token appears in the file (0 if absent).
#   Fixed-string match so the path's dots are literal.
token_count() {
  grep -oF "$TOKEN" "$1" 2>/dev/null | wc -l | tr -d ' '
}

# ─── Section: Test cases ─────────────────────────────────────────────────────

# AC 3 / AC 6: every enumerated gate-site file references the rule at least the
# expected number of times. blueprint/SKILL.md carries one inline pointer per
# gate (six), so a single dropped pointer fails this case (sec Finding 4).
case_gatepresentation_sites_reference_rule() {
  # "<repo-relative file>\t<minimum expected count>"
  local rows=(
    "skills/blueprint/SKILL.md	7"
    "skills/blueprint/references/fork-grounding.md	1"
    "skills/blueprint/references/reconcile-methodology.md	1"
    "skills/blueprint/references/map-methodology.md	2"
    "skills/partition/SKILL.md	2"
    "skills/meta-skill/SKILL.md	1"
    "skills/meta-agent/SKILL.md	1"
  )
  local row rel min cnt ok
  for row in "${rows[@]}"; do
    rel="${row%%$'\t'*}"
    min="${row##*$'\t'}"
    cnt="$(token_count "$REPO_ROOT/$rel")"
    ok="no"; [[ "$cnt" -ge "$min" ]] && ok="yes"
    assert_eq "$rel references rule (need >= $min, got $cnt)" "yes" "$ok"
  done
}

# AC 1 / AC 2: the single canonical rule doc exists and carries its four
# load-bearing sections — the definition every site points at.
case_gatepresentation_rule_doc_structure() {
  local exists="no"; [[ -f "$RULE_DOC" ]] && exists="yes"
  assert_eq "rule doc exists" "yes" "$exists"
  [[ "$exists" == "yes" ]] || return

  local body; body="$(cat "$RULE_DOC")"
  assert_match "has '## Every gate' section"           '^## Every gate'          "$body"
  assert_match "has '## When content exceeds' section" '^## When content exceeds' "$body"
  assert_match "has '## On decline' section"           '^## On decline'          "$body"
  assert_match "has '## Data safety' section"          '^## Data safety'         "$body"
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
#
# Runs this file's cases only on direct invocation; when the aggregate runner
# sources us, BASH_SOURCE[0] != $0 and this stays silent. See the sibling test
# files' tail for why this shape must not be "tidied".
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  FILTER="${1:-}"
  run_discovered_cases
fi
