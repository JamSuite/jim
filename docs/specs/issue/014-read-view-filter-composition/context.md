# Context — read-view filter composition

A closing handoff for whoever picks this up. It records what is **expensive or
impossible to re-derive from the artifacts**: facts established by running
things, reproduction recipes, decisions whose reasoning lives nowhere else, and
the traps that cost real time. Everything already said well in `spec.md`,
`plan.md`, `review.md`, `remediation.md` or `retrospective.md` is pointed at,
not repeated. Anything below that looks like a setting is a pointer — go read
the setting.

---

## 1. Where this stands

The feature is **built, reviewed, and remediated through step 5**, and the test
debt the order queued next is closed too — what is left of `remediation.md`'s
order is the two it deliberately deferred. The three issues that gated the plan
are fixed, verified and closed. The plan is still held at `approved` — closing
it is a single decision, described in § 6.

| artifact | state |
| :--- | :--- |
| `spec.md` | `approved` — 35 acceptance criteria |
| `research.md` | `Needs PM Review` — the VISION contention, explicitly non-blocking |
| `security.md` | `Needs Plan Review` — 12 findings, all routed and applied |
| `plan.md` | `approved` — 21/21 tasks `[x]`, **held**, and now closeable |
| `review.md` | `minor-drift` — 13 findings, `undelegated=0` |
| `remediation.md` | the order of attack — steps 1–5 and `#396` done; `#394`, `#398` left |
| `retrospective.md` | why it happened; the root cause and its prevention |
| group blueprint | **15 invariants** — `row-shape-is-the-writers` added, writer-side only |
| suite | **1628 green** (`skills/meta-test/scripts/run.sh`) |

Two frontmatter values look wrong and are not, the same trap the preceding
increments record. **`security.md` stays `Needs Plan Review`** — the field
records what a review *found*, not whether it was acted on. **`research.md` is
`Needs PM Review`** because Peer Feedback carries the `VISION.md:67` contention
(`#380`, filed, not actioned). Non-blocking.

### What the remediation did

**31 commits, `0e55946..7af2fd7`** — this document's own commit follows
them. The load-bearing ones:

| commit | what |
| :--- | :--- |
| `9f292f0` | `#387` + `#388` — one `schema_gate` both read verbs call |
| `95d56cc` | `#390` + `#397` — an operand that names no filter refuses |
| `9cc6185` | `#386` — placeholders substitute only at declared offsets |
| `da7bd34` | `#391` — the callerless `is_filter_token` deleted |
| `0d7c820` | `#393` — 34 spec/finding citations swept from six scripts |
| `74a91d2` | `#395` — the index judges the scalar its rows carry |
| `d63357d` | `#392` (1 of 2) — filter values trimmed only beside commas |
| `2a22a21` | `#392` (2 of 2) — a row value read back as the writer wrote it |
| `52d071e` | `#389` — an unresolvable dependency blocks |
| `0197d67` | `remediation.md`'s steps-1+2 claim corrected |
| `0981ae0` `9b67756` | blueprint invariant 15 added; map restamped |
| `34fe1a1` `46d8908` | `#402` filed; `#374` extended |

**Closed (10):** `#386`, `#387`, `#388`, `#389`, `#390`, `#391`, `#392`,
`#393`, `#395`, `#397`. Each carries a Resolution note written to be read after
the fact rather than to justify a commit — they hold the reproduction evidence,
and for `#392` and `#389` the record of what the *filed* reproduce got wrong.
Read them before re-deriving anything about the fixes.

**Filed (4):** `#399` (schema gate misses a partly converted collection,
medium), `#400` (SKILL.md inlines title and origin into the emitter command
line, **critical**), `#401` (~58 spec/finding citations in three scripts outside
this group, plus the missing mechanical check, medium), `#402` (declared
vocabularies span scripts, **high**).

**Raised:** `#374` to high, twice extended — the face-counter undercount banks
into ledger history, and it now blocks the reconcile's derivation outright.

