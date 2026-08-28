# Context — epic authoring and views

A mid-flight handoff, written at the boundary between `/jim:plan` and
`/jim:build`. It records what is **expensive or impossible to re-derive from
the artifacts**: code anatomy established by reading and running, the
experiments that proved each security finding, the things that were checked and
*held*, and the traps that cost real time.

This replaces the pre-plan handoff of the same name. That one pointed forward
at decisions still to be made; every one of them is now made and written into
`plan.md`, so this document deliberately does **not** repeat the design.

**Anything below that looks like a setting is a pointer.** Configuration is the
half of a handoff that goes stale fastest — findings survive, settings change
under you — so where a value matters this document names the resolver that
answers it rather than quoting what it answered here.

**This document is a starting point, not a substitute for grounding.** § 2 is
not optional.

---

## 1. Where this stands

The spec and the plan are both **approved**. Research is complete. Security has
run **twice** — once against the spec, once against spec+plan together — and
the second pass reshaped the plan. Nothing is waiting on a decision.

| artifact | state |
| :--- | :--- |
| `spec.md` | **`approved`** — 38 ACs across 7 groups, 11 stories, 12 exclusions, 6 handoff insights, 9 resolved / 0 open questions |
| `plan.md` | **`approved`** — 877 lines: 11 design decisions, 29 tasks, 38/38 ACs covered, 0 `[NEEDS CLARIFICATION]` |
| `security.md` | `Needs Plan Review` — `reviewed_phases: [spec, plan]`, 0 Critical · 10 Notable · 4 Advisory, all 14 dispositioned |
| `research.md` | `Needs PM Review` — advisory; its two corrections were applied to the spec before approval |
| `ledger.md` | 10 events: spec → research → sec → spec finished → plan → sec → plan finished |

**`security.md` sitting at `Needs Plan Review` is correct and is not a loose
end.** That status is set by routed Notable findings *existing*, not by their
being unaddressed. All nine plan-lens findings are folded into `plan.md`. The
status is the artifact recording that a plan-lens pass found real things, which
is what the next reader should see.

**The next stage is `/jim:build`.** Its gate re-runs `/jim:sec`, which will find
`reviewed_phases: [spec, plan]` already satisfied — a third pass is available
but has no lens left to apply.

**Commits this session**, oldest first: `b00d8f2` (config), `e0ceb3e`,
`e34db60`, `80a1a35` (spec), `34bc443`, `12811ee` (notes), `71ae209` (the
superseded handoff), `4755bc9` (plan + security + ledger), `a6fd9c3` (three
filed issues + index). Working tree clean at `a6fd9c3`.

**The arc this closes.** A brainstorm dated 2026-08-17 opened two capabilities
on the issue collection. `012` made the schema fields exist; `013` settled the
form a recorded identity takes; `014` made those fields queryable and widened
the index row. Each left the epic half deliberately unbuilt. `015` is the
remainder.

---

## 2. Building deep context

Read this document first, then **do all of the following before building**.
Each read grounds a different class of claim, and every failure this session
cost time on was a claim made without opening the thing it described.

**In the spec directory** — all five, in this order:

1. `plan.md` — **the primary document now.** The design decisions carry their
   own reasoning and their own verified anchors; the task breakdown is the
   contract. Read the Design Decisions in full even where they look settled —
   several were amended by the security pass and the amendment is the part that
   matters.
2. `spec.md` — the 38 ACs are what the plan is measured against. Its Open
   Questions section holds the reasoning for every fork; several decisions look
   arbitrary without it.
3. `security.md` — findings **6–14** are the plan-lens pass and each names a
   concrete defect in a mechanism the plan describes. Every one was reproduced
   by execution; § 3 below holds the reproductions.
4. `research.md` — its Peer Feedback documents two places the spec was factually
   wrong and why, which is the failure mode most likely to recur.
5. `ledger.md` — the stage record.

