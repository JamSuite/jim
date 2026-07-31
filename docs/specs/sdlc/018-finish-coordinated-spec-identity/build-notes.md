---
spec: "docs/specs/sdlc/018-finish-coordinated-spec-identity/spec.md"
status: Active
date: "2026-07-31"
---

# Build Notes: Finish coordinated spec identity

## Suite

954 passing, 0 failing (`bash skills/meta-test/scripts/run.sh`) — the 903-case
baseline at `8c2ae74` plus 51 fixtures added by this build.

## Pre-existing fixture modifications: none

`git diff 457d2ff..HEAD -- tests/` is **928 insertions, 0 deletions** across all
four touched test files. No pre-existing fixture was edited, weakened, or
removed; every one passes unchanged against the corrected code.

This is the strongest form of `sdlc/018` AC 17 and it corroborates
`sdlc/017`'s review conclusion directly: the suite was silent about eight
defects **by omission**, not because it encoded the wrong behavior. Nothing had
to be un-taught — only taught.

Two places the plan predicted a modification that turned out to be unnecessary:

- **Fold contract (task 7).** The plan expected the two raw-group callers at
  `tests/jimalloc.sh` to need pre-resolution once `alloc_fold_max_spec` stopped
  resolving its argument. Their fixture logs carry no `group rename` record, so
  raw and resolved are the same token there and both callers were already
  contract-conforming.
- **`ordinal_holder` removal (task 4).** No fixture called the spec realizer's
  local predicate directly, so replacing it with the shared `jimfile.sh` verb
  changed no test surface.

## Evidence map — `sdlc/017` acceptance criteria to fixtures

`sdlc/018` AC 1 requires each of `017`'s executable criteria to be evidenced by
at least one fixture. Fixtures marked **new** were added by this build; the rest
were already present and still pass.

| `017` AC | Evidenced by |
| :--- | :--- |
| 1 — identity resolves through the allocator, reserved before the write; no file on failed reservation | `case_specreconcile_apply_still_offline`; `case_jimalloc_allocate_spec_local_distinct`, `case_jimalloc_reconcile_spec_apply_publishes_durably`; judged holding at the `spec-id-sequencing` clause-1 rung (`/jim:verify sdlc`, this build) |
| 2 — concurrent specs never share an ordinal | `case_jimalloc_origin_race_distinct` and `case_jimalloc_origin_cross_clone_distinct`; **new** `case_jimalloc_next_id_spec_reused_group_name`, **new** `case_jimalloc_realize_spec_reused_group_name` — the reused-name log where both read paths previously offered an ordinal the current group already held |
| 3 — guarantee tier follows reachability | `case_jimalloc_allocate_spec_local_distinct` (no-remote tier), `case_jimalloc_origin_cross_clone_distinct` (reachable-remote tier); `case_specreconcile_apply_still_offline` (unreachable tier) |
| 4 — a preview reserves nothing; a shifted preview never survives binding | `case_jimfile_mv_spec_id_absorbs_ordinal_shift`; **new** `case_jimfile_mv_spec_id_excludes_its_own_source` — the `018-wip → 018-name` self-exclusion that keeps the shift absorbable now that occupancy is enforced inside the primitive |
| 5 — provisional identity is structurally distinct, downstream stages run unchanged, no real ordinal consumed | **new** `case_jimfile_path_spec_provisional_form` and **new** `case_jimfile_path_spec_two_arg_is_provisional_only` — the provisional path shape, which had no fixture at all before this build |
| 6 — `fail` mode hard-fails with a clear message | `case_jimalloc_provisional_fail_mode_hard_fails`, `case_jimalloc_unreachable_remote_hard_fails`; the refusal message is now carried in `skills/spec/SKILL.md`'s refusal table |
| 7 — preview-then-apply realization; idempotent, resumable, never collapses two specs | `case_specreconcile_apply_idempotent`, `case_specreconcile_apply_resume_converges`, `case_jimalloc_reconcile_spec_resume_no_double_allocate`, `case_jimalloc_reconcile_spec_preview_matches_apply`; **new** `case_specreconcile_apply_resume_unpadded_record` (resume against a crafted unpadded record); **new** `case_specreconcile_two_specs_sharing_a_key_are_surfaced` — the genuine two-spec residual, where the prior fixture pre-realized the *same* directory and so proved resume rather than non-merger |
| 8 — realization works committed or uncommitted | `case_specreconcile_apply_committed`, `case_specreconcile_apply_uncommitted`; **new** `case_specreconcile_apply_partially_staged_dir` — the mixed case routing to the tracked primitive and still carrying its untracked siblings |
| 9 — durable provisional→real ledger record | `case_specreconcile_realized_event_recorded`, `case_specreconcile_realized_event_covers_batch`, `case_specreconcile_realized_event_chunks_at_boundaries`, `case_specreconcile_realized_event_omits_halted`; **new** `case_specreconcile_apply_rejected_record_is_loud` and **new** `case_specreconcile_apply_rejected_record_keeps_batch` — a rejected row is now a warning plus a failure status, where it was a silent drop at exit 0 |
| 10 — renamed-away group refused with the redirect named; terminal refusal presented as terminal | `case_jimalloc_peek_spec_group_alias_follow_redirect`, `case_jimalloc_next_id_spec_group_alias_follow_redirect`; **new** `case_jimalloc_allocate_spec_follow_redirect_end_to_end` — the redirect path exercised end to end for the first time; **new** `case_jimalloc_next_id_spec_exhaustion_emits_nothing` and **new** `case_jimalloc_realize_spec_exhaustion_emits_nothing` — terminal exhaustion, previously untested in both paths; **new** `case_specreconcile_apply_halts_on_group_rename` |
| 11 — bootstrap/integrity treats a pending provisional dir as reserved | `case_jimalloc_seed_skips_provisional_dir`, `case_jimalloc_seed_skips_provisional_only_group` |
| 12 — `/jim:spec` derives no ordinal from the tree | judged holding at the `spec-id-sequencing` clause-1 rung (`/jim:verify sdlc`, this build): the flow mints only via `peek`/`allocate`, and `allowed-tools` makes the tree-scan verb unreachable from it |
| 13 — every registry/config/tree-derived value revalidated before use as a path, git argument, or frontmatter | **new** `case_specreconcile_apply_gates_realized_ordinal` — the realized ordinal was the one token on this surface that reached all four uses ungated; **new** `case_jimfile_path_spec_validates_numeric_form`; **new** `case_jimfile_spec_ordinal_holder_rejects_bad_input`; **new** `case_specreconcile_uncommitted_sweep_refuses_escape` |
| 14 — local identity collision halts loudly, names the drift, writes nothing | `case_specreconcile_apply_halts_on_drift`; **new** `case_specreconcile_apply_halts_on_padding_variant_occupant`, **new** `case_specreconcile_apply_halts_on_bare_ordinal_occupant`, **new** `case_jimfile_mv_spec_id_refuses_held_ordinal`, **new** `case_jimfile_mv_spec_id_refuses_padding_variant_holder`, **new** `case_jimfile_mv_spec_refuses_held_ordinal` — the creation half of the halt, which had no coverage before |
| 15 — the allocator's shipped behaviors hold unchanged | the whole suite, unmodified: 0 deletions in `tests/`, and the issue-side, resolve/peek/fold, and `000-blueprint`-exclusion fixtures all pass untouched |

