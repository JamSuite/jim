# Context — read-view filter composition

A closing handoff for whoever picks this up. It replaces the cold-start
document written before the remediation ran, and keeps that document's one
rule: **it records findings and points at configuration.** Anything below that
looks like a setting is a pointer — go read the setting.

It records what is **expensive or impossible to re-derive from the artifacts**:
facts established by running things, reproduction recipes, decisions whose
reasoning lives nowhere else, and the traps that cost real time. Everything
already said well in `spec.md`, `plan.md`, `review.md`, `remediation.md` or
`retrospective.md` is pointed at, not repeated.

---

## 1. Where this stands

The feature is **built, reviewed, and remediated through step 3**. The three
issues that gated the plan are fixed, verified and closed. The plan is still
held at `approved` — closing it is a single decision, described in § 6.

| artifact | state |
| :--- | :--- |
| `spec.md` | `approved` — 35 acceptance criteria |
| `research.md` | `Needs PM Review` — the VISION contention, explicitly non-blocking |
| `security.md` | `Needs Plan Review` — 12 findings, all routed and applied |
| `plan.md` | `approved` — 21/21 tasks `[x]`, **held**, and now closeable |
| `review.md` | `minor-drift` — 13 findings, `undelegated=0` |
| `remediation.md` | the order of attack — steps 1–3 are done |
| `retrospective.md` | why it happened; the root cause and its prevention |
| living intent | re-run this session: 13 sensed · 10 holds · 2 violated · 1 skipped |
| contracts | 4 edges checked, 0 violations |