**Grounding beyond this increment** — all four are load-bearing:

6. `docs/specs/issue/000-blueprint/spec.md` — the group's present-tense
   specification. Its **Invariants** table is what this increment is most likely
   to violate by accident; at least seven bear on it directly
   (`declared-vocabularies`, `id-gate-before-path`, `row-shape-is-the-writers`,
   `placeholder-by-position`, `atomic-index-write`, `single-emitter`,
   `staleness-gated-reads`). Read the Provides section too — `place.sh`'s verb
   enum is a declared face, not an internal list.
7. `BLUEPRINT.md` — the project map and the derived contract graph. It is what
   tells you the placement door has **two consumers outside this group**.
8. `docs/notes/process-improvements.md` — **read this before building, not
   after something goes wrong.** The sections that bit *this* session are listed
   in § 5.
9. `docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md` — the
   origin. Its design-options analysis explains why membership is stored on the
   member and derived on the umbrella, which no later artifact re-argues.

---

## 3. Facts established by running things

Every claim here was verified by execution or by opening the file. Coordinates
are paired with symbol names deliberately — line numbers rot when a file grows,
and `render.sh` grew ~450 lines during the last remediation, which is how two
stale references reached the spec's first draft.

### The nine plan-lens findings, and how each was proven

These are the expensive half of the session. Each reproduction is one command.

- **Quoting mismatch (finding 6).** `apply_verb` emits values in *file form* —
  `claimed-by` with literal quotes, `status`/`outcome` bare — while `fm_field`
  strips quotes. Proven by running the real `fm_field` body against a fixture:
  pair value `"jrko"` vs current `jrko`; release `""` vs empty. **Reached
  independently twice** (own pass + one adversarial reader).
- **`fm_field` cannot see `part-of` (finding 7).** It is anchored `^<field>:`
  and `part-of` is indented under `relations:`. Proven: `fm_field` returns empty
  against a record that genuinely holds a membership, while `relation_targets`
  returns the umbrella.
- **`outgoing_fm` is not deduplicated (finding 8).** `edges_all` is guarded by a
  `seen_all` key; `edges_fm` is appended unguarded. Proven end-to-end: a record
  with `part-of: [E, E, E]` renders **one** edge in `## Graph` and produces
  **three** entries in `outgoing_fm` — the umbrella-resolves check fires three
  times for one record.
- **The heredoc (finding 9).** `usage()` is `cat <<'USAGE'` — quoted, which is
  why `` `direct` ``, `` `route` ``, `` `{}` ``, `` `{token}` `` print
  literally. Proven by reproducing the unquoted form: four
  `command not found` lines and four deleted words. **And the plan's own verify
  command passed against the corrupted output** — it redirected stderr into
  stdout and grepped substrings. That is the finding within the finding.
- **The label encoder (finding 10).** `is_valid_id` admits
  `[A-Za-z0-9][A-Za-z0-9._-]*`; the labels encoder reduces to `[a-z0-9-]`.
  Proven: `JIM-0042-auth-hardening` passes the validator and encodes to
  `jim-0042-auth-hardening`. `JIM-` is a supported `issue_id_prefix` scheme
  named in `ARCHITECTURE.md`, so this is an ordinary configuration.
- **Reference forms (finding 11).** Proven against a two-record fixture holding
  a real umbrella: `--epic <exact-slug>` matches; `--epic <ordinal>` and
  `--epic <prefix>` match **nothing**, both at status 0. Adding the refusal
  without the ladder makes two of three required forms worse than today.
- **Container-scoped census (finding 12).** Follows from the guard being
  unconditional: `stats --type epic` admits only epic rows and then skips every
  one before any counter.
- **Impossible resolution position (finding 13).** `resolve_person_axes` runs
  before `ensure_index` in both read verbs (`render.sh` — `cmd_stats` calls them
  at `:624` then `:630`; `cmd_list` at `:1141` then `:1143`).
