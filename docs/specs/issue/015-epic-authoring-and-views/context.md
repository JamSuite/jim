# Context — epic authoring and views

A mid-flight handoff, written at the boundary between the spec stage and
`/jim:plan`. It records what is **expensive or impossible to re-derive from the
artifacts**: facts established by running things, decisions whose reasoning
lives nowhere else, and the traps that cost real time this session. Everything
already said well in `spec.md`, `research.md` or `security.md` is pointed at,
not repeated.

**Anything below that looks like a setting is a pointer.** Configuration is the
half of a handoff that goes stale fastest — findings survive, settings change
under you — so where a value matters this document names the resolver that
answers it rather than quoting what it answered here.

**This document is a starting point, not a substitute for grounding.** § 2 is
not optional.

---

## 1. Where this stands

The spec is **approved**. Research and both a security pass are complete. The
next stage is `/jim:plan`, which opens with its own security gate.

| artifact | state |
| :--- | :--- |
| `spec.md` | **`approved`** — 38 ACs across 7 groups, 11 stories, 12 exclusions, 6 handoff insights, 9 resolved / **0 open** questions |
| `research.md` | `Needs PM Review` — it corrected two of the spec's own insights; both corrections are applied |
| `security.md` | `Needs Spec Review` — 0 critical, 3 notable, 2 advisory; all five dispositioned |
| `ledger.md` | `spec started → research → sec → spec finished` |
| `plan.md` | does not exist yet |

Nothing is waiting on a decision. Every fork this spec opened is closed and the
reasoning is recorded in its Open Questions section rather than only here.

**The arc this closes.** A brainstorm dated 2026-08-17 opened two capabilities
on the issue collection. Three increments have landed: `012` made the schema
fields exist (`filed-by`, `claimed-by`, `type`, `part-of`, `outcome`, and the
three-state lifecycle with its five transition verbs); `013` settled the form a
recorded identity takes; `014` made those fields queryable and widened the
index row to carry them. Each left the epic half deliberately unbuilt. `015` is
the remainder: nothing can create an umbrella or join one, and no view derives
a roster or progress.

---

## 2. Building deep context

Read this document first, then **do all of the following before planning**.
Nothing here is a summary you can plan from — each read grounds a different
class of claim, and the failures this session cost time on were all claims made
without opening the thing they described.

**In the spec directory** — read all four in this order:

1. `spec.md` — the ACs are the contract. Read the Open Questions section in
   full even though all nine are resolved: the *reasoning* for every fork lives
   there, and several decisions look arbitrary without it.
2. `research.md` — read its Peer Feedback section carefully. It documents two
   places where the spec was wrong and why, which is the failure mode most
   likely to recur.
3. `security.md` — findings 1–3 are each a property a spec-lens pass can only
   *state* and a plan-lens pass must *check as a design*. They are the reason
   the plan's security gate is likely to earn its cost here.
4. `ledger.md` — the stage record.

**Grounding beyond this increment** — all four are load-bearing:

5. `docs/specs/issue/000-blueprint/spec.md` — the group's present-tense
   specification. Its **Invariants** table is the thing this increment is most
   likely to violate by accident; at least five bear on this work directly
   (`declared-vocabularies`, `id-gate-before-path`, `row-shape-is-the-writers`,
   `placeholder-by-position`, `atomic-index-write`). Read the Provides section
   too — `place.sh`'s verb enum is a declared face, not an internal list.
6. `BLUEPRINT.md` — the project map and the derived contract graph. It is what
   tells you the placement door has **two consumers outside this group**, so
   extending its verb enum is a face change rather than a local one.
7. `docs/notes/process-improvements.md` — **read this before planning, not
   after something goes wrong.** It is the transferable half of two
   retrospectives and it now absorbs everything generalizable from the `014`
   retrospective, so that document is no longer required reading. The sections
   that bit *this* session specifically are listed in § 5.
8. `docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md` — the
   origin. Its design-options analysis explains why membership is stored on the
   member and derived on the umbrella, which no later artifact re-argues.

**Optional, and only if the process notes leave you wanting the original
evidence:** `docs/specs/issue/014-read-view-filter-composition/retrospective.md`.
Everything transferable in it was absorbed into the process notes in `12811ee`;
what remains unique to it is that increment's per-stage timings and token
counts.

---

## 3. Facts established by running things

