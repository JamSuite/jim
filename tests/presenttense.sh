#!/usr/bin/env bash
#
# tests/presenttense.sh — Tests for the present-tense discipline wiring (spec 050)
#
# Conventions: see skills/meta-test/scripts/testlib.sh header (canonical).
#
# HOW TO RUN
#   bash tests/presenttense.sh                  # every case in this file
#   bash skills/meta-test/scripts/run.sh        # this file alongside every other tests/*.sh
#
# Unlike sibling test files there is no script under test: the invariant is a
# *textual* one over jim's blueprint skill/reference prose. Every blueprint
# composition site that ingests supplied text must reference the one canonical
# present-tense rule, so the discipline stays single-sourced rather than
# restated per site. A bare presence check would pass even if one of a file's
# per-site pointers were dropped, so each file is asserted against an expected
# *minimum count* (mirrors tests/gatepresentation.sh).
#
# The aggregate runner sources every tests/*.sh into one shell, so file-level
# identifiers must be unique across files (testlib.sh header, "Design contract").
# These globals and the helper carry a PT_ / pt_ prefix so they never collide
# with a sibling file's own TOKEN / RULE_DOC (e.g. tests/gatepresentation.sh).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

PT_RULE_DOC="$REPO_ROOT/skills/blueprint/references/present-tense.md"
PT_TOKEN="skills/blueprint/references/present-tense.md"

# pt_token_count <abs-file>
#   Print how many times the reference token appears in the file (0 if absent).
#   Fixed-string match so the path's dots are literal.
pt_token_count() {
  grep -oF "$PT_TOKEN" "$1" 2>/dev/null | wc -l | tr -d ' '
}

# ─── Section: Test cases ─────────────────────────────────────────────────────

# AC: the discipline is single-sourced and referenced (not restated) at each
# composition site, and a dropped or missing citation is caught mechanically.
# Each file carries one pointer per exit door it wires, so a single dropped
# pointer drops the count below its minimum and fails this case.
case_presenttense_sites_reference_rule() {
  # "<repo-relative file>\t<minimum expected count>"
  local rows=(
    "skills/blueprint/SKILL.md	5"
    "skills/blueprint/references/map-methodology.md	2"
    "skills/blueprint/references/migrate-arms.md	3"
  )
  local row rel min cnt ok
  for row in "${rows[@]}"; do
    rel="${row%%$'\t'*}"
    min="${row##*$'\t'}"
    cnt="$(pt_token_count "$REPO_ROOT/$rel")"
    ok="no"; [[ "$cnt" -ge "$min" ]] && ok="yes"
    assert_eq "$rel references rule (need >= $min, got $cnt)" "yes" "$ok"
  done
}

# AC: the rule, the three marker categories, and the normalize-and-disclose
# contract are defined in a single canonical location — the doc every site
# points at, carrying its four load-bearing sections.
case_presenttense_rule_doc_structure() {
  local exists="no"; [[ -f "$PT_RULE_DOC" ]] && exists="yes"
  assert_eq "rule doc exists" "yes" "$exists"
  [[ "$exists" == "yes" ]] || return

  local body; body="$(cat "$PT_RULE_DOC")"
  assert_match "has '## The rule' section"                '^## The rule'                "$body"
  assert_match "has '## Normalize and disclose' section"  '^## Normalize and disclose'  "$body"
  assert_match "has '## Untrusted supplied text' section" '^## Untrusted supplied text' "$body"
  assert_match "has '## Where it runs' section"           '^## Where it runs'           "$body"
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