- **Entry ceiling (finding 14).** `row_safe` caps a scalar at 512 bytes,
  `is_valid_id` a slug at 128, and **`status` is checked against no vocabulary
  at all** in `index.sh` — there is no `ISSUE_STATUSES` constant, unlike
  `ISSUE_TYPES` and `ISSUE_OUTCOMES` at `:77-78`.

### What was attacked and **held** — do not re-litigate these

The negative results cost as much as the findings and are invisible in the
artifacts. Three adversarial readers plus the reviewer's own pass tried to
refute each of these and could not:

- **`row_safe` really does kill newlines.** `tr -d '\000-\037\177'` — octal
  `\012` is inside `\000-\037`. Demonstrated (`a\nb` → `ab`), not inferred from
  the function's name. This is the whole basis of the structure-forgery answer.
- **Section placement is safe between `## Issues` and `## Graph`.** All three
  `INDEX.md` extractors terminate on *any* following `^## ` line; none hardcodes
  the next section's name. A repo-wide sweep found **no other** section-keyed,
  range-keyed or line-prefix parser of `INDEX.md` — not in `skills/blueprint`,
  `skills/verify`, `skills/partition`, `skills/spec`, `agents/`, or any test file.
- **The placeholder-offset defect stays closed.** Markers are appended last and
  declared as negative offsets; `place_marker_at` resolves them against the
  *current* argc and verifies the resolved slot holds the declared marker before
  substituting. New flags cannot disturb them.
- **The directory-resolution hoist is behaviour-preserving.** It depends only on
  `$dir` and `jimconf.sh get issues` — no hidden dependency on anything the
  allocator returns.
- **Both new refusals are reachable on both invocation shapes.** The routing
  block ends in an `exec` whose child always carries `--dir`, which makes the
  routing conditional false, so the child falls into the same shared pre-spend
  block in the same order.
- **A routed refusal cannot leak a materialized collection.** `place_open_work`
  registers `trap place_cleanup EXIT INT TERM` before the wrapped command runs.
- **Aborting the handle on a no-op cannot lose in-flight edits.** The routed arm
  materializes fresh per invocation; the direct arm's `abort` removes only the
  handle dir, never the working tree, and `place_dirty_guard` already refuses a
  direct handle over a dirty tree.
- **Growing `PLACE_VERBS` breaks neither outside consumer.** `reconcile.sh` uses
  `mode`/`begin`/`commit --verb edit`/`abort`; `/jim:partition` holds
  `mode`/`begin --read`/`abort` and no publish verb. Neither enumerates the
  array.
- **`is_valid_id`-cleared slugs are inert in markdown.** The class admits no
  backtick, pipe, bracket, asterisk, angle bracket or whitespace.
- **The bucketing shape terminates over genuine cycles.** Traced by hand against
  A↔B and a self-loop; a self-loop makes a record its own roster member, which
  the containment warning catches.
- **`cmd_list` is unaffected by a guard scoped to `cmd_stats`' loop.** It shares
  `seen_rows`/`saw_type`/`row_matches` but has no `matching` array.
- **Moving `epic` into the schema-gated axes breaks no existing caller.** The
  vocabulary-iterating case reads `AXIS_FIELDS` at run time and flips the axis
  with no test edit.

### Anatomy the plan cites but does not fully enumerate

**`transition.sh`** — `TRANSITION_VERBS` at `:49`, iterated at exactly two sites
(`usage` `:64`, `in_verbs` `:68-74`). The argument loop is in `main` `:203-213`;
the single positional binds at `:210` and a second token errors at `:211`. Id
validation at `:241-245`, `resolve_slug` at `:112-138`, re-validation at
`:266-276`. The change choke point: `changes="$(apply_verb …)"` at `:281`,
stamp appended at `:300`, `set_fields` at `:303`. Six `abort` sites; one
`commit` at `:321` that deliberately does **not** unwind on failure.
`set_fields` writes `field: value` and passes both halves through `ENVIRON`,
never `awk -v`.