## Deviations from the plan

Recorded rather than silently absorbed.

### Task 20 — the `jim` blueprint fold was declined, not performed

The plan's task 20 and spec AC 13 call for folding `spec-id-sequencing` in
**both** the `sdlc` and `jim` blueprints. The `sdlc` fold was performed through
the blueprint surface (`--from-review`, violation fork answered `fold the
intent`) and is committed.

The `jim` fold was **not** performed, by developer decision during the build.
`docs/specs/jim/000-blueprint/spec.md` carries `status: retired` — the group was
split into `sdlc`/`blueprint`/`issue`/`platform`, and its blueprint is superseded
by the project context map. It is absent from the map, excluded from the
reconcile and the contract graph by construction, and has no declared territory,
so nothing consumes it. Editing it would make a superseded document look
maintained while remaining outside every mechanism that keeps documents current.
The same posture is already recorded in this spec's own Out of Scope, which
leaves the retired `jim` group's registry absence "deliberately unrepaired".

Provenance of the inclusion: `sdlc/017`'s review located the invariant by
matching its id across blueprint **files** rather than through the map, five days
after the group was retired, and reported both hits. Issue #149, the grouping
note, this spec's AC 13, its research, and the plan's task-20 Verify command each
carried the pair forward without checking `status:`. The review sensor's
file-level enumeration is the reusable defect and is filed separately.

Consequently task 20's Verify command passes on its `sdlc` half and fails on its
`jim` half by design.

### Task 20 — `/jim:verify jim` skipped

For the same reason: with `jim` absent from the map it has no territory, so the
run degrades to `UNSCOPED` — a repo-wide floor and judge fan-out scoring a
superseded document. Skipped by decision.

### AC 13's second clause is not met as worded

AC 13 requires that after the fold, "a `/jim:verify` pass of each group scores
the invariant as holding". The `/jim:verify sdlc` run (recorded at
`docs/specs/sdlc/000-blueprint/ledger.md`, committed `b4f7a16`) scored
`spec-id-sequencing` **partial → violated**.

The fold itself succeeded: the invariant's two identity clauses — allocator-minted
rather than tree-derived, and both identity states admitted — were each judged
holding with converging evidence. The `partial` comes from the row's third clause,
"a spec must be `approved` before its plan is produced", which `/jim:plan`
enforces as a one-value blacklist (`draft` stops; `deprecated` or a missing
status matches no row and is not stopped before `plan.md` is written). That defect
predates this build, is unrelated to spec identity, and the fold could not have
fixed it. Filed as issue #167.

### `/jim:verify sdlc` surfaced seven further pre-existing partials

None introduced by this build. Filed as #161–#166 plus #167 above; the
`untrusted-content` partial was already open as #53 and was not re-filed. The
full run report is reproduced in the ledger event
(`checked=12 holds=2 violated=8 failed=0 unconfigured=1 skipped=1`).

### One AC 14 site beyond the plan's enumeration

The plan named four self-contradictions in `skills/spec/SKILL.md`. A fifth — the
skill's own one-line summary of the path it writes — carried the same numeric-id
framing and was corrected in the same file (`f5e34eb`). The equivalent framing in
`agents/*.md` context blocks was left alone: those files are outside the plan's
File Manifest, and the judge that flagged them ruled the skill bodies govern.
Routed to the end-of-build candidate batch instead.
