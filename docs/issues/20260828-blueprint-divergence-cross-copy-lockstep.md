---
id: 20260828-blueprint-divergence-cross-copy-lockstep
num: 411
title: "Blueprint divergence: cross-copy-lockstep"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [000-blueprint, drift]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-28T11:55:11Z
updated: 2026-08-28T20:25:46Z
origin: "docs/specs/issue/015-epic-authoring-and-views"
---

## Description

resolved: fix the code

The invariant stands. `skills/issue/scripts/resolve.sh`'s header declares
itself "the single definition of what an ordinal, an exact slug or a slug
prefix resolves to on a write path", but `transition.sh` keeps its own
`resolve_slug()` (`transition.sh:125-156`) implementing the same three-branch
ladder, and uses it for the primary `<id>` operand. `resolve.sh` is invoked
only for the `<umbrella>` operand (`transition.sh:367`) and by the emitter's
`--part-of` (`new.sh:274`).

## Why this breaches the invariant

Neither copy carries a sync marker, and no fixture compares them. That is the
exception in this territory rather than the rule — every other duplicated
guard is both marked and test-enforced:

- `is_valid_id` — marked, three copies, diffed by a test in the platform group's
  own file.
- the timestamp-shape pattern — marked by shared pattern, three sites, diffed.
- `place_valid_branch` / `alloc_valid_branch` — marked on both sides, diffed.
- `place_handle_root`'s containment check — a *declared* asymmetry: the marker
  states the one deliberate difference, so intent never reads as drift.
- `need_operand` — likewise declared not-identical, with the reason.

The reference ladder is the only unmarked, untested duplicate.

## The divergence is real, and currently masked

`resolve.sh:103-110` distinguishes no-match ("no issue matches that reference")
from multiple-match ("that reference matches more than one issue") on stderr.
`resolve_slug` collapses both to a bare `return 1`.

Externally the two currently agree, but only by accident: both of `resolve.sh`'s
callers redirect its stderr to `/dev/null` and substitute a generic message of
their own. Nothing enforces that coincidence, and a future edit to either
ladder diverges silently.

## The decision this needs

Not a typo — a design fork, and it should be settled rather than patched:

- **Either** `transition.sh`'s primary id delegates to `resolve.sh` too, and the
  header's claim becomes true; the callers' stderr suppression can then be
  revisited so the finer refusal reaches the developer.
- **Or** `resolve.sh`'s header stops claiming to be the single definition, and
  both copies gain a marker declaring the asymmetry and its reason — the shape
  `place_handle_root` and `need_operand` already use.

Either way the outcome is a marker plus a test, which is what the invariant
asks for.

## Also noted

`frontmatter()` / `fm_field()` are triplicated across `resolve.sh:55-63`,
`transition.sh:97-105` and `migrate.sh:442-450`, unmarked. They are currently
byte-identical, so this is not a breach today — but it is the same shape one
edit away from being one.

## Resolution

Fixed in `414fc3b4`. The fork was settled the first way: `transition.sh`'s
primary `<id>` now resolves through `resolve.sh`, so the header's
single-definition claim is true rather than annotated.

Delegating removed rather than marked. `resolve_slug` is gone, and so are both
open-coded validate blocks around it — `resolve.sh` already gates the supplied
reference before composing a path and the resolved basename afterwards, which
was the whole of what those blocks did. `INDEX_FILENAME` went with them, having
had no other reader. The `join` nesting check now reads the kind that comes
back with the slug instead of re-opening the file, so both records in that
refusal are read one way.

**The masked divergence is now observable, which was the point.** Neither
caller suppresses `resolve.sh`'s stderr any more, so a reference matching
nothing and one matching several give different reasons. The line each caller
keeps names only which operand failed — the one thing `resolve.sh` cannot know
on a verb taking two references. The refusal strings carry neither the
reference nor any issue content, so nothing that was withheld before is
disclosed now.

**One deliberate departure from "delegate everything".** The cheap
`jimfile.sh valid-id` call ahead of the placement door stays. It is not a
second definition — it is one call to the shared validator — and it is
load-bearing: the group blueprint states as a `transition.sh` guarantee that
*the id clears the validator and the outcome clears its enum before the
placement door opens*. Delegating it would have moved the check behind the
door and broken a published guarantee to buy nothing. Commented in place as a
fail-fast so it does not read as the duplication returning.

**Pinned by two cases** in `tests/issues.sh`:
`case_transition_resolves_its_id_through_the_shared_definition` asserts the
ambiguous and absent refusals are distinguishable, and
`case_transition_and_capture_refuse_a_reference_alike` drives one collection
from both write paths. The first was mutation-verified: re-suppressing the
stderr on the primary operand turns it red on exactly those two assertions.

**No blueprint edit was needed**, and that is the correct outcome for a
divergence resolved *fix the code*. The map already described `resolve.sh` as
shared by the capture and lifecycle surfaces; that sentence was the false one,
and the fix made it true.

**Not addressed, and still true as filed:** `frontmatter()` / `fm_field()`
remain triplicated across `resolve.sh`, `transition.sh` and `migrate.sh`,
unmarked and byte-identical. This record judged that not a breach today, and
nothing here changed it either way.