**`new.sh`** — flat script, no functions. Flag loop `:86-104` (14 flags, purely
additive). Routing block `:106-178`, ending in the `exec` at `:175-176`. Shared
pre-spend block `:182-209`. **The spend is `:219`.** Directory resolution
`:246-252` (hoistable). Collision handling `:270-287` (not hoistable). Frontmatter
write `:324-349`; `type: issue` is hardcoded at `:333` with a comment asserting
a capture is always an issue — **this increment is what makes that false, so the
comment goes with it**. `relations.part-of` hardcoded `[]` at `:341`. Exit codes
0/1/2/3/4; enum refusals use **1**, call-shape errors **2**.

**`index.sh`** — four section emitters composed at `:799-828`, accumulators
declared at `:400`, atomic write `:787-857` with a deliberate `touch` after the
`mv` so the staleness gate sees the index as newest. `row_safe` at `:301-303`.
`parse_relations` `:178-207` — **type-agnostic by construction**, no vocabulary
check, which is what let `part-of` work with no parser change.
`outgoing_fm`/`outgoing_all` declared at `:410`, built at `:546`/`:550`.
Umbrella-resolves check `:742-751` — has `mtarget`, `meta_type`, `meta_status`
in scope, which is why both new warnings belong there. **No recursion or
visited-set traversal anywhere in the file.**

**`render.sh`** — `cmd_stats` `:617-756` with **ten** accumulation sites; the
three regions are `seen_rows`/`saw_type` `:658-659`, `matching` `:661`, and five
work counters `:662-680`. Blocking loop `:727-732`, gated on
`matching[$edge_src]` and never on the target (pre-existing). `read_graph_edges`
`:484-502`, five call sites (`:732`, `:934`, `:937`, `:1450`, `:1454`);
`part-of` is read in exactly one place, `build_derived_axes:937`.
`build_derived_axes` `:922-938` builds `DERIVED_EPIC` keyed by **member**, not
by umbrella — a roster needs the inverse. `epic_matches` `:1021-1034` does exact
string equality. `render_issue_file` `:1324-1358` takes `dir` and `slug` only
and never touches the index; `cmd_show` holds `index_file` at `:1369`.
`index_is_stale` `:115-128`. `schema_gate` `:525-551`. Declared vocabularies at
`:72-96` and `:172-173`.

**`place.sh`** — `PLACE_VERBS` `:104-105` (twelve verbs, already including all
five transition verbs), `place_valid_verb` `:222-229` called from two sites,
`place_message` `:1676-1683`, empty-diff early return `place_direct_publish:777`,
`place_changed` `:1913-1925`. `usage()` heredoc `:2052-2068`.

**Tests** — `tests/issues.sh` 402 cases / 9,294 lines. Only four assertion
helpers; no `assert_ne`, no `assert_contains`; absence is
`assert_eq "label" "0" "$(… | grep -c …)"`. `derived_fixture` `:8639-8680`
already builds an epic with two members — **both open**, so no fixture exercises
a non-zero progress numerator. `script_vocabulary`/`render_vocabulary`
`:8262-8280` read a `readonly NAME=(` out of a script; `axis_query` `:8306-8320`
must gain an entry for any new axis or the vocabulary loop fails loudly.
`tests/docsurfaces.sh` carries the derive-from-authority pattern to copy
(`ledger_verbs` `:60-64`, its case `:137-147`) and the anti-pattern not to
(`case_docsurfaces_registry_verbs_reach_every_surface` `:154-180`, a
hand-written array).

Targeted verification works and is what every task's Verify uses:
`bash tests/issues.sh <case-name>`.

### Measurements

Against the real collection, modelling full adoption (46 umbrellas, 311
memberships):