**Found, not filed (2)** — both from step 5, both recorded only in prose:
`index.sh` warns `names an umbrella not in the collection` for a missing
`part-of` target and has no analogue for `depends-on`; and
`row-shape-is-the-writers` is stated writer-side only while `2a22a21` upholds
its read-side half. They live in `remediation.md` § What it did not anticipate
at all and in the two resolutions. Neither has an ordinal — decide whether they
want one before they are lost.

### After the remediation

**`#396` closed** — `80c169c` (five cases) and `320273c` (the resolution). It
was the test debt the order queued next. Six behaviours were listed and five
needed work: `52d071e` had already shipped the sixth's assertion alongside the
fix for that defect, so the record's own list outlived the work by one. Two of
the six were stated slightly wrong and running them is what corrected it (§ 3).
Suite 1623 → 1628.

**One case fixed rather than filed** (`21eec13`).
`case_issues_index_wikilink_in_inline_backticks_ignored` passed for the wrong
reason, found by the shell's own complaint during the work above — one site
across all 1628 tests. It was two defects, and the second is the durable one:

- Its fixture body was double-quoted, so the wikilink it exists to test was
  command substitution. Bash ran it, and the body reached disk without the
  token; the case then asserted that a body holding no wikilink made no edge.
- **Correct quoting alone would not have saved it.** Its token was `[[B]]`,
  and neither assertion could fail on that. The edge assertion looks for an
  edge to `20260530-b`, which a differently-named target never makes; the
  warning assertion needs a target that fails `is_valid_id`, and `B` passes
  it, because that validator guards **containment** — empty, over 128 chars,
  `..` — and not slug shape. So a bare name yields an edge to an unvalidated
  target and no warning at all. Both assertions were inert.

The fixture now spans a resolvable slug and a traversal shape, the sibling
malformed-wikilink case's own shape. Disabling the inline-span strip in
`index.sh` fails both assertions; the half-fixed version failed one, which is
what exposed the second defect.

### What remains, in `remediation.md`'s order

- **`#394` and `#398` last, and deliberately.** Neither is a defect today.
- Outside the remediation: `/jim:arch` (§ 5), `#401`, `#402`, and `#374` —
  which now gates the blueprint surface, not just a counter.

Also open against this spec dir and never part of the remediation's thirteen:
`#380`–`#385` (VISION amendment, graph-edge slug narrowing, filter negation,
origin grouping, ROADMAP staleness, sort/group by the new fields).

### Where this sits in the larger arc

014 is the **third** spec out of
`docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md`, after 012
(schema and state model) and 013 (recorded identity schemes). Two remain, and
this decomposition lives nowhere but here:

1. **Epics** — 012 shipped `type` and `part-of`; nothing produces or consumes an
   epic. There are 0 epics and every `part-of` is `[]`. Missing: filing one
   (`new.sh` hardcodes `type: issue`), joining one (no transition verb mutates
   `part-of`), the derived roster and progress, an INDEX Epics section, and
   enforcement of the one-level nesting rule.
2. **Honest stats** — completion as `done / closed` rather than `closed / total`,
   with `wontfix` / `obsolete` / `duplicate` surfaced as their own signals.

**014 was deliberately sequenced first** so both later increments build *views*
rather than a second parse surface. That is why `--type` and `--epic` ship here
against fields that are schema-valid and empty.

## 2. Building deep context

Reading this document is not enough. Ground it in the artifacts, in this order
— the first three are short and change how the rest reads.

1. **`remediation.md`** § *Order*, § *What not to do*, and § *What running it
   settled*. All five steps are done, and so is `#396`; what is left of the
   order is `#394` and `#398`. Read § *Where this analysis was short* with it
   — five entries now, and they are the honest account of where an analysis of
   a review cannot reach.
2. **`retrospective.md`** § *Root cause: one set, three enumerations* — the
   single most useful page here, and the reason every fix took the shape it did.
   It is still predicting findings: `#402` is that shape one file boundary out,
   and `#392` turned out to be it at a seam between two functions.