Every claim here was verified by execution or by opening the file this session.
Coordinates are paired with symbol names deliberately — line numbers rot when a
file grows, and `render.sh` grew roughly 450 lines during the last remediation,
which is how two stale references ended up in the spec's first draft.

### The write path

- **`transition.sh` has no second-positional infrastructure.** Every existing
  verb takes exactly one operand, the issue id; `--as` is a flag, not a
  positional. `join <id> <umbrella>` is therefore a **new argument shape** for
  this script, and that is the real work in the verb — the dispatch arm is
  trivial. `TRANSITION_VERBS` is declared at `transition.sh:49`; dispatch is in
  `apply_verb` (~`:353-389`); the argument loop is in `main` (~`:204-213`).
- **The id validator runs before any path is composed**, and the code says so
  at the site: `transition.sh:242` gates the caller's id *"before any path is
  composed from it, including the stat inside `resolve_slug`"*, and `:272`
  re-validates the resolved slug because only one of the resolver's two arms
  returns a value the first check covered. **A second id-shaped operand must
  join that ordering** — this is security finding 3.
- **`new.sh` spends its identity at `:219`** (`jimalloc.sh allocate issue`).
  Refusals above that line are free; every refusal below it burns an ordinal
  permanently, because the allocator is append-only. Existing pre-spend checks
  sit at `:182-207`. **The issues-directory resolution at `:246-252` depends on
  nothing the allocation returns and can be hoisted above it** — which is what
  makes a capture-time umbrella-existence check affordable. The local-collision
  handling (`:270-287`) genuinely cannot move.
- **New emitter flags are safe with respect to the placeholder defect.**
  `new.sh:175-176` re-execs through the door appending `--dir '{}'
  --place-token '{token}'` **last**, and declares their positions as negative
  offsets (`--dir-at -3 --token-at -1`). The comment at `:172-174` states that
  forwarded argv ahead of them is never examined. New flags land in
  `original_argv`, ahead of the markers, so the offsets are unaffected. *The
  spec's first draft claimed the opposite; that claim was wrong.*
- **`PLACE_VERBS` is declared at `place.sh:105-106`**, validated by
  `place_valid_verb` (~`:220-229`) from two call sites (`cmd_commit`,
  `cmd_run`), and reaches published history through `place_message`
  (~`:1674-1681`), which composes `docs(issues): <verb> <id>`.

### The no-op behaviour that drove one decision

Probed directly with a fixture: **`claim` on an issue you already hold exits 0,
prints output byte-identical to a real claim, rewrites the file, and bumps the
`updated:` stamp by a second.** All five existing verbs write unconditionally.

The consequence chain is the part worth keeping: the placement door **already**
declines to publish a collection with nothing to commit — `place.sh` returns
early on an empty `git status --porcelain` (~`:777`) — but a refreshed stamp is
a real modification, so the stamp defeats a guard that would otherwise have made
a no-op free. That is why the spec's rule is *write only on change* rather than
*say something different*, and why the fix reaches all five existing verbs.

### The read path and the index

- **One shared graph reader.** `read_graph_edges` (`render.sh:484-502`) is the
  only reader of the index's `## Graph` section anywhere under `skills/` — the
  other matches for that heading are the writer in `index.sh` and a header
  comment. It has **five call sites**: `cmd_stats` blocking rollup (`:732`),
  `build_derived_axes` for `depends-on` and `part-of` (`:934`, `:937`), and
  `cmd_insights_graph` (`:1450`, `:1454`). Its slug class matches
  `is_valid_id`'s, with the rationale written at `:468-483`. **The roster and
  progress derivations become sites six and seven — bind them to this function
  by name.**
- **Issue `#381` is closed and its defect has no remaining instances.** A census
  of every slug character class under `skills/` found two deliberate families
  whose boundary holds: the **id** class `^[A-Za-z0-9][A-Za-z0-9._-]*$` governs
  issue ids (`index.sh:112`, `render.sh:492`, `render.sh:1316`,
  `jimfile.sh:207`), and the narrower **slug/group** class
  `^[a-z0-9][a-z0-9-]*$` governs spec slugs and group names. `jimfile.sh`
  carries both (`:176` slug, `:207` id), which is what shows the split is
  intentional.