| | |
| :--- | :--- |
| `INDEX.md` | 167,041 bytes / 571 lines — Issues 140,223 · Graph 21,783 · Warnings 653 |
| collection | 409 issues, 143 open |
| Graph edge cost | **150.2 bytes/edge** measured over 145 edges |
| open members per umbrella | median **2** · p75 **4** · p90 **7** · max **20** |
| `## Epics` section | 13,313 B uncapped (+8.0%) · 12,641 B at cap 10 (+7.6%) |
| `part-of` edges added | **+46,703 B (+28.0%)** — four times the section |
| largest real body of work | 88 issues from `docs/specs/issue/011-issue-placement`, 20 open / 68 closed |

**The census regression oracle is regenerable, not archived — do not chase a
stored hash.** The collection holds zero umbrellas, so `stats` before and after
the change must be byte-identical, and the oracle is whatever the *current*
collection produces: copy `docs/issues/*.md` to a scratch directory and run
`render.sh stats <dir>` against the copy, before touching `cmd_stats`. Take it
against a copy rather than the live collection — a read regenerates `INDEX.md`
when it judges it stale, and that is a write to a tracked artifact. The hash
moves every time an issue is filed or closed, which is exactly why the method
belongs here and a number does not. Task 18 pins this.

---

## 4. Decisions whose reasoning lives only here

Most of this increment's reasoning **is** in `plan.md` and `spec.md`. Four
things are not.

**Why the security pass was run adversarially, and what it bought.** The plan's
author reviewing the plan is the documented failure mode — *Budget for second
priors, not for diligence*. Three readers with distinct lenses ran alongside the
reviewer's own pass. Findings 6 and 11 came from the own pass, by going after
the least-certain claims rather than re-reading. **Findings 8, 9 and 10 would
not have been found otherwise** — and 9 especially, because the verify command
that would have caught it was one the same author wrote and it passes against
the corrupted output. That is the concrete argument for the fan-out, and it is
worth repeating at the build's review stage.

**Why the two commits are ordered plan-then-issues.** The three filed issues
carry `origin: …/plan.md`, and `index.sh` lints origin paths under the default
placement. Filing first would leave an intermediate commit with three
unresolvable origins and a warning block that has nothing to do with the change.

**Why `status` having no vocabulary check was left alone.** It surfaced under
finding 14 and is real — `type` and `outcome` are checked, `status` is not. It
is pre-existing, it is not this increment's, and filing it would have been a
fourth candidate on a batch already carrying three. Left deliberately, recorded
here so the next reader knows it was seen rather than missed.

**A session grant that does not survive this document.** The developer
authorized agent fan-out for the session that produced this work, twice —
before the plan and again after compaction. **Both were per-session grants.** A
later session must not read this paragraph as standing authorization; confirm
before fanning out. It is recorded only so the next session knows the grant
existed and can ask.

---

## 5. Traps and environment

**Configuration — resolve, do not trust this page.** `b00d8f2` turned off
unattended invocation for the post-build review and the blueprint health hook,
so both prompt and give a compaction point. Whether that is still true is a
question for `bash skills/conf/scripts/jimconf.sh get <key>`, not for this
document. Same for every gate flag and the identity scheme.

**The placement mode is the exception, and `jimconf.sh` answers it
misleadingly.** `get issue_placement` returns `branch` — which is not a branch
name but the sentinel for *the working branch*, read at `place.sh:199-202` and
fabricated as the default at `jimconf.sh:96`. Taken at face value it says the
collection is centralized when it is not. Ask the door instead:
`bash skills/issue/scripts/place.sh mode`. Verified this session — the key
reads `branch`, the door reports `direct`.

**The diff-filter trap fired again this session, on a reader who had already
written it down.** `git diff | grep '^[+-]' | grep -v '^[+-][+-]'` silently
drops every added markdown list line, because `+` followed by a list `-` matches
the exclusion. It is in the process notes, it was in the *previous* handoff, and
it still produced a wrong answer here. Read diffs by hunk: `git diff -U0` and
filter only the `diff`/`index`/`---`/`+++` headers out. Treat the prose rule as
insufficient — the habit has to be the default invocation.