3. **The eleven closed issues' Resolution sections** — `#386`, `#387`, `#388`,
   `#389`, `#390`, `#391`, `#392`, `#393`, `#395`, `#396`, `#397`. `#392`,
   `#389` and `#396` are the three worth reading first: each records a filed
   account that did not survive being run, and why.
4. **`docs/specs/issue/000-blueprint/spec.md`** — the group's 15 invariants.
   Three changed across the remediation (§ 4). This is what the code answers
   to — and `row-shape-is-the-writers` now understates the code, which upholds
   a read-side half the invariant does not state.
5. **`BLUEPRINT.md`** — the project map: four groups, their territories, and the
   derived contract graph. Read it to see where `issue` sits and what depends on
   its face. **Its Contract Graph is stale-by-design right now** — see § 3.
6. **`review.md`** § *Findings* and § *Living intent* — the evidence behind each
   issue, with `file:line` anchors. Findings 6 and 5 are worth reading against
   the resolutions of `#392` and `#389`: both name the right defect and the
   wrong input.
7. **`spec.md`** § *Acceptance Criteria* — five were partial; four are now
   satisfied. The one left cites Finding 9 (`#394`), which is a dependency to
   state rather than a bug to fix.
8. The code, in dependency order: `skills/issue/scripts/render.sh` (the whole
   filter surface, the row reader, and the derived axes), then `index.sh` (the
   row emitter and the scalar judge), then `place.sh` → `place_substitute`.

`plan.md` is worth reading for its Design Decisions, which carry reasoning the
code comments do not — but it is a **historical** record: two Constitution
Check rows cite the wrong task numbers, and `review.md` says which.

## 3. Facts established by running things

Every one of these was verified in-session by executing it. **Do not re-derive
them by reading**, and note that several contradict what a careful reading first
suggested.

### The fixes, confirmed by probe

- **`#386`.** Feed `place.sh run --read --token-at <i> --dir-at -1 --
  /usr/bin/env printf '%s\n' --place-token '{token}' list --label --dir '{}'
  '{}'` and read what the wrapped command receives. Before: **both** `{}` came
  back as the run's collection path. After: the caller's own `{}` survives
  verbatim and only the declared trailing slot is filled. Needs a
  placement-configured repo — this checkout resolves to `direct`, so confirm
  `place.sh mode` prints `route` first or the repro is inert. The recipe for
  building one is `tests/issues.sh`'s `placement_repo`.
- **`#387` / `#388`.** Against an index whose rows predate the widened row, all
  four recorded behaviours refuse: `--claimed-by` and `--filed-by` on either
  verb, and the `claimed` / `unclaimed` bare words. The refusal names the **row
  field**, not the axis key.
- **`#390` / `#397`.** `--label ,,,` and `--label '   '` refuse instead of
  matching everything; `--label --nosuchflag` refuses; `--filed-by -alice` is
  still carried, because the boundary is one hyphen versus two.
- **`#395`.** `status: "closed<0x01>"` produced `- Open: 1` three lines above a
  row reading `status: closed`, with `stats` answering `Open: 0 · Closed: 1`.
  The count was one of **three** sites: the same raw value reached both
  vocabulary checks, so `type: "issue<0x01>"` warned `unrecognized type: issue`
  — printing the value it had not judged.
- **`#392`. The filed reproduce does not reproduce, and the record says so.**
  Build a collection holding `filed-by: " alice"` and `filed-by: "bob "` and
  query both spellings of each. Before the fix, `" alice"` was reachable by
  `alice` *and* by `" alice"` — the row reader ate leading whitespace and the
  query's trim landed on the same string, two trims cancelling. `"bob "` matched
  **nothing**: not `bob `, not `bob`. Trailing whitespace was the unreachable
  class, and it was unfilterable rather than awkward. After: each identity is
  reached by the one spelling it carries.
- **`#392`, the second seam.** With `type: " issue"`, `index.sh` writes an
  Integrity Warning reading `unrecognized type:  issue` — and `list --type
  issue` returned that same record. The index refused the value; the view
  served it as recognized. `priority: " high"` behaved the same under
  `--priority high`. The row reader consuming a *run* of whitespace rather than
  the writer's single separator space is the whole mechanism.