- **`matching` carries two meanings, and the counting change collides with
  it.** In `cmd_stats` (`render.sh:617-756`), `matching[$slug]=1` at `:661`
  means *this row passed the filter*; the blocking loop at `:729` reads the same
  array to mean *this record is in scope*. Epics must be excluded from every
  count but **must not** be excluded from `matching`, because `stats --type
  epic` is a legal query whose blocking rollup should still work. **The
  exclusion is not one `continue`** — the set that matched and the set that
  counts as work are different sets that are currently one variable. A subagent
  proposed exactly the wrong placement here; reading the two loops together is
  what caught it.
- `saw_type` and `seen_rows` (`:658-659`) are computed **before** `row_matches`,
  so the schema-staleness gate is unaffected by any exclusion applied later in
  the loop. Preserve that ordering deliberately.
- **Index section assembly** lives at `index.sh:800-828` — four emitters, each
  printing a header then a conditional accumulator (declared ~`:400`), composed
  into a tmp file and `mv`'d atomically (~`:836-843`). A `## Epics` section
  slots between the Graph emitter and the Integrity Warnings emitter.
- **Membership data already exists in the index.** `parse_relations`
  (`index.sh:173-207`) is type-agnostic and already yields `part-of` pairs, and
  every membership renders as a Graph edge today. Read membership from
  `outgoing_fm` (frontmatter only), **not** `outgoing_all` — the latter unions
  wikilinks, and a wikilink must not create a membership. In practice wikilinks
  always type as `related-to` (`index.sh:569`), so `part-of` edges come only
  from frontmatter and the two renderings cannot disagree.
- The existing umbrella-resolves-in-collection check is at ~`index.sh:744-751`.
  The new containment warnings belong beside it, iterating the same edges.

### Measurements

Taken against the real collection this session:

| | |
| :--- | :--- |
| `INDEX.md` | 167,041 bytes / 571 lines |
| Issues section | 144,560 bytes (~87%) |
| Graph section | 21,805 bytes, 145 edges — **~149 bytes per edge** |
| avg rendered issue slug | 68 bytes |
| largest single body of work | **88 issues** from `docs/specs/issue/011-issue-placement` |
| its open/closed split | **20 open, 68 closed** |

Modelled from those: a full roster for that one umbrella costs ~6.2 KB
(+3.7%); open-only costs ~1.4 KB (+0.8%). **Membership itself costs more than
the roster does** — those 88 memberships add ~13.1 KB of Graph edges regardless
of what the new section renders.

### Tests

- **`derived_fixture` (`tests/issues.sh:8639-8680`) already builds an epic with
  `part-of` members** and completed dependencies. It is the corpus-shaped helper
  the group converged on — extend it rather than writing epic frontmatter inline.
- Existing epic-adjacent cases: an epic accepted as a kind (~`:5310`), an
  unresolvable umbrella warned (~`:5324`), single-sided membership staying quiet
  (~`:5343`).
- **Only four assertion helpers exist** — `assert_eq`, `assert_match` (ERE),
  `assert_exit`, `assert_nonempty`. There is no `assert_ne` and no
  `assert_contains`; the house idiom for absence is
  `assert_eq "label" "0" "$(… | grep -c …)"`.
- **Vocabulary-iterating tests already exist** at four sites (~`:8337`,
  `:8359`, `:8371-8400`, `:8448`) via a `render_vocabulary` helper
  (~`:8278-8280`) that reads a `readonly` constant out of `render.sh`. The
  `declared-vocabularies` invariant makes this obligatory, not optional, for any
  new vocabulary.
- 402 cases, 9,294 lines in `tests/issues.sh` at the time of writing.

---

## 4. Decisions whose reasoning lives only here

Most of this increment's reasoning **is** in `spec.md`'s Open Questions, which
is where it belongs. Read those. Only three things are not recorded there.

**Why `#381` was closed during a spec stage.** It was filed from `014`'s
research and fixed in `4ab67dc` during that same increment, with the trailer to
prove it. Nothing closed it, so it sat open describing a defect that no longer
existed, and the `015` spec's first draft cited it as a sequencing
prerequisite. Its `## Where` section named `render.sh:324` and `:703`; those
lines now hold unrelated code. That is the whole argument for confirming a
record against the rule it describes rather than the coordinates it quotes, and
it is now written up in the process notes.

**How the two wrong insights got into the spec.** Both described the code as it
was *before* the `014` remediation — one from an issue record written earlier,
one from the retrospective's account of a defect that had since been fixed.
Neither was checked against the file. Both were caught by research in about two
greps. **The lesson is not "read more carefully"** — it is that a mechanism
described from a record rather than from the file is the claim class that
travels furthest, and the tell is that no line was cited.