Two frontmatter values look wrong and are not, the same trap the preceding
increments record. **`security.md` stays `Needs Plan Review`** — the field
records what a review *found*, not whether it was acted on. **`research.md` is
`Needs PM Review`** because Peer Feedback carries the `VISION.md:67` contention
(issue #380, filed, not actioned). Non-blocking.

### What this session did

Nine commits, `0e55946..HEAD`:

| commit | what |
| :--- | :--- |
| `9f292f0` | `#387` + `#388` — one `schema_gate` both read verbs call |
| `95d56cc` | `#390` + `#397` — an operand that names no filter refuses |
| `9cc6185` | `#386` — placeholders substitute only at declared offsets |
| `19c6c5e` `22c1980` `6997468` | verify record, blueprint update, map restamp |
| `b22b68b` `ff1cd5c` `15d0556` | issues filed, ordinals realized, five closed |

**Closed:** `#386`, `#387`, `#388`, `#390`, `#397`, each carrying a resolution
note that says what fixed it, what pins it, and — for `#387` — what remains
open. Read those notes before re-deriving anything about the fixes.

**Filed:** `#399` (schema gate misses a partly converted collection, medium),
`#400` (SKILL.md inlines title and origin into the emitter command line,
critical). Both came out of the living-intent sensor, not the review.

**Raised:** `#374` to high, with a section recording that the face undercount
accumulates in ledger history rather than merely displaying.

### What remains, in `remediation.md`'s order

- **Step 4** — `#391` (`is_filter_token` has no callers) and `#393` (comments
  citing spec / AC / Finding ids). Both deletions. `#393` wants a sweep across
  the sibling scripts in one pass, or it gets forgotten half-done.
- **Then** `#392`, `#395`, `#389` — real, small, none urgent.
- **`#396`** as the surrounding code is next touched, except its fifth item.
- **`#394` and `#398` last, and deliberately.** Neither is a defect today.
- Outside the remediation: `/jim:arch` (see § 5), and the two corrections in § 4.

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

1. **`remediation.md`** § *Suggested remediation* → *Order*, and § *What not to
   do*. Steps 1–3 are done; the rest of the order stands. **One claim in it is
   wrong** — see § 4.
2. **`retrospective.md`** § *Root cause: one set, three enumerations* — the
   single most useful page here, and the reason the fixes took the shape they
   did.
3. **The five closed issues' Resolution sections** — `#386`, `#387`, `#388`,
   `#390`, `#397`. Written to be read after the fact rather than to justify a
   commit; they carry the reproduction evidence.
4. **`docs/specs/issue/000-blueprint/spec.md`** — the group's invariants. Two
   changed this session (§ 4). This is the specification the code answers to.
5. **`BLUEPRINT.md`** — the project map: the four groups, their territories,
   and the derived contract graph. Read it to see where `issue` sits and what
   depends on its face before changing anything the other groups consume.
6. **`review.md`** § *Findings* and § *Living intent* — the evidence behind each
   issue, with `file:line` anchors.
7. **`spec.md`** § *Acceptance Criteria* — five were partial; four of those are
   now satisfied by the remediation.
8. The code, in dependency order: `skills/issue/scripts/render.sh` (the whole
   filter surface), then `index.sh` (the row emitter), then `place.sh` →
   `place_substitute`.

`plan.md` is worth reading for its Design Decisions, which carry reasoning the
code comments do not — but it is a **historical** record: two Constitution
Check rows cite the wrong task numbers, and `review.md` says which.

## 3. Facts established by running things

Every one of these was verified in-session by executing it. **Do not re-derive
them by reading**, and note that two of them contradict what a careful reading
first suggested.

### The three fixes, confirmed by probe

- **`#386`.** Probing the wrapper directly settles it. Feed
  `place.sh run --read --token-at <i> --dir-at -1 -- /usr/bin/env printf '%s\n'
  --place-token '{token}' list --label --dir '{}' '{}'` and read what the
  wrapped command receives. Before: **both** `{}` came back as the run's
  collection path. After: the caller's own `{}` survives verbatim and only the
  declared trailing slot is filled. Needs a placement-configured repo — this
  checkout resolves to `direct`, so confirm `place.sh mode` prints `route`
  first or the repro is inert. The recipe for building one is in
  `tests/issues.sh`'s `placement_repo`.
- **`#387` / `#388`.** Against an index whose rows predate the widened row and
  whose mtime is newest, all four recorded behaviours now refuse: `--claimed-by`
  and `--filed-by` on either verb, and the `claimed` / `unclaimed` bare words.
  The refusal names the **row field**, not the axis key.
- **`#390` / `#397`.** `--label ,,,` and `--label '   '` refuse instead of
  matching everything; `--label --nosuchflag` refuses; `--filed-by -alice` is
  still carried, because the boundary is one hyphen versus two.

### The mixed-collection defect (`#399`) — the one the fixes did not close

`schema_gate` detects staleness from a **single witness**: one row carrying a
`type` satisfies it for the whole index. Reproduced by executing it:

```
- `20260101-alpha` — Alpha · … · type: issue · filed-by: dev@example.test
- `20260102-bravo` — Bravo · …                       (legacy: no type)

render.sh list --type issue <dir>   ->  1 of 2 records, rc 0, no disclosure
```

This is the collection's **ordinary steady state**, not an edge case: the
schema conversion is opt-in and nothing forces it. The premise is pre-existing
— it came from the original build — but this increment carried it to `stats`,
to `held`, and to columns. `#399` has the full analysis.

### The face-counter undercount (`#374`, already filed)

`jimverify.sh faces-aggregate` counts only `` - ` ``-prefixed Provides entries
and silently drops every `- **Bold**` one. Backtick-only across the four groups
sums to exactly the 23 the verb reports; the true total is 32, and **sdlc's
entire face measures as zero**. `#374`'s Census section carries the full table
plus a requires-side failure this session did not detect.

**A trap that follows from it:** a `grep -cE '^- \`'` over a Provides section
undercounts the same way. That pattern nearly produced a false `leak` finding
against sdlc during the reconcile. Match `^- (\`|\*\*)`.

### Other verified facts

- **`is_filter_token` still has zero callers** (`#391`) — one occurrence in
  `render.sh`, its own definition. The spec-id-citing comments (`#393`) are
  still there too; take their count from the issue rather than from one grep
  pattern, which misses forms like `security 019 Finding 5`.
- **The aggregate suite is 1617 green** (`skills/meta-test/scripts/run.sh`),
  up from 1608 at the session's start: +9 cases, all looping declared
  constants rather than sampling.
- **`migrate identity --from --nosuchflag --to <addr>` ran the remap at rc 0**
  before `95d56cc` — a live defect on a write path, found by extending the
  render-side fix to the sibling the SYNC marker binds. It was not filed
  separately because the fix and its test landed in the same commit.

## 4. Decisions whose reasoning lives only here

- **`remediation.md` and the previous `context.md` both claim steps 1+2 close
  "both blueprint violations" and let the plan be marked complete. That is
  wrong** — `#386` was the second violation and needed step 3. The conclusion
  is now true because all three landed, but the reasoning that reached it is
  not, and `remediation.md` still carries the error. Correcting it is
  outstanding.
- **Two blueprint invariants changed, both additive.**
  `placeholder-by-position` was **strengthened**, not folded: the code no longer
  implements the "flag's operand or trailing argument" mechanism the invariant
  described, it implements a strictly narrower one, and a judge independently
  characterized the code as stronger than the rule. A new row,
  `declared-vocabularies`, records the property whose absence produced the
  enumeration defects. Neither is a downgrade; no Provides entry was touched,
  so no blast-radius grounding was needed.
- **`#386` was fixed by having callers declare placeholder positions**, the
  first of the three shapes its issue proposed, rather than by narrowing the
  inference or pushing the rule onto every parser. It cost a sweep across both
  test files — 116 invocations now declare their offsets — and that churn *is*
  the point: substitution follows a statement rather than a convention, and a
  caller whose arithmetic drifts is told on its first run. An earlier issue
  (`#270`) proposed passing dir and token through the environment instead; that
  was not taken, because each entry script needs the value in a specific argv
  slot.
- **A column that cannot be answered refuses rather than disclosing.** One rule
  for both surfaces. `remediation.md` leaned the other way; the developer chose
  refusal. A *configured* `issue_list_cols` still degrades, which is the split
  the file already makes between this run's explicit ask and a standing setting.
- **`migrate.sh`'s boundary test was retuned, overriding a documented prior
  decision.** `case_migrate_identity_option_shaped_values_are_still_accepted`
  warned in its own comment against exactly the tightening that was applied.
  It was retuned (and renamed) on `remediation.md`'s reasoning that the original
  rationale covered addresses wearing *one* leading hyphen, not two. The
  rewritten comment states the narrowed boundary and why. Reversible.
- **`faces=23` was recorded on the ledger verbatim** although it is known to be
  an undercount. Substituting a hand count would break comparability with every
  prior event and violate the rule that counters are script-emitted. The number
  is wrong; correcting it belongs in the script.
- **The axis alternatives are newline-separated, not space-separated as the
  plan's Interface Contract specifies.** A deliberate deviation, recorded in
  `review.md` § *vs. Plan tasks*. Do not "restore" the contract's letter.
- **`--cols` and `unblocked` were explicit additions the developer pulled into
  scope** after they had been proposed as out of it. Not scope creep to trim.

## 5. Traps and environment

- **Read the configuration; do not trust any transcription of it.** Every gate
  and cap lives in `jimconf.toml`, and they were changed mid-session in a
  previous run. `bash skills/conf/scripts/jimconf.sh get <key>` is the answer.
- **Editing these scripts by line number is fragile.** `place.sh`'s `cmd_commit`
  was corrupted this session by an off-by-one range delete that removed the
  wrong line and left a dangling fragment. Anchor on a unique literal, guard
  for an empty match, verify the anchor is unique *first*, and `bash -n` after
  every edit. A `case` arm pattern that appears in two functions will match both.
- **Test timings, and they are worse under load.** `bash tests/issues.sh` is
  ~171s for ~390 cases alone, but exceeded 400s while the aggregate was also
  running — run one at a time. The aggregate exceeds 600s; background it.
  `transition.sh close` costs ~45s per issue because it regenerates the index
  over ~400 records, so closing five does not fit in one foreground call.
- **New test cases splice in before the standalone-runnable tail block** at the
  end of `tests/issues.sh`. There is also a *comment* block with a similar name
  mid-file — that one is prose, not the tail.
- **`/jim:blueprint --since` takes `<ref> <group>`, not a range.** Passing
  `0e55946..HEAD` with no group silently reads as the wrong mode. The verify
  engine's `--since` also **skips the registry rung entirely** — say so when
  reporting, rather than letting it read as covered.
- **The coordination remote is unreachable from this VM.** Filing returns a
  `P-` provisional identity; the developer realizes it on the host via
  `/jim:issue reconcile`. Nothing is pending right now — expect any new filing
  to be provisional again.
- **`issue_placement` resolves to `branch` by default but `place.sh mode` prints
  `direct` in this checkout.** Both are true. Check `mode`, not the config key.
- **Never hand-edit `ARCHITECTURE.md`.** It is maintained through `/jim:arch`.
  It currently describes placeholder substitution as whole-argument matching —
  true, but now incomplete, since substitution is position-declared. That
  refresh is outstanding and is a `/jim:arch` job, not an edit.
- **The Bash tool's working directory persists between calls.** Prefer absolute
  paths or `cd /mnt/src/jim && …`.
- **Do not push.** Git push is host-only from this sandbox.

## 6. If you are picking up from here

**The plan can now be closed honestly.** All three gating issues (`#386`,
`#387`, `#390`) are fixed, their tests pin them, the suite is green at 1617,
and the living-intent sensor was re-run against the fixes rather than against
the original build. Both blocking gates were satisfied — `review.md` exists and
the blueprint update ran to completion with its fork answered. Marking
`plan.md` `status: complete` is a single question to the developer, and nothing
needs re-running unless you judge a fresh review worthwhile.

Three things worth carrying while you work, all from `retrospective.md` and all
re-confirmed this session:

- **Fix the shared cause, not the instance.** Every pair in this remediation was
  one enumeration short of one rule. The same judgment applies to what is left:
  `#393` is a sweep, not a file.
- **Derive test domains from the code's own constants.** The new cases loop
  `AXIS_FIELDS`, `COL_TOKENS`, `RENDER_OPTIONS` and `SCHEMA_GATED_FIELDS`, and
  fail on a declared axis they have no query for — so a new axis cannot enter
  the grammar without entering the guard's test. Extend that, don't sample.
- **Reading finds what is missing; running settles why.** Independent judges
  found `#399` and `#400` by reading. Execution is what confirmed the mechanism
  of `#399` and what caught a `grep` pattern that would have filed a false
  finding. Neither substitutes for the other, and a green suite distinguished
  neither.