- **`#389`.** A record whose `depends-on` names a slug the collection does not
  hold read as `unblocked`. The issue proposed leaning on the index's
  dangling-edge warning instead — but that warning reads `has no inverse blocks
  back-edge`, and it fires **identically** for a dependency that resolves. It
  reports reciprocity, not danglingness. Nothing reported the absence at all,
  on any surface.
- **`#396`, and the two of its six items that were stated wrong.** Its *item 3*
  says the census scope line reports the `me` it resolved. It reports more than
  that: the identity in the collection's own **recorded form**. Querying as
  `1234+alice@users.noreply.github.com` prints `scope: filed-by=alice`, the
  account name the configured form extracts — which is also the form the
  comparison ran under, so the line and the count agree by construction rather
  than by coincidence. Its *item 1* names "the trailing `if` with no `else`" as
  though it were one path; the integrity-warnings block has two, and the verb's
  status comes from whichever it takes, so an empty match has to be run over a
  sound collection **and** over one carrying a warning.
- **`labels: []` reaches the row as a literal pair and is still not a defect.**
  Every other empty scalar is omitted from the row; this one is not, because
  the frontmatter value is the two-character string rather than an empty one —
  and it is the spelling `new.sh` emits for a record with no labels. It is
  harmless: `read_issue_rows` strips the brackets, so the list view renders it
  absent and the census clusters nothing under it. Writer and reader invert
  each other exactly. Recorded because reading the emitter alone suggests a
  defect that is not there.

### `jimverify.sh faces` cannot be used to derive the graph (`#374`)

The most consequential thing learned across the remediation, and it changes how
the blueprint surface must be operated.

```
jimverify.sh faces docs/specs/sdlc/000-blueprint/spec.md  →  8 requires, 0 provides
```

sdlc's Provides section has **five** entries. Two exact parse rules produce
this, both measured:

- **Provides:** a slug is derived only from a **leading backticked token**. An
  entry opening with bold yields nothing. Per group: sdlc 5→0, blueprint 9→8,
  issue 12→10, platform 6→5. Total 32 declared, 23 reported.
- **Requires:** **one dotted key per bullet**. Three bullets declare two
  dependencies each (`` `platform.jimconf-cli` / `platform.jimfile-cli` ``, and
  `` `issue.emitter` + `issue.candidate-batch-contract` `` in two blueprints),
  so 26 declared requirements report as 23.

**Operational consequence:** a reconcile that re-derives from this verb reads
sdlc as declaring nothing and fabricates a leak against every `sdlc.personas`
requirement. This session's reconcile carried the persisted 26-edge table
forward and restamped instead — safe only because the run changed no face. A run
that *moves* a face has no such escape. `#374` now records this.

**The trap that follows:** `grep -cE '^- \`'` over a Provides section
undercounts the same way and nearly produced a false `leak` by hand. Match
`^- (\`|\*\*)`.

### Other verified facts

- **The pre-existing row-forgery test.**
  `case_issues_index_row_new_scalars_are_sanitized` already fed
  `type: "issue · status: closed"` and `outcome: "done · num: 999"` through the
  row and asserted five separators and zero control bytes. It was there before
  `#395`. The new
  `case_issues_index_classified_scalars_cannot_forge_a_row_field` adds `status`
  (the old fixture uses a plain `status: open`), per-field isolation, and a
  domain read from `index.sh`'s own declarations.
- **`row_safe` is the index's cost centre** — three processes a call, ~11 calls
  a record, most of the ~41s a 402-record regeneration takes. Applying it at
  both the read and the emission site took that to 52s; the committed shape is
  flat. Not filed — recorded in `#395`'s resolution.
- **A regeneration of the real collection is byte-identical** after `#395`. The
  numbers move only for a collection holding a control byte in a judged scalar.
- **`migrate identity --from --nosuchflag --to <addr>` ran the remap at rc 0**
  before `95d56cc` — a live write-path defect found by extending the render-side
  fix to the sibling the SYNC marker binds.