**A session grant that does not survive this document.** The developer
authorized agent fan-out for the session that produced this work, including
across compaction. **That was a per-session grant.** A later session must not
read this paragraph as standing authorization; confirm before fanning out. It
is recorded only so the next session knows the grant existed and can ask.

---

## 5. Traps and environment

**Configuration — resolve, do not trust this page.** Commit `b00d8f2` turned
off unattended invocation for the post-build review and the blueprint health
hook, deliberately, so both prompt and give you a compaction point. Whether
that is still true is a question for
`bash skills/conf/scripts/jimconf.sh get <key>`, not for this document. The
same goes for every gate flag, the placement mode and the identity scheme.

**The coordination remote is unreachable from this VM.** Every filing and every
spec allocation returns a `P-` provisional identity; the host realizes them.
This is the designed degradation, not a failure. Two consequences: an ordinal is
**spent even when a run later refuses**, because the allocator is append-only;
and `/jim:spec reconcile` and `/jim:issue reconcile` must be run host-side.

**The placement door reports `direct` here.** Filings and transitions write in
place and do **not** auto-publish, so issue work lands uncommitted in the
working tree and the commit is a separate manual step. `INDEX.md` regenerates
across all of it, which means a single index state can span several logical
changes — plan commits so the index lands with the last of them.

**`grep` over these documents lies in three distinct ways**, all silent, all
plausible: a phrase split across a line break is invisible; a checkbox marker
means different things in different sections, so counting `- [ ]` for ACs
over-counts by the number of open questions; and `grep '^[+-]' | grep -v
'^[+-][+-]'` on a diff drops every added markdown list item. All three cost time
this session. Unwrap with `tr '\n' ' ' | tr -s ' '` before searching prose, and
scope with `sed -n '/^## Section/,/^## Next/p'` before counting structure.

**No `python3` in this VM.** Bash and POSIX tools only, which is also the
project's own rule for its scripts.

**The suite takes ~9 minutes** and exceeds a foreground timeout; run it
backgrounded and never concurrently with anything else, **subagents included**.
Sequence the fan-out and the suite.

**The process-improvements sections that bit this session**, worth re-reading
before planning rather than after: *A false success is the failure mode that
survives every gate*, *Verify a claim about a document by opening it*, *A line
number is the first thing in a record to rot*, *A grep over a wrapped document
measures the rendering*, and *Budget for second priors, not for diligence*.

---

## 6. If you are picking up from here

The next stage is `/jim:plan`. Five things it owes:

1. **A sweep for consumers of the `updated:` field across other groups.**
   Write-only-on-change stops that stamp moving on no-op transitions. The read
   views use it for staleness, which this change *improves*; nothing else was
   checked. This was explicitly deferred to the plan.
2. **The cap number and the truncation order** for the index section's roster.
   Both are deliberately unspecified — properties to settle by measurement, the
   way `014` measured its index widening before committing to it. The ordering
   wants to be deterministic: the index already enumerates in glob order, which
   for date-prefixed slugs is chronological, so oldest-first falls out of
   existing behaviour rather than needing invention.
3. **Security findings 1–3 as designs.** Each is a property the spec can only
   state: a new index structure whose safety cannot be inherited from a
   sanitizer written for flat rows; a derivation that must terminate over
   records the index only *warns* about; and a second id-shaped operand that
   must clear the validator in the same position relative to path composition.
4. **Keep two ACs paired.** Capture-time umbrella validation and the
   no-identity-burned rule are coupled — validating at capture is only
   affordable *because* the ordering requirement is stated. Split them across
   tasks and you get either a check that burns ordinals or a quiet drop of the
   capture-time check. The last increment's remediation found the same pairing
   discipline held for two other AC pairs.
5. **Bind every universally-quantified task to its named domain** rather than
   paraphrasing the quantifier. This increment adds derivations over the graph
   edge set and an exclusion that must reach every accumulator in `cmd_stats`;
   both are exactly the shape that shipped incomplete last time, and the domains
   are enumerable.

Two things the plan should *not* re-open: membership cardinality stays
unbounded (bounding it would reverse a `012` decision taken in the reversible
direction), and the fold to the existing five verbs governs the no-op path
only — every verb keeps its behaviour on a real change.
