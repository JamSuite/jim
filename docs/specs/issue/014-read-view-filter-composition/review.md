---
spec: "issue/014"
type: "feature"
base_sha: "88a003afec03e749a6d35d4d9232fc64cc0ff878"
head_sha: "3bbb97acb2d40e6d340d6980ceb99802c6f12df4"
commits: "25"
commits_test: "2"
commits_feat: "14"
commits_fix: "2"
commits_refactor: "0"
files_changed: "11"
insertions: "2682"
deletions: "555"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "5097"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "872"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "2915"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "3789"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "13813"
review_runs: "1"
review_interruptions: "1"
review_duration_seconds: "692"
artifacts_present: "spec,research,security,plan,ledger,context"
plan_deviations: "2"
security_regressions: "0"
invariant_violations: "2"
contract_violations: "0"
alignment: "minor-drift"
date: "2026-08-26"
---

# Review: Read-view filter composition

## Summary

**Alignment:** minor-drift · **Depth:** thorough · **Findings:** 13 · **Plan
deviations:** 2 · **Security regressions:** 0

All 21 planned tasks shipped across 25 commits, with the full suite green at
1608 tests and no scope creep. The drift is concentrated in one acceptance
criterion: the disclosure that refuses an axis the index cannot answer was built
to the plan's task text, which enumerated three axes on one verb, while the
criterion it serves is stated over every axis on both. Against an index written
before the row was widened, `list unclaimed` therefore reports a genuinely-held
record as unclaimed, and `stats --filed-by X` reports `Open: 0 · Closed: 0` —
both at status 0, which is the failure the criterion names in its own words.

## Alignment

### vs. Spec acceptance criteria

30 of 35 criteria are fully satisfied with both implementation evidence and a
named pinning test. The five below diverge or are only partly met.

- **"When a filter names an axis the collection's index does not describe, the
  view says so and fails"** — *drift.* The guard covers `type` / `filed-by` /
  `claimed-by` and lives only in `cmd_list`. The `held` axis (bare `claimed` /
  `unclaimed`) reads the same blanked `claimed-by` field and is not in the
  enumeration; `cmd_stats` has no guard at all. See Finding 1.
- **"A flag given with no value, or with a value that is another flag, is
  refused"** — *partly met.* `need_operand` refuses only this file's own option
  names, so `--label --nosuchflag` binds `--nosuchflag` as a label value. The
  plan's design decision deliberately narrowed this to "another *known* flag";
  the criterion's text is not so narrowed. See Finding 3.
- **"Values naming the same axis combine as alternatives"** — *partly met.* An
  operand that is present but effectively empty (`,,,`, whitespace-only) adds no
  alternative, leaving the axis unset — which downstream reads as "axis not
  named", so the filter matches everything. See Finding 2.
- **"A contributor value the configured form cannot judge stays reachable by
  naming it exactly"** — *partly met.* Values are whitespace-trimmed before
  reaching the axis, so a recorded identity unjudgeable *because of* edge
  whitespace cannot be named exactly. See Finding 6.
- **"An origin match is a path prefix"** — *met, with an undocumented
  dependency.* The comparison has no directory-boundary check; `--spec
  issue/011` cannot collide with a sibling only because the allocator enforces
  ordinal uniqueness and fixed-width padding. Neither invariant is stated where
  the comparison lives. See Finding 9.

### vs. Plan tasks

All 21 tasks done, none skipped, nothing shipped beyond them. Two deviations:

- **Task 6 — interface contract.** The contract specifies `FILTER_AXIS[<axis>]`
  as *space-separated* alternatives; the build used newline-separated. A space
  separator would split an `--origin` value containing a space into two
  alternatives and silently widen the query — the failure the plan's own design
  decision 8 exists to prevent. Deliberate, and flagged at the time.
- **Task 8 — incomplete replacement.** `is_filter_token` had three callers
  before the build and zero after; the task replaced its last caller without
  deleting it. See Finding 4.

### vs. ARCHITECTURE.md

Independently audited against the project's bash conventions and the plan's own
Constitution Check. Every claim verified: no third-party dependencies, `set -uo
pipefail` unchanged, nothing sourced or evaluated, every new awk program a
single-quoted literal with no shell value in its body, no untrusted value
reaching a shell command, and no spec/AC/Finding id in any comment this build
added. Two rows of the plan's Constitution Check cite the wrong task numbers
(`staleness-gated-reads` credits task 11, the work is task 13;
`insights-capability-boundary` credits task 5, the ordering is tasks 6–7) — a
plan-authoring slip, not a code defect.

