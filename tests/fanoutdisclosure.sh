#!/usr/bin/env bash
#
# tests/fanoutdisclosure.sh — Textual-invariant test for the fan-out disclosure rule.
#
# WHAT THIS FILE DOES
#   jim's quality machinery is delegation: /jim:review fans out investigators,
#   /jim:verify fans out judges, /jim:partition fans out gatherers, and
#   /jim:issue insights runs wholly inside the analyst. When the Agent tool is
#   withheld, each of those degrades into the orchestrator's own unaided reading —
#   and the failure that matters is not the thinner reading, it is that the
#   artifact looks identical to a run that fanned out and found nothing.
#
#   So each delegating surface must disclose an undispatched fan-out, and the two
#   surfaces that record durable counters must carry the `undelegated=` key. There
#   is no single script under test; the invariant is a textual one over the skill,
#   agent, and operator-doc corpus, in the shape tests/gatepresentation.sh uses
#   for the gate-presentation rule.
#
#   The counters case sweeps by RULE rather than by site: every recitation of a
#   `verify finished` / `review finished` event anywhere in the corpus must carry
#   the key, so a NEW recitation added later without it fails here rather than
#   shipping a counter-less event. Pinning the known sites would not catch that —
#   a contract names a site, and a site is not a class.
#
#   Fail-closed throughout: each sweep asserts a non-empty corpus and a minimum
#   recitation count, so a mis-resolved $REPO_ROOT or a future reorg fails loudly
#   instead of passing vacuously over zero files.
#
# HOW TO RUN
#   bash tests/fanoutdisclosure.sh         # standalone
#   bash skills/meta-test/scripts/run.sh   # via the aggregate runner
#
# CONVENTIONS: see skills/meta-test/scripts/testlib.sh header.
#

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$HERE/../skills/meta-test/scripts" && pwd)/testlib.sh"

# ─── Section: Helpers ────────────────────────────────────────────────────────

# corpus — echo every doc surface that may recite a stage event: skill bodies,
#   their references and assets, and the agent definitions that mirror them.
corpus() {
  local f
  for f in "$REPO_ROOT"/skills/*/SKILL.md \
           "$REPO_ROOT"/skills/*/references/*.md \
           "$REPO_ROOT"/skills/*/assets/*.md \
           "$REPO_ROOT"/agents/*.md; do
    [[ -e "$f" ]] && printf '%s\n' "$f"
  done
}

# recitations — echo every corpus line reciting a finished stage event that
#   carries counters. The trailing space excludes prose naming the event without
#   spelling the command out.
recitations() {
  local files=()
  while IFS= read -r f; do files+=("$f"); done < <(corpus)
  [[ "${#files[@]}" -gt 0 ]] || return 0
  grep -h -e 'verify finished ' -e 'review finished ' "${files[@]}" 2>/dev/null
}

# token_lines <file> <token> — count lines in <file> containing <token>.
token_lines() { grep -c -- "$2" "$1" 2>/dev/null || printf '0'; }

# exists <path> — "yes" when the path exists, else "no".
exists() { [[ -e "$1" ]] && echo yes || echo no; }

# ─── Section: Test cases ─────────────────────────────────────────────────────

# AC: every recitation of a counter-bearing `verify finished` / `review finished`
# event carries the `undelegated=` key, so a suppressed fan-out stays legible from
# the durable record and not only from the report prose. Swept by rule, not by
# site: a new recitation added anywhere in the corpus is covered automatically.
case_fanoutdisclosure_finished_events_carry_counter() {
  local all missing enough
  all="$(recitations | grep -c '')"
  missing="$(recitations | grep -cv 'undelegated=')"

  # Fail-closed: the corpus really does hold the recitations this case exists
  # for. A zero here means the sweep broke, not that the rule holds.
  enough="no"; [[ "$all" -ge 8 ]] && enough="yes"
  assert_eq "corpus holds the known recitations (need >= 8, got $all)" "yes" "$enough"
  assert_eq "every finished-event recitation carries undelegated=" "0" "$missing"
}

# AC: every surface whose contract rests on delegated independent judgment
# discloses an undispatched fan-out. Each row pins that file's own remedy
# vocabulary at a minimum line count, so dropping one statement fails here rather
# than silently narrowing the rule to whichever surfaces kept theirs.
case_fanoutdisclosure_delegating_surfaces_disclose() {
  # "<repo-relative file>\t<token>\t<minimum expected line count>"
  local rows=(
    "skills/verify/SKILL.md	undelegated	10"
    "skills/verify/references/contracts-methodology.md	undelegated	4"
    "skills/verify/references/retirement-methodology.md	undelegated	5"
    "skills/review/SKILL.md	undelegated	7"
    "skills/review/assets/review-template.md	NONE DISPATCHED	2"
    "agents/reviewer.md	undelegated	2"
    "skills/partition/SKILL.md	cannot be dispatched	1"
    "skills/issue/SKILL.md	cannot be dispatched	1"
    "WORKFLOW.md	undelegated	2"
    "README.md	undelegated	2"
  )
  local row rel token min cnt ok
  for row in "${rows[@]}"; do
    rel="${row%%$'\t'*}"
    token="${row#*$'\t'}"; token="${token%$'\t'*}"
    min="${row##*$'\t'}"
    assert_eq "$rel exists" "yes" "$(exists "$REPO_ROOT/$rel")"
    cnt="$(token_lines "$REPO_ROOT/$rel" "$token")"
    ok="no"; [[ "$cnt" -ge "$min" ]] && ok="yes"
    assert_eq "$rel discloses via '$token' (need >= $min, got $cnt)" "yes" "$ok"
  done
}

# AC: the standing-authorization phrase carries one spelling across both operator
# docs. It is the user's actual mitigation, so a reworded second copy would leave
# one doc teaching a phrase the other no longer matches.
case_fanoutdisclosure_authorization_phrase_single_spelling() {
  local phrase="invoking a jim skill authorizes the agents that skill prescribes"
  local f
  for f in WORKFLOW.md README.md; do
    assert_eq "$f carries the authorization phrase" "1" "$(token_lines "$REPO_ROOT/$f" "$phrase")"
  done
}

# ─── Section: Standalone-runnable tail ───────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  FILTER="${1:-}"
  run_discovered_cases
fi
