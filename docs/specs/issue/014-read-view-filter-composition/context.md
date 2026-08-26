# Context — read-view filter composition

A closing handoff for whoever picks this up. The session that built, reviewed
and analysed this increment is over and will not resume, so this is written for
a **cold start** rather than for recovery from compaction.

It records what is **expensive or impossible to re-derive from the artifacts**:
facts established by running things, reproduction recipes, decisions whose
reasoning lives nowhere else, and the traps that cost real time. Everything
already said well in `spec.md`, `plan.md`, `review.md`, `remediation.md` or
`retrospective.md` is pointed at, not repeated.

One rule this document learned from its own previous version: **it records
findings and points at configuration.** The mid-flight handoff it replaces
transcribed config values and was wrong within hours of the developer changing
them. Anything below that looks like a setting is a pointer — go read the
setting.

---

## 1. Where this stands

The feature is **built and shipped**; the increment is **not finished**. The
plan is deliberately held at `approved` while remediation is outstanding.

| artifact | state |
| :--- | :--- |
| `spec.md` | `approved` — 35 acceptance criteria |
| `research.md` | `Needs PM Review` — the VISION contention, explicitly non-blocking |
| `security.md` | `Needs Plan Review` — 12 findings, all routed and applied |
| `plan.md` | `approved` — 21/21 tasks `[x]`, **held** pending remediation |
| `review.md` | `minor-drift` — 13 findings, `undelegated=0` |
| `remediation.md` | the order of attack — **read this first** |
| `retrospective.md` | why it happened; the root cause and its prevention |
| living intent | 13 sensed · 7 holds · **2 violated** · 4 skipped by scope |
| contracts | 1 edge affected, holds |

**Next action:** remediate, in the order `remediation.md` § *Suggested
remediation* → *Order* recommends. Nothing there has been approved — the
sequencing is a recommendation, and the developer has seen it.

Two frontmatter values look wrong and are not, the same trap the two preceding
increments record:

- **`security.md` stays `Needs Plan Review`.** The field records what a review
  *found*, not whether it was acted on. All findings were routed and applied.