- **Neither step-5 fix moves this repository's own collection**, and both were
  checked rather than assumed. Scanning the Issues section for a `key:` whose
  value begins with whitespace returns nothing across all 402 rows, and the
  collection holds seven `depends-on` edges across three distinct targets, all
  of them present — one blocked record before `52d071e` and one after. These
  changes matter only for a collection that has drifted, which is exactly when
  a read view is most trusted.
- **An invalid relation target never becomes an edge at all.** `index.sh`
  refuses it with `invalid relation target` and drops it, so the record reads
  unblocked and no Graph edge exists. That is a different path from `#389`'s,
  and the one case where the operator is already told.
- **`index.sh` warns about a missing umbrella but not a missing dependency.**
  `names an umbrella not in the collection` fires for an unresolvable `part-of`
  target; `depends-on` has no analogue. The collection already has the shape of
  that check for one relation type and not the other. Unfiled.

## 4. Decisions whose reasoning lives only here

- **`#392` was two seams, and the rule chosen for the first is what let the
  second stay safe.** `filter_axis_add` is the function step 2 changed to refuse
  an operand yielding no alternative, and the edge trim is what made that work —
  `case_issues_render_operand_naming_no_alternative_refuses` loops
  `',,,'  '   '  ','  ' , '` and asserts every one is refused. Simply dropping
  the edge trim would have made `'   '` a non-empty value, recorded as an
  alternative matching nothing rather than refusing, undoing half of `#390`.
  The rule adopted instead: whitespace beside a comma is the list's formatting
  and goes; whitespace at the operand's own edge is part of the value; an
  alternative that is *nothing but* whitespace names no value and is dropped.
  That third clause is what keeps the refusal reachable, and it is the reason
  an identity recorded as pure whitespace is deliberately still unreachable.
  The consequence to know: a value carrying edge whitespace is namable at a
  list's own edges but not beside its commas — `--filed-by 'carol, bob '`
  reaches both records, `--filed-by 'bob , carol'` reaches only `carol`.
- **The `#392` reader fix was taken here rather than filed**, on the developer's
  call, because it is the same disagreement one surface further in and wider
  than identity: the index recorded `unrecognized type` while the view served
  the same record as recognized. Filing it would have meant a closed-on-arrival
  issue, which the capture gate forbids — so it lives in `2a22a21`'s message and
  `#392`'s resolution instead, and has no ordinal.