**`grep` over these documents lies in three more ways**, all silent: a phrase
split across a line break is invisible; a checkbox marker means different things
in different sections, so counting `- [ ]` for ACs over-counts by the number of
open questions; and subtracting the wrong header rows from a table count gives a
plausible wrong number (that one happened here and was caught only by a second
measurement). Unwrap with `tr '\n' ' ' | tr -s ' '` before searching prose;
scope with `sed -n '/^## Section/,/^## Next/p'` before counting structure.

**The coordination remote is unreachable from this VM.** Every filing and every
spec allocation returns a `P-` provisional identity; the host realizes them.
This is the designed degradation. Two consequences: an ordinal is **spent even
when a run later refuses**, because the allocator is append-only; and
`/jim:spec reconcile` and `/jim:issue reconcile` must be run host-side. Realize
assigns ordinals **alphabetically by slug within a day's batch**, not in filing
order — this session's three landed 407/408/409 in an order that surprises if
you expect filing order.

**The placement door reports `direct` here.** Filings and transitions write in
place and do not auto-publish, so issue work lands uncommitted and the commit is
a separate manual step. `INDEX.md` regenerates across all of it, so one index
state can span several logical changes — plan commits so the index lands with
the last of them.

**No `python3` in this VM.** Bash and POSIX tools only, which is also the
project's own rule for its scripts.

**The suite takes ~9 minutes** and exceeds a foreground timeout; run it
backgrounded and never concurrently with anything else, **subagents included**.
Any measurement taken under suite contention is unreliable — sequence
measurements before the suite, not beside it.

**The process-improvements sections that bit this session**, worth re-reading
before building rather than after: *A false success is the failure mode that
survives every gate* (finding 9 is a textbook instance), *Budget for second
priors, not for diligence*, *A grep over a wrapped document measures the
rendering*, *Neuter the guard, watch the case go red*, and *A case that cannot
go red is a finding*.

---

## 6. If you are picking up from here

The next stage is `/jim:build`, executing `plan.md`'s 29 tasks in order. Six
things it owes beyond the task list.

1. **Red-first is not optional on the nine security-driven cases.** Each of
   findings 6–14 has a named case in the plan, and each of those cases must be
   shown to fail against the naive implementation before the fix lands. Finding
   9's case is the sharpest: the obvious verify passes against the broken
   output, so the case has to assert the *literal backticks survive and stderr
   is empty*, not that the verbs appear.
2. **Task 12's case supersedes an existing one that cannot discriminate.**
   `case_transition_claim_is_idempotent_for_the_holder` is exactly the no-op
   scenario and asserts nothing about `updated:` or mtime, so it passes either
   way. Extend it or replace it — leaving it standing reports coverage that does
   not exist.
3. **`derived_fixture` needs a partially-complete umbrella.** Both its members
   are open today, so no fixture exercises a non-zero progress numerator.
4. **Bind every universally-quantified task to its named domain** rather than
   paraphrasing the quantifier — the five work counters, the six documentation
   surfaces, the seven verbs. All three domains are enumerable and all three are
   enumerated in `plan.md`.
5. **The commit type must match the content.** Several tasks touch both a script
   and its test; a behavioural change never ships under `docs` or `test`.
6. **`ARCHITECTURE.md` is the completion gate's job, not a task.** Two verb-list
   mentions there refresh via `/jim:arch`. `README.md` and `WORKFLOW.md` are
   **not** auto-refreshed and are tasks 25–27 for exactly that reason.

Three things the build should *not* re-open: membership cardinality stays
unbounded; the fold to the existing five verbs governs the no-op path only; and
`part-of` keeps rendering in `## Graph` — its cost is filed as `#408`, not
resolved here.