The architecture document was refreshed for four passages this build
invalidated. One item research.md raised — that ARCHITECTURE.md "describes a
six-field row" needing correction — turned out to be wrong: no literal row-shape
passage exists there.

## Investigation

### High-stakes regions investigated

#### The filter grammar (`parse_filters`, `need_operand`, `filter_axis_add`, `token_safe`)
- locations examined: `render.sh:156-195`, `:199-231`, `:233-312`
- callers/consumers traced: `cmd_list:966`, `cmd_stats:506`, `named_collection:1329`
- tests checked: `tests/issues.sh:7373-7497`
- verdict: **partial** — refusal ordering is genuinely load-bearing (no argument
  reaches a filesystem operation before every argument is classified); the
  `declare -gA` reset is correct across the two in-process parses. But an
  operand that is present-yet-empty degrades its axis to a no-op rather than
  refusing. Confirmed by running: `--label ,,,` and `--label '   '` each match
  every record at status 0, against a baseline of one.

#### Routing vs. binding (`bind_collection`, `named_collection`, `dir_given`, `route_placement`)
- locations examined: `render.sh:314-335`, `:1314-1374`, `place.sh:224-263`, `:1730-1863`
- callers/consumers traced: `main:1385`, `place_substitute:1836`
- tests checked: `tests/issues.sh:7504-7607`
- verdict: **satisfied for the reviewed concern** — the security review's
  Finding 9 defect is closed: a flag's operand can no longer be read as the
  collection, a reserved word never binds one, and the re-exec cannot recurse.
  The old hide rule and the new one were compared directly at the two commits
  and agree exactly for every pre-existing invocation shape.

#### The unified graph-edge parse (`read_graph_edges`)
- locations examined: `render.sh:401-435`; call sites `:609`, `:761`, `:764`, `:1295`, `:1299`
- callers/consumers traced: every emitted slug — all reach an associative-array
  key, a string comparison, or a `printf`; none reaches a path or a file read
- tests checked: `tests/issues.sh:7328-7356`
- verdict: **satisfied** — the documented laxness relative to `is_valid_id` is
  genuinely inert here, and the widening is a strict superset for every slug
  that can exist in a current-format index.

#### The person axes (`ident_form`, `person_matches`, `resolve_person_axes`)
- locations examined: `render.sh:863-959`; `identity.sh:132-153`, `:357-436`
- callers/consumers traced: `identity.sh` now has its first read consumer
  alongside `new.sh:204`, `transition.sh:228`, `migrate.sh:490`
- tests checked: `tests/issues.sh:7817-7948`
- verdict: **satisfied, one narrow gap** — the fallback-to-literal rule was
  proved sound (a value that fails normalization can never equal a value that
  passes, so no false positive is constructible), the memoization genuinely
  bounds subprocesses to distinct values, and neither refusal carries the value
  or any issue content. The gap is upstream whitespace trimming (Finding 6).

#### The origin and derived axes (`prefix_axis`, `build_derived_axes`, `held/blocked/epic`)
- locations examined: `render.sh:711-797`, `:833-861`
- callers/consumers traced: `row_matches` from both `cmd_list:1028` and `cmd_stats:542`
- tests checked: `tests/issues.sh:8043-8082`, `:8134-8178`
- verdict: **satisfied, two untested edges** — prefix matching is literal (the
  pattern operand is quoted; a glob-shaped value matches itself), `specs_root`
  agrees across both verbs, and no filter value reaches a path. A dependency
  target absent from the collection reads as unblocked (Finding 5).

#### The rewritten `cmd_stats`
- locations examined: `render.sh:501-633`, `:815-828`; compared against `88a003a`
- callers/consumers traced: `named_dir_exists` still live for `show` / `insights-graph`
- tests checked: `tests/issues.sh:8324-8428`
- verdict: **partial** — scoping is correct and integrity warnings are
  deliberately unscoped, but moving the counts from the index's Summary lines to
  the rows introduced a divergence between the two (Finding 7), and the guard
  gap above lands hardest here.

#### The rewritten `cmd_list` (`format_row`, `disclose_hidden_closed`, the staleness guard)
- locations examined: `render.sh:637-678`, `:799-813`, `:961-1138`
- callers/consumers traced: `format_row` single call site, always 12 arguments
- tests checked: `tests/issues.sh:8185-8322`, `:7971-8001`
- verdict: **partial** — reordering the hide check cannot change which records
  appear, the sort-key indices survive the row widening, and the disclosure
  cannot double-print. The guard's axis enumeration is the divergence.

#### The index substrate (row emitter, `read_issue_rows`, its consumers)
- locations examined: `index.sh:301-303`, `:740-753`; `render.sh:350-399`
- callers/consumers traced: all five `read_issue_rows` consumers audited for
  field count; no other script in the group parses Issues rows
