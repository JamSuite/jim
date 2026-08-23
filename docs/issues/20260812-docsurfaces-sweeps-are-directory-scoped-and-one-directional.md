---
id: 20260812-docsurfaces-sweeps-are-directory-scoped-and-one-directional
num: 330
title: "docsurfaces sweeps are directory-scoped and one-directional"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [test, docsurfaces]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T21:53:46Z
updated: 2026-08-12T21:53:46Z
origin: "docs/specs/issue/011-issue-placement/review.md"
---

## Description

The doc-surface sweeps that hold the candidate-batch contract are weaker than
they read. Three defects, all in `tests/docsurfaces.sh`.

## 1. The `--reviewed` sweep is directory-scoped

`tests/docsurfaces.sh:257` — `case_docsurfaces_interactive_paths_declare_reviewed`
uses:

    grep -rq -- 'new\.sh --reviewed' "$(dirname "$f")"

That is file/directory-scoped in exactly the way its own sibling's comment
(`:270-274`) argues is inadequate. A consumer whose interactive path called the
bare emitter — or passed `--auto` — still passes, so long as `--reviewed` appears
anywhere under its directory, including in prose or a `references/` doc.

The auto-file sibling at `:281` correctly scopes to the branch. This one should
too: assert `--reviewed` inside the region after the `INTERACTIVE PATH` marker.

## 2. The fallback-target assertion is near-tautological

`tests/docsurfaces.sh:289` greps the **whole file** for the same literal that
terminates the `sed` range extracting `branch` at `:281`. Since the terminator
*is* `INTERACTIVE PATH`, a well-formed file satisfies it by construction. It can
only fire when the string appears nowhere — precisely the shape where the range
degenerates to EOF and simultaneously weakens the `--auto` and `exit code 4`
assertions above it. It asserts nothing about the fallback being reachable *from*
the rc-4 refusal.

The third review called this tautological; the round addressed it nominally.
Replace with `after="$(sed -n '/INTERACTIVE PATH/,$p' "$f")"` and assert
`new.sh --reviewed` appears in `$after`.

## 3. The roster sweep is one-directional, on a hardcoded floor

`case_docsurfaces_candidate_batch_roster_matches_the_grant` (`:195-215`) derives
the consumer set from `grep -l 'scripts/new\.sh \*' skills/*/SKILL.md` and requires
§ 7a to name each. That direction is genuine — a 12th consumer raises `n` and lands
in `missing` unless § 7a names it.

But nothing checks the reverse: § 7a can name a skill that is **no longer** a
consumer, and the roster accrues stale names silently.

And the three non-vacuity floors (`:209-210`, `:259-260`, `:293-294`) are
hardcoded at exactly today's counts (`n >= 11`, `n >= 11`, `n >= 9`). The failure
mode is benign, but it relocates into the test the very defect the round removed
from prose — a count that goes stale the moment a consumer accrues. The comment at
`:291-293` names the consequence without avoiding it.

Two narrower gaps in the same file: both consumer sets derive from unanchored
literals rather than from the `allowed-tools:` line, so a prose mention counts as a
grant and a grant spelled otherwise (`new.sh:*`, `new.sh --auto *`) is invisible;
and the anti-count guard at `:213-214` matches only spelled-out numerals
(`(seven|…|twelve) surfacing skills`), so `10 surfacing skills` slips through.

## Action

1. Scope `:257` to the post-`INTERACTIVE PATH` region.
2. Replace `:289`'s whole-file grep with the scoped form above.
3. Make the roster check bidirectional — collect § 7a's `/jim:<name>` mentions and
   assert the reverse containment against the derived set.
4. Drop the three floors to `n > 0`, letting the bidirectional check carry set
   membership.
5. Anchor both derivations to `sed -n '/^allowed-tools:/p'`, and broaden the
   anti-count regex to `([0-9]+|seven|…|twenty) (surfacing skills|consumers)`.

Related, from the same review: the partition disclosure grant assertion at
`:242-243` uses `grep -oE 'place\.sh (commit|run)'`, which catches a literal
`place.sh commit` grant but not `Bash(bash …/place.sh *)` — the form every other
script in that same line is granted with. Assert positively instead: every
`place.sh` grant must be exactly one of `mode`, `begin --read`, `abort *`.