- **`#389` took the first of its three options — block on an unresolvable
  target — not the disclosure.** The wrong *answer* was the harm; a disclosure
  would have left it standing beside a note about it. The third option
  (lean on the index's warning) was removed by running it: that warning reports
  missing reciprocity and fires for a resolvable dependency too. Disclosure
  remains available on top, and would now be a note about a blocked record
  rather than a caveat on an unblocked one.
- **`#395` dropped the emission-site sanitizer rather than adding a second
  pass**, and the reason is measured, not aesthetic: `status`/`outcome`/`type`
  have one assignment site each, fed by the sanitized value, so re-applying an
  idempotent transform on the hot path costs 11 seconds a regeneration and buys
  a guarantee a test already held.
- **Three blueprint invariants changed across the session, all additive.**
  `placeholder-by-position` was **strengthened**, not folded — the code
  implements a strictly narrower mechanism than the invariant described.
  `declared-vocabularies` was added, recording the property whose absence
  produced the enumeration defects. `row-shape-is-the-writers` was added for the
  row-forgery property `row_safe`'s header already argued but no invariant
  named. No Provides entry was ever touched, so no blast-radius grounding
  applied.
- **`#402` resolved `fix the code`, not `fold the intent`.** The judge returned
  `partial` on `declared-vocabularies` because `ISSUE_OUTCOMES` is declared in
  both `index.sh` and `transition.sh`, and one type vocabulary wears two names
  (`ISSUE_TYPES`, `TYPE_TOKENS`) — no SYNC marker on any of the four, no test
  comparing any pair. Folding would encode a regression as intent. **The
  duplication predates the range**; it reached the fork because judges are
  selected by what a change touches, not by what introduced the finding.
- **`remediation.md` was wrong twice in one sentence, now corrected.** It read
  "clear both blueprint violations and four of the five partial ACs". Steps 1+2
  clear **one** violation (`staleness-gated-reads`) and **three** partial ACs.
  `#386` is the second violation. The count error came from never mapping the
  five partial ACs back to their findings — 1, 3, 2, 6, 9, of which steps 1+2
  cover three.
- **`#386` was fixed by having callers declare placeholder positions** — the
  first of three shapes its issue proposed. It cost a sweep across both test
  files, 116 invocations, and that churn *is* the point: substitution follows a
  statement rather than a convention. `#270` proposed passing dir and token
  through the environment instead; not taken, because each entry script needs
  the value in a specific argv slot.
- **A column that cannot be answered refuses rather than disclosing.** One rule
  for both surfaces. `remediation.md` leaned the other way; the developer chose
  refusal. A *configured* `issue_list_cols` still degrades.
- **`migrate.sh`'s boundary test was retuned, overriding a documented prior
  decision** whose own comment warned against exactly that tightening. Retuned
  on the reasoning that the original rationale covered addresses wearing *one*
  leading hyphen, not two. Reversible.
- **`faces=23` is recorded on the ledger verbatim** although known to be an
  undercount. Substituting a hand count would break comparability and violate
  the rule that counters are script-emitted. Correcting it belongs in `#374`.
- **The axis alternatives are newline-separated, not space-separated** as the
  plan's Interface Contract specifies. A deliberate deviation, recorded in
  `review.md` § *vs. Plan tasks*. Do not "restore" the contract's letter.
- **`--cols` and `unblocked` were explicit additions the developer pulled into
  scope** after they had been proposed as out of it. Not scope creep to trim.

## 5. Traps and environment

- **Read the configuration; do not trust any transcription of it.** Every gate
  and cap lives in `jimconf.toml`. `bash skills/conf/scripts/jimconf.sh get
  <key>` is the answer.
- **`mktemp` + `mv` clobbers file permissions.** A sweep during the citation
  purge stripped the exec bit from three scripts and dropped three more to
  `0600`. `git diff --summary` names it (`mode change 100755 => 100644`); a
  comment-only diff carrying one is easy to wave through.
- **Editing these scripts by line number is fragile.** `place.sh`'s `cmd_commit`
  was corrupted by an off-by-one range delete. Anchor on a unique literal, verify
  the anchor is unique *first*, and `bash -n` after every edit. A `case` arm
  pattern that appears in two functions matches both.
- **Test timings vary enough that only the order of magnitude carries.**
  `bash tests/issues.sh` is **~400s** for its 401 cases, and the aggregate
  `skills/meta-test/scripts/run.sh` took **~18 minutes** at 1623 and
  **~22 minutes** at 1628, on different days under different load. Two earlier
  handoffs recorded 171s and ~35 minutes, both wrong. Measure; do not
  transcribe. Every foreground wait will time out; background the run and poll
  a log.
  `transition.sh close` costs ~45s per issue because it regenerates the index
  over ~400 records.
- **A suite log can contain a NUL byte, and then `grep` goes silent.** Some case
  writes one, so `grep -c '^PASS' run.log` reports nothing at all rather than a
  count — it has decided the file is binary. Use `grep -a` for every read of a
  run log. A watcher that greps without it waits forever on a run that finished.
- **Never edit a test file while `bash <that file>` is running.** Bash reads a
  script incrementally and keeps a byte offset into it, so an edit that shifts
  offsets can make a running interpreter resume mid-token. Any result from a
  run that straddled an edit is untrustworthy whatever it reports — kill it and
  start again rather than reasoning about whether the edit was "far enough
  down". Confirm no runner survives first: `pgrep -fa 'tests/issues\.sh'`, then
  kill **by PID**, never by pattern — a pattern matches the shell issuing it.
- **Do not put `&` inside a call already backgrounded by the harness.** The
  launcher returns immediately, the harness reports *its* exit status as the
  run's, and the suite keeps going unsupervised. That is how two concurrent
  runs over one edited file happened here; the first was still alive an hour
  later. Background the plain command and let the harness track it.
- **New test cases splice in before the standalone-runnable tail block** at the
  end of `tests/issues.sh`. There is also a *comment* block with a similar name
  mid-file — that one is prose, not the tail.
- **`/jim:blueprint --since` takes `<ref> <group>`, not a range.** The verify
  engine's `--since` also **skips the registry rung entirely**; say so when
  reporting rather than letting it read as covered. All 15 invariants are
  `judge` method, so the mechanical floor produces no invariant outcomes at all
  — only territory-conformance facts.
- **The `docs/issues/` collection reads as outside the group's territory.** That
  is correct: it is the data the group operates on, not group source. Report it
  bucketed-informational, never as a stray.
- **The coordination remote is unreachable from this VM.** Filing returns a `P-`
  provisional identity; the developer realizes it on the host via `/jim:issue
  reconcile`. Nothing is pending right now — expect any new filing to be
  provisional again.
- **`issue_placement` resolves to `branch` by default but `place.sh mode` prints
  `direct` in this checkout.** Check `mode`, not the config key.
- **Never hand-edit `ARCHITECTURE.md`.** It currently describes placeholder
  substitution as whole-argument matching — true, but now incomplete, since
  substitution is position-declared. That refresh is a `/jim:arch` job.
- **The Bash tool's working directory persists between calls.** Prefer absolute
  paths or `cd /mnt/src/jim && …`.
- **Do not push.** Git push is host-only from this sandbox.

## 6. If you are picking up from here

**The plan can be closed honestly.** All three gating issues are fixed, their
tests pin them, the suite is green at 1628, and the living-intent sensor has
been run twice against the fixes rather than the original build. Marking
`plan.md` `status: complete` is a single question to the developer.

Six things worth carrying, all re-confirmed across the remediation and the
test-debt close that followed it:

- **Reproduce the reproduce before you trust it.** This is the one that earned
  its place in step 5, and `#396` supplied a third instance from a different
  direction. Both step-5 issues were filed with a concrete recipe that was
  wrong about the input while right about the defect: `#392` named `" alice"`,
  which already worked, and missed `"bob "`, which worked under no spelling at
  all; `#389` named a warning as the existing safety net, and that warning
  fires just as loudly for a dependency that resolves. `#396` carried no recipe
  at all — six behaviours "correct by code trace" — and two of the six were
  described wrongly, which only running them showed. A characterization test
  written from a trace pins whatever the trace got wrong.
- **A test that passes on its first run has proved nothing yet.** That is also
  what a test asserting nothing looks like, and `#396`'s five were all green
  immediately. Break the behaviour each one claims to pin and watch it fail.
  One of those five deliberate breaks silently failed to apply, and the case
  passed for the wrong reason — the check caught the check.
- **Fix the shared cause, not the instance.** `#393` named one file and 82% of
  the work was in the other five. `#395` reported one count and was three
  classification sites. `#392` named one trim and was two, applied at opposite
  ends of the same path and cancelling. Take the same reading of what is left.
- **Derive test domains from the code's own constants.** The cases loop
  `AXIS_FIELDS`, `COL_TOKENS`, `RENDER_OPTIONS`, `SCHEMA_GATED_FIELDS`, and
  `index.sh`'s `ISSUE_*` vocabularies, failing on a declared member with no
  mapping — so a new one cannot enter the code without entering the guard's
  test. Extend that, don't sample.
- **Reading finds what is missing; running settles why.** Independent judges
  found `#399`, `#400` and `#402` by reading. Execution confirmed `#399`'s
  mechanism, measured the 41s→52s cost that shaped `#395`, caught a `grep`
  pattern that would have filed a false finding, and overturned the stated
  premise of two of the three options `#389` offered. A green suite
  distinguished none of them.
- **Check the issue collection before reporting a measurement as new.** Twice
  in one session a "new" finding about `#374` was already in its Census
  section, written the day before. Read the issue, then measure.