- **`research.md` is `Needs PM Review`** because Peer Feedback carries the
  `VISION.md:67` contention (issue #380, filed, not actioned). Non-blocking.

### The thirteen issues

`#386`–`#398`, all realized (no provisional ordinals remain). Two are high; two
are blueprint violations; they overlap by one. `remediation.md` groups and
sequences them. The three that gate the plan's completion:

- **`#386`** (high, blueprint violation `placeholder-by-position`)
- **`#387`** (medium, blueprint violation `staleness-gated-reads`)
- **`#390`** (high, the worst user-visible defect — a narrowing filter widens)

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

Read in this order. The first two are short and change how the rest reads.

1. **`remediation.md`** — what is open, what the issues have in common, and the
   order to fix them in. Its § *What not to do* is load-bearing.
2. **`retrospective.md`** § *Root cause: one set, three enumerations* — the
   single most useful page here. It explains why five of the thirteen issues are
   the same defect wearing different labels.
3. **`review.md`** § *Findings* and § *Living intent* — the evidence behind each
   issue, with `file:line` anchors.
4. **`docs/specs/issue/000-blueprint/spec.md`** — the group's invariants. Both
   violations resolved *fix the code*, so the blueprint declares properties the
   code must **return to**. It is the specification for the remediation, not a
   record of what the code does.
5. **`spec.md`** § *Acceptance Criteria* — five are partial; `review.md`
   § *vs. Spec acceptance criteria* names which and why.
6. The code, in dependency order: `skills/issue/scripts/render.sh` (the whole
   filter surface), then `index.sh` (the row emitter), then
   `skills/issue/scripts/place.sh` → `place_substitute` (for `#386` only).

`plan.md` is worth reading for its Design Decisions, which carry reasoning the
code comments do not — but note it is a **historical** record now: two of its
Constitution Check rows cite the wrong task numbers, and `review.md` says which.

## 3. Facts established by running things

Every one of these was verified in-session by executing it. Several contradict
what a careful reading first suggested, and three corrected claims that had
already been written down confidently. **Do not re-derive them by reading.**

### The stale-index behaviours (`#387`)

Against an index whose rows predate the widened row and whose mtime is newer
than every issue file, holding one issue with `claimed-by` set:

```
render.sh list --claimed-by <holder> <dir>   rc=1  refuses, names repair   ✓
render.sh list unclaimed <dir>               rc=0  lists the HELD record   ✗
render.sh list claimed <dir>                 rc=0  _No matching issues._   ✗
render.sh stats --filed-by <filer> <dir>     rc=0  Open: 0 · Closed: 0     ✗
```

The `unclaimed` line is the important one: a **populated, wrong** answer, not an
empty one. An early write-up of this called it an empty result; that was wrong.

**Recipe.** `tests/issues.sh` already carries the fixture — `strip_new_scalars`
(search for it) rewrites an index's rows as a pre-widening emitter would and
`touch`es it newest. Its only current consumer drives `list` with two axes; a
remediation test should drive every axis and both verbs.

### The empty-operand widening (`#390`)

Two issues, one labelled `auth`:

```
render.sh list --label auth <dir>    1 match    (correct)
render.sh list --label ,,, <dir>     2 matches, rc 0
render.sh list --label '   ' <dir>   2 matches, rc 0
```

An operand yielding no alternative leaves the axis key unassigned, and every
matcher reads an unassigned axis as one nobody named.

Related, same family: `render.sh list --label --nosuchflag <dir>` binds
`--nosuchflag` as a label value at rc 0 (`#397`), and an operand containing a
literal newline is truncated at the first line.

### The placeholder rewrite (`#386`)

Needs a placement-configured repository — this checkout resolves to `direct`, so
it will not reproduce here. Recipe, mirroring `tests/issues.sh`'s
`placement_repo`:

```bash
git init -q <repo> && cd <repo>
git config user.name T && git config user.email tester@example.test
printf 'issue_placement = "jim/issues"\n' > jimconf.toml
printf 'base\n' > README.md && git add -A && git commit -qm base
# file one issue through new.sh --reviewed, then:
bash <jim>/skills/issue/scripts/render.sh list --label --dir '{}'
```

The refusal names the run's **real materialized collection path** — the caller's
own `{}` was rewritten with it. Confirm `place.sh mode` prints `route` first; if
it prints `direct` the repro is inert.

### The census/Summary divergence (`#395`)

An issue whose frontmatter carries `status: "closed<0x01>"` — a `closed` followed
by a control byte, which is not whitespace and so is not trimmed:

```
grep -E '^- (Open|Closed):' <dir>/INDEX.md   ->  Open: 1 · Closed: 0
render.sh stats <dir>                        ->  Open: 0 · Closed: 1
```

`index.sh` classifies the **raw** value; `render.sh` classifies the **sanitized**
one read back from the row. The previous code echoed the Summary verbatim and
could not diverge.

### The structural fact underneath five of the issues

`render.sh` declares **seven** vocabularies as `readonly` constants —
`STATUS_TOKENS`, `PRIORITY_TOKENS`, `TYPE_TOKENS`, `HELD_TOKENS`,
`BLOCKED_TOKENS`, `COL_TOKENS`, `RENDER_OPTIONS`. The **axis** vocabulary is the
one it does not. Axis names exist in three places instead: the flag `case`
pattern (derived via `${a#--}`), the bare-word `elif` chain (literals), and the
staleness guard's own `for ax in type filed-by claimed-by`.

Three enumerations of one set; the third is a strict subset, and the gap is
exactly `held`. `retrospective.md` develops this; it is the thing to fix, and
fixing it closes `#387` and `#388` together.

### Other verified facts

- **`is_filter_token` has zero callers** (three before this build). Verified by
  repository-wide grep; the only other mentions are in spec artifacts describing
  the historical bug. `#391`.
- **The `is_valid_id` triplicate is byte-identical** across `render.sh`,
  `index.sh` and `jimfile.sh` (verified by hash), and its asserting test passes.
- **ARCHITECTURE.md contains no literal row-shape passage.** `research.md` claims
  it "describes a six-field row" needing correction. It does not. That claim
  survived four stages before the arch refresh went looking for the passage.
- **The real collection's index was itself stale** in exactly the `#387` sense
  after the build, and the guard fired correctly on `--claimed-by me`. It has
  since been regenerated (+12.0%, 141,844 → 158,856 bytes). A remediation test
  needs the fixture above; the live collection will no longer reproduce it.

## 4. Decisions whose reasoning lives only here

- **The axis alternatives are newline-separated, not space-separated as the
  plan's Interface Contract specifies.** A deliberate deviation, flagged at the
  time and recorded in `review.md` § *vs. Plan tasks*. A space separator splits
  an `--origin` value containing a space into two alternatives and silently
  widens the query — the failure the plan's own DD 8 exists to prevent. Do not
  "restore" the contract's letter.
- **Both invariant violations resolved *fix the code* at the blueprint fork.**
  The blueprint therefore still declares `placeholder-by-position` and
  `staleness-gated-reads` as they were. **Do not fold either to match the current
  code** — that would encode a regression as intent, and for `#387` would mean
  writing down that a census may answer confidently from an index it knows
  cannot answer.
- **The graph-slug narrowing was fixed inside this increment rather than
  deferred** (issue #381, closed by task 4). Two new axes would otherwise have
  become copies three and four of a pattern already known to be wrong. The same
  judgment applies to the remediation: fix the shared cause, not the instances.
- **`--cols` and `unblocked` were explicit additions the developer pulled into
  scope** after they had been proposed as out of it. Not scope creep to trim.
- **The review bundled 35 ACs into 5 investigators** rather than one per AC, with
  a cap of 20 and only 14 used. A judgment about diminishing returns, not a cap
  effect; `review.md` § *Coverage* says so. Whether per-AC dispatch finds more is
  untested.

## 5. Traps and environment

- **Read the configuration; do not trust any transcription of it.** The gates in
  force (`require_security`, `auto_security`, `require_review`, `auto_review`,
  `require_blueprint`, `require_health`, the fan-out caps and models) all live in
  `jimconf.toml` and were changed mid-session once already.
  `bash skills/conf/scripts/jimconf.sh get <key>` is the answer.
- **The Bash tool's working directory persists between calls.** An early `cd`
  into a subdirectory broke a later relative-path invocation. Prefer absolute
  paths or `cd /mnt/src/jim && …`.
- **Editing these scripts by line number is fragile.** `render.sh` was corrupted
  twice this session by `awk`/`sed` splices whose bounds were off by one or whose
  anchor matched nothing — an empty match variable silently truncates the file.
  Anchor on a unique literal, guard for an empty match, and `bash -n` after every
  edit. `git checkout --` is cheap; a half-written script is not.
- **Test timings.** `bash tests/issues.sh` is ~171s for 384 cases — foreground is
  fine. The aggregate `bash skills/meta-test/scripts/run.sh` exceeds 600s for
  1,608 cases — run it in the background and wait on it.
- **New test cases splice in before the standalone-runnable tail block** at the
  end of `tests/issues.sh` (the `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` guard).
  There is also a *comment* block with a similar name mid-file — that one is
  prose, not the tail.
- **The coordination remote is unreachable from this VM.** `jimalloc allocate`
  returns a `P-` provisional identity and the developer realizes it on the host
  via `/jim:issue reconcile`. All thirteen from this session are realized; none
  is pending. Expect any new filing to be provisional again.
- **`issue_placement` resolves to `branch` by default but `place.sh mode` prints
  `direct` in this checkout.** Both are true and not in conflict — check `mode`,
  not the config key, when reasoning about routing.
- **Never hand-edit `ARCHITECTURE.md`.** It is maintained through `/jim:arch`; a
  surgical edit bypasses the skill and stales its Last-updated header.
- **Do not push.** Git push is host-only from this sandbox.

## 6. If you are picking up the remediation

Start with `remediation.md` § *Order*. Its first two steps close both blueprint
violations and four of the five partial acceptance criteria, and they are what
lets the plan be marked complete honestly.

Three things worth carrying in from `retrospective.md` while you work:

- **Fix the shared cause, not the instance.** `#387` and `#388` are one fix
  wearing two labels; so are `#390` and `#397`. Fixing either pair by halves
  leaves the other half looking deliberate.
- **Derive test domains from the code's own constants.** The reason the original
  suite could not catch `#387` is that its test exercised the same two axes the
  implementation enumerated — one context wrote both. A loop over an
  `AXIS_TOKENS`-style constant catches the next one automatically; a hand-picked
  pair never will.
- **Smoke-test by enumeration, not by selection.** Every bare word and every flag
  once against the real collection is ~23 invocations and costs nothing. The
  original smoke test covered the axes the guard was built for, which is the same
  blind spot one level up.

When the remediation is done, the completion gate is a single question to the
developer: mark `plan.md` `status: complete`. Both blocking gates
(`require_review`, `require_blueprint`) were satisfied during this session —
`review.md` exists and the blueprint update ran to completion with its fork
answered — so nothing needs re-running unless the code changes make a fresh
review worthwhile. That is a judgment call; `remediation.md` does not presume it.