- tests checked: `tests/issues.sh:7176-7321`
- verdict: **satisfied** — `row_safe`'s control-character strip covers `0x0A`,
  so no value can break the one-row-per-line contract; the build's own
  consumer-widening regression case was verified to fail against the narrow
  `read` and pass against the wide one.

### Coverage

- Depth: thorough; review_model: sonnet.
- Full high-stakes set investigated. The 35 acceptance criteria were covered by
  their nine spec headings bundled into five investigators rather than one
  investigator per criterion — a deliberate bundling, not a cap effect (14
  dispatched against a cap of 20). Every criterion received a per-criterion
  verdict and a named pinning test or an explicit "NO TEST".
- investigators: 14 dispatched, 14 returned. No undelegated set.
- Two investigators noted they could not run `git show` (read-only by design),
  leaving two comparisons on inference; both were closed directly against the
  two commits by the orchestrator rather than left inferred.

## Living intent

**Sensed:** 13 invariants · **holds:** 7 · **violations:** 2 (in-change 2 ·
pre-existing 0 · unlocalized 0) · **skipped:** 4 · **failed/unconfigured:** 0

### Violations

- **placeholder-by-position** — high · violated · in-change ·
  `place.sh:253`. The wrapper recognizes `{}` as a placeholder when the
  preceding argv element is literally `--dir`, with no notion of which script's
  grammar produced it. This build made that adjacency reachable: a filter value
  may be any text, including `--dir`, and the residue slot may hold a bare
  `{}`. Reproduced end-to-end in a placement-configured repository —
  `list --label --dir '{}'` rewrote the caller's own `{}` with the run's real
  materialized collection path and leaked it onto stderr. The invariant's text
  forbids exactly this ("never an argument matching a placeholder's text
  elsewhere in the argv"). On the read path the harm is a spurious refusal and a
  leaked run-local path; `place_substitute` is shared verbatim by every entry
  script, so the class is wider than the one route.
- **staleness-gated-reads** — medium · violated · in-change ·
  `render.sh:1048-1061`. The schema-staleness disclosure exists only in
  `cmd_list` and enumerates only three of the four axes that read the blanked
  fields. Reproduced: against a pre-widening index, `list unclaimed` lists a
  genuinely-held record as unclaimed, and `stats --filed-by X` reports
  `Open: 0 · Closed: 0` — both at status 0, no stderr.

### Coverage

- appetite in force: low (no per-group or per-run override), so every invariant
  cleared the threshold and change-selection alone narrowed the judged set.
- Whole-group floor ran; territory declared. 0 strays — no `issue`-group file
  sits outside its declared territory; 922 files bucketed as other groups' code
  and project scaffolding (`docs/` 815 · `skills/` 66 · `tests/` 14 · root 14 ·
  `agents/` 11 · `scripts/` 1 · `.claude-plugin/` 1).
- judges: change-selected, 9 of 13, all within cap. 9 dispatched, 9 returned —
  no undelegated set.
- skipped by scope: 4 — `single-emitter`, `placement-gate-before-git`,
  `materialization-contained`, `collection-rewrite-preview-gated`, which govern
  `new.sh` / `place.sh` / `migrate.sh`, none of which this build touched.
  Skipped by appetite: 0.
- registry: 0 configured for this group — the blueprint records no
  `registry:` invariant, so nothing was unconfigured or unrun.

### Contracts

**Edges checked:** 1 · **holds:** 1 · **violations:** 0 (provider-side 0 ·
consumer-side 0)

- None — every checked edge holds. The graph names `issue` as provider on seven
  edges; six were unaffected (their provides entries are `new.sh`, `place.sh`,
  and SKILL.md § 7a, none of which this build touched — the SKILL.md change is
  confined to the verb-routing section). The one affected edge, `platform →
  validator-lockstep → issue`, holds: the three `is_valid_id` copies remain
  byte-identical (verified by hash across `render.sh`, `index.sh`,
  `jimfile.sh`) and their asserting test passes.

## Metrics

| Metric | Value |
| :--- | :--- |
| Commits (test / feat / fix / refactor) | 25 (2/14/2/0) |
| Files changed · insertions · deletions | 11 · +2682 · -555 |
| Stage runs (spec·research·plan·sec·build·review) | 1·1·1·2·1·1 |
| Stage durations (spec·research·plan·sec·build·review) | 5097s·872s·2915s·3789s·13813s·692s |
| Interruptions (spec·research·plan·sec·build·review) | 0·0·0·0·0·1 |
| Artifacts present | spec,research,security,plan,ledger,context |

## Security regressions

- None identified. No secret-looking value appears in the diff; no trust
  boundary was weakened; no new injection surface was introduced. Every new awk
  program is a single-quoted literal taking the index file only as a positional
  argument, every filter comparison is a quoted bash test or a quoted-prefix
  glob, and `identity.sh` receives its value as argv rather than through string
  interpolation. The one path-adjacent widening — `read_graph_edges` matching a
  laxer charset than `is_valid_id` — was traced to every consumer and reaches no
  path, file read, or command.

## Findings

### 1. The unanswerable-axis disclosure covers three axes on one verb

- **Priority:** high
- **Description:** Against an index written before the row was widened — newer
  than every issue file, so the staleness gate reuses it — `list unclaimed`
  reports a genuinely-held record as unclaimed and `stats --filed-by X` reports
  `Open: 0 · Closed: 0`, both at status 0 with nothing on stderr. The bare words
  `claimed`/`unclaimed` populate an axis named `held`, which reads the same
  blanked `claimed-by` field the guard protects but is absent from its
  enumeration; `cmd_stats` has no guard at all. The `unclaimed` case is the worse
  of the two: not an empty result but a positively wrong non-empty one.
- **Suggestion:** Extend the enumeration to the `held` axis and lift the guard
  into a helper both read verbs call. Both are reachable from the existing
  `seen_rows` / `saw_type` state.
- **Relates to:** AC "the view says so and fails"; plan task 13; invariant
  `staleness-gated-reads`

### 2. A present-but-empty filter operand silently matches everything

- **Priority:** high
- **Description:** `--label ,,,` and `--label '   '` each produce no alternative,
  so the axis key is never assigned and every downstream matcher reads it as
  "axis not named" and returns true. Verified: both match every record at status
  0 where the baseline matches one. This is the silent widening the file's own
  `need_operand` commentary argues against — a narrower query and a query that
  matched little look identical on a read surface.
- **Suggestion:** Refuse when a flag's operand yields zero alternatives after
  splitting and trimming; the flag was typed, so its axis should never vanish.
- **Relates to:** AC "Values naming the same axis combine as alternatives"

### 3. An unrecognized flag is accepted as a flag's value

- **Priority:** medium
- **Description:** `need_operand` refuses an operand only when it matches one of
  this file's own option names, so `--label --nosuchflag` binds `--nosuchflag` as
  a label alternative. Standing alone, the same token is recognized as a flag and
  refused. The plan's design decision scoped the refusal to "another *known*
  flag" and its rationale concerns single-hyphen values that a real address can
  wear; the carve-out is broader than that rationale needs.
- **Suggestion:** Refuse a double-hyphen operand while continuing to carry a
  single-hyphen one through, which matches the stated rationale exactly.
- **Relates to:** AC "a value that is another flag, is refused"

### 4. `is_filter_token` is dead code

- **Priority:** medium
- **Description:** The function had three callers before this build and zero
  after. It is the old membership test whose narrow use in `dir_given` produced
  the routing defect task 8 fixed; the build widened it in task 6 and then
  removed its last caller in task 8 without deleting it. A future reader could
  mistake it for the live guard.
- **Suggestion:** Delete it.
- **Relates to:** Task 8

### 5. A dependency outside the collection reads as unblocked

- **Priority:** low
- **Description:** A `depends-on` target with no record in the collection cannot
  be judged unfinished, so it contributes nothing and the record falls through to
  unblocked. The index reports the dangling edge as a missing back-edge; the read
  view answers confidently in the other direction. Already filed.
- **Suggestion:** Treat an unresolvable target as blocking, or disclose the
  records whose blocked-ness could not be settled.
- **Relates to:** AC "An issue is blocked when it depends on an issue that is not
  finished"

### 6. A person query is whitespace-trimmed before it is compared

- **Priority:** low
- **Description:** `filter_axis_add` trims every filter value with no
  axis-specific exception. A recorded identity unjudgeable *because of* leading
  or trailing whitespace — reachable through hand-edited frontmatter or a
  history-recovered filer — therefore cannot be reached by naming it exactly,
  which is what the criterion promises for exactly that class.
- **Suggestion:** Exempt the person axes from the trim, or trim only around the
  comma delimiters.
- **Relates to:** AC "stays reachable by naming it exactly"

### 7. Statistics counts can disagree with the index's own summary

- **Priority:** low
- **Description:** `index.sh` classifies a record by its raw `status` value;
  `render.sh` now classifies by the sanitized value read back from the row.
  Verified: a record with `status: "closed<0x01>"` is counted open in the index's
  own Summary block and closed by `stats`, so the two disagree inside one file.
  The previous code echoed the Summary verbatim and could not diverge.
- **Suggestion:** Compare the sanitized value on both sides, or have `stats`
  disclose when its count differs from the recorded Summary.
- **Relates to:** Task 18

### 8. The blocking rollup is scoped by source only

- **Priority:** low
- **Description:** A filtered `stats` scopes its counts and clusters to matching
  records, but the blocking rollup filters only the edge *source* — a matching
  source still reports its full out-degree and target list over the unfiltered
  graph. Defensible as "what does this filtered set block", but nothing states
  it, so a reader cannot tell design from oversight.
- **Suggestion:** State the choice where the rollup is built.
- **Relates to:** Task 18

### 9. `--spec` prefix matching has no directory boundary

- **Priority:** low
- **Description:** The comparison is a raw string prefix, so `--spec issue/011`
  would also reach `issue/0110-…` were such a directory possible. It is not, but
  only because the allocator enforces ordinal uniqueness and fixed-width padding
  — two invariants that live in another group and are not referenced where the
  comparison happens.
- **Suggestion:** Note the dependency at `prefix_axis`, or require the byte after
  the prefix to be `/`, `-`, or end-of-string.
- **Relates to:** AC "An origin match is a path prefix"

### 10. A column naming an unanswerable field renders blank

- **Priority:** medium
- **Description:** `--cols filed-by` against a pre-widening index prints a column
  of `-` at status 0, while `--filed-by` against the same index refuses and names
  the repair. The disclosure was specified over axes and stops at the axis list.
  Already filed.
- **Suggestion:** Extend the same check to `FILTER_COLS`, or disclose beside the
  view rather than refusing — a blank column is less severe than a wrong filter.
- **Relates to:** AC "the view says so and fails"

### 11. `render.sh` comments still cite spec and finding ids

- **Priority:** low
- **Description:** Eight comments cite a spec, AC, or Finding number, which the
  project forbids because this group's own rename verbs renumber what they name.
  The two inside functions this build re-authored were removed; the rest predate
  it. Already filed.
- **Suggestion:** Sweep them, and the sibling scripts in the same pass.
- **Relates to:** CLAUDE.md → Bash scripts

### 12. Untrusted values reach awk through `-v` in two sibling scripts

- **Priority:** low
- **Description:** `migrate.sh` and `transition.sh` pass untrusted values to awk
  via `-v`, while `backfill.sh` deliberately avoids `-v` because POSIX awk
  expands backslash escapes in its operand — a hazard ARCHITECTURE.md documents.
  Pre-existing and untouched by this build; surfaced while auditing the new awk
  programs, which are all clean.
- **Suggestion:** Route those values through `ENVIRON`, matching `backfill.sh`.
- **Relates to:** ARCHITECTURE.md § Skills

### 13. Test-coverage gaps around the new surfaces

- **Priority:** low
- **Description:** Six behaviors are correct by trace but pinned by no case: a
  `stats` filter that matches nothing; `--cols` alone correctly *not* triggering
  the closed-hidden disclosure; `stats --filed-by me` disclosing the resolved
  identity in its scope line; a dangling `depends-on` target; `insights-graph`
  excluding a `depends-on`-only node from `BLOCKING`; and `type: ""` /
  `filed-by: ""` omission (only two of the four fields are exercised empty).
- **Suggestion:** Add cases as the surrounding code is next touched.
- **Relates to:** Tasks 15, 16, 17, 18

## Deviations & feedback

- **The plan's task text became the specification.** Both partial acceptance
  criteria trace to the same shape: the plan enumerated a concrete subset
  (`type` / `filed-by` / `claimed-by`; "another *known* flag") and the build
  implemented the enumeration faithfully, while the criterion above it was
  stated generally. Neither security pass caught it because both reviewed the
  plan's own framing. A plan that narrows a criterion should say it is narrowing
  one.
- **The feature's own disclosure fired on its first real query.** The
  unanswerable-axis guard refused `--claimed-by me` against this repository's
  tracked index immediately after the build, because that index predated the
  widening. That is the mechanism working — and it is also what exposed the two
  axes the guard does not cover.
- **Two verification methods disagreed, and running it settled it.** Three
  investigators reasoned that a present-but-empty operand *should* refuse;
  executing it showed it matches everything. Every finding above that asserts a
  behavior was reproduced rather than inferred.
- **The read-only investigator boundary cost two comparisons.** Two agents could
  not run `git show` and said so rather than guessing; the orchestrator closed
  both against the commits directly. The boundary is right — the disclosure is
  what made it safe.
