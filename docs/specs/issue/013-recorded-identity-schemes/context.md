# Context — recorded identity schemes

A closing handoff for whoever picks this up. The session that built it is over
and will not resume, so this is written for a cold start rather than for
recovery from compaction.

It records what is **expensive or impossible to re-derive from the artifacts**:
facts established by running things, decisions whose reasoning lives nowhere
else, and a few traps that cost real time. Everything already stated well in
`spec.md`, `plan.md`, `review.md` or `remediation.md` is pointed at, not
repeated.

---

## 1. Where this stands

The feature is built, the collection is converted, and the increment is
**finished**.

| artifact | state |
| :--- | :--- |
| `spec.md` | `approved` — 33 acceptance criteria |
| `research.md` | `Active` |
| `plan.md` | `complete` — 21/21 tasks `[x]`, 17/17 review issues |
| `security.md` | `Needs Plan Review` — 16 findings, all applied |
| `review.md` | **`major-drift`** — 14 findings |
| `remediation.md` | the analysis, the fix order, and what has executed against it |

`plan.md` reads `status: complete` as of 2026-08-25. It had been held at
`approved` because two critical issues from the review were open and unfixed,
and marking it complete would have made the plan's status contradict its own
review. All seventeen are closed, so the gate closed with them.

Two frontmatter values look wrong and are not:

- **`security.md` stays `Needs Plan Review`.** That field records what a review
  *found*, not whether it was acted on. The previous spec's did the same
  through its build. Do not "fix" it.
- **`research.md` is `Active`** because its status gates whether planning
  proceeds. Different field, different semantics.

### What the remediation has closed

**All seventeen**, in eight batches. First the two that blocked — `#365`, the
bracket bypass past the recorded-identity charset gate, and `#360`, a path
composed from an unvalidated slug — then the fail-open pair (`#358`, `#361`),
the documentation set (`#368`, `#364`, `#369`, `#370`), the test-quality pair
(`#362`, `#357`), the contract declaration (`#367`), the small-correctness batch
(`#359`, `#356`, `#371`, `#366`), the mechanical sweep (`#363`), and the
line-length convention (`#355`).

Both blueprint violations are cleared. `/jim:verify issue` returned
`identity-validated-before-record` and `id-gate-before-path` as `holds` under
judges reading the code without being told what changed, and the group ledger
carries both records — `violated=1`, then `violated=0` — so the trajectory is
visible rather than amended away.

`#53` is open and critical, and predates this increment.

Seven issues were filed *by* the remediation rather than fixed by it — `#372`,
`#373`, `#374` out of the contract-declaration pass, `#377` and `#376` out of
the census behind them, `#375` out of the mechanical sweep, and
`#378` out of the line-length one. None is part of the seventeen. Three cannot
be closed from this group at all, because the undeclared halves belong to
`platform`'s and `sdlc`'s faces.

`#377` is the root the other contract-graph issues are instances of: no
`Requires` token on any face resolves to any `Provides` entry, because the two
halves are named in disjoint vocabularies — the artifact on one side, the
capability on the other. Three of the reconcile pass's six finding classes are
decided by reading prose as a result. It is a larger piece of work than anything
in the seventeen and was deliberately not folded into them.

**Read `remediation.md` § *Where this analysis under-scoped the work* before
touching any of them.** Every issue closed reached further than it named —
seventeen for seventeen — and the section says how each extra site was found.
Not one was found by re-reading the issue. That is the single most transferable
thing this cycle produced, and it kept recurring after it had been written down.

Three of those are worth knowing before the rest. The sharpest is the one where
the wrong census looked right: asked whether any other group face had `#367`'s
gap, enumerating the *declared* contract edges answered "exactly one" — and
could not have answered otherwise, since it searched only edges someone had
already declared. Censusing the code's sync markers instead found three
couplings where the issue named one. **Census the rule's mechanism, not the
registry of things already recorded.**

The second runs the opposite way. `#371` reported two quiet failure paths as one
inconsistency; the second turned out to be deliberate, and "fixing" it would
have discarded a developer's edits to make the code look symmetrical. A census
can widen an issue and it can also cut one in half, and the second only happens
if you check whether the thing that looks wrong is actually wrong.

The third is that the fix for a symptom is not always the fix for the problem.
`#355` reported line lengths and wrapping is what it asked for — but wrapping
alone would have left `/jim:arch`'s own instruction to read the document *fully*
exactly as unfollowable, because reflowing a file does not shrink it. What was
left after the rewrap was a different problem wearing the same symptom, and it
is filed rather than folded in.

---

## 2. Building deep context

**This document is not enough grounding to change this code.** Read in this
order; the two blueprints are not optional.

### First — `docs/specs/issue/000-blueprint/spec.md` (the group's blueprint)

This is the `issue` group's current-state specification: what it is
responsible for, the surface it exposes, and the **thirteen invariants its code must
uphold**, each with a criticality and a verification method. It is the document
that decides whether a change to this group is correct, and it is what
`/jim:verify` judges the code against.

Two of those invariants were violated by this increment
(`identity-validated-before-record`, `id-gate-before-path`) and now hold again.
Read them anyway before changing this code: the invariant text is what both
fixes were written against, and in both cases it reached further than the issue
titles suggested — `id-gate-before-path` turned out to cover four composition
sites where the issue named two.

The `identity.sh` **Provides** entry declares four verbs and the form/mapping
behaviour, and asserts a refusal guarantee the code now honours. The tension
that made it worth flagging is resolved.

### Second — `BLUEPRINT.md` (the project context map)

The project is partitioned into four groups — `sdlc`, `blueprint`, `issue`,
`platform` — each a deliberate context boundary with a declared territory. Read
it for three things:

1. **Which territory a file belongs to.** This work touched `skills/issue/`
   (the `issue` group) *and* `skills/conf/scripts/jimconf.sh` plus
   `tests/jimconf.sh` (the `platform` group). That straddle is ordinary — a
   domain group adding a key to the shared config registry — but it means a
   change here can require a second group's blueprint to agree.
2. **The contract graph.** Seven edges name `issue` as a provider. One is
   directly load-bearing for this code: `platform → validator-lockstep`, which
   requires `is_valid_id` to stay byte-identical across `jimfile.sh`,
   `index.sh` and `render.sh`. This increment edits `index.sh`. The function
   was not touched and all three copies still cksum `3250514351` (508 bytes) —
   **verify that again after any `index.sh` change.**
3. **What the map does not do.** It never restates a group's face. The group
   blueprints are authoritative for surfaces and invariants; the map is
   authoritative for the partition. If the two disagree, the map is about
   boundaries and the blueprint is about content.

### Third — the code, in dependency order

`skills/issue/scripts/identity.sh` is the whole definition of a recordable
identity and should be read end to end before anything else in the group. Then
its consumers: `new.sh` (filer at filing), `transition.sh` (holder at a
transition), `migrate.sh` (the conversion's recovered filer, and the `identity`
rewrite subcommand), `index.sh` (the configured-form mismatch warning).

### Fourth — `ARCHITECTURE.md` § Security Considerations → Recorded identity

Two bullets, refreshed by this build. **Read them with a bounded tool call.**
That file has 23,000-character lines and a naive read exceeds the token cap; see
§ 5. The Recorded-identity bullets are around line 344 and are ordinary length.

### Also worth reading, in order of payoff

- `remediation.md` — the issue analysis and suggested fix order. Do not
  re-derive it.
- `review.md` § *Investigation* — what was examined and, importantly, the three
  findings that were **refuted**. Two of them are the kind a careful reader
  regenerates from first principles; the refutations are recorded so you do not
  spend the afternoon rediscovering that they are wrong.
- `docs/notes/process-improvements.md` — project-wide craft with the evidence
  attached. §§ *Fixtures inherit the author's blind spot* and *Reproduce a
  finding before believing it* were written from this cycle.

---

## 3. Facts established by running things

These cost time to establish and are not recoverable by reading.

**The alias mapping is untracked and governs everything.** `.mailmap` sits at
the repo root, is listed in `.gitignore`, and is **not** in the repository. It
maps four addresses across two contributors onto two forge relay identities.
Every recorded identity in the collection was derived through it. A fresh clone
has no mapping, so a re-normalization there would produce different results —
this is a known and accepted consequence, stated in the spec's Out of Scope.

**Two GitHub relay forms exist**, confirmed against the forge's own reference:
`ID+USERNAME@users.noreply.github.com` (accounts after 2017-07-18) and
`USERNAME@users.noreply.github.com` (earlier, privacy enabled before the
cutoff) — the older form carries **no numeric prefix and no `+` at all**.
Recognition therefore strips the service suffix and then an *optional* leading
`<digits>+`. Requiring the id would record every pre-cutoff contributor as a
full address while everyone else got a handle.

**The two `+` rules run in opposite directions.** This is the likeliest
implementation error in the whole feature:

- relay extraction discards everything **before** the `+` (a numeric account id)
- organization-local discards everything **after** it (a mailbox tag)

Within one organization's domain a tagged address is the same mailbox and so
the same person; in a relay address the same character separates an id from a
name. Same character, opposite halves. Verified correct and not swapped.

**Case folding runs before extraction, contrary to the plan's data-flow
diagram.** The diagram folds last. That order is wrong:
`1234+Dev@Users.NoReply.GitHub.com` fails the exact suffix match, falls through
unextracted, and records as a full address while the same person's lower-case
spelling records as `dev` — precisely the split the spec exists to close.
Folding first is the only order satisfying both the lower-case and the relay
criteria. There is a test pinning it. **The diagram was not corrected; this
note is the record.**

**`git check-mailmap` behaviours**, all verified empirically rather than from
documentation:

- it accepts a bare `<addr>` with no name, and returns `<addr>` unchanged when
  unmapped, preserving case
- lookup is case-insensitive
- `%aE` honours the mapping; `%ae` does not
- `mailmap.file` and `mailmap.blob` redirect where the mapping is read from, so
  "the project's mapping" is not necessarily a file at a known path
- given a malformed multi-bracket contact it returns the **first** parseable
  contact, not the last — this is why the `#365` bypass truncates rather than
  redirects, and why the reported "attribution hijack" was refuted

**The angle-bracket wrapping, not the `--` separator, is what neutralizes
option shape.** `git check-mailmap "<--help>"` with no separator returns
`<--help>` as data. Both mechanisms are in place; the plan's claim that "the
separator is the whole fix" is imprecise. Neither can be individually
mutation-proven, because removing either leaves the regression test green.

**The `--follow` filer recovery can mis-attribute.** Rename detection is
content-similarity based, so two near-identical issue files can be linked and
the later one attributed to the earlier's author. Observed directly with
identical-content fixtures during research. The ambiguity check does not catch
it — a mis-attribution is plausible, not colliding. Accepted deliberately; the
8 issues attributed to the second contributor are worth an eyeball if that ever
matters.

---

## 4. Decisions whose reasoning lives only here

**An unrecognized `identity_scheme` refuses; an absent one takes the default.**
Refusing on absence would break every zero-config project. That distinction is
the whole point and is easy to "simplify" away.

**The mismatch warning has no suppression knob, deliberately.** A signal that
can be switched off stops being a signal. The repetition objection does not
hold because the warning has an exit condition: running the re-normalization
clears it, so it is a finite prompt to finish a migration rather than a nag.

**The ambiguity check has three exclusions, and the third was a bug fix.** Two
addresses do not collide when they differ only in case; when one record already
holds the value another is reaching; or — added after the fact — when the alias
mapping already declares them one contributor. That third exclusion was missing
in the shipped version and disabled re-normalization for exactly the projects a
mapping exists to serve. It was found by running the verb against the real
collection, not by the 30 tests that passed over it.

**The remap mode records `--to` verbatim (case-folded), not through the form.**
An operator supplying a value explicitly gets that value; the mismatch surface
then tells them if it disagrees with the configured form. Applying the form
would silently change what they typed.

**`new.sh` and `transition.sh` were deliberately not touched.** Both already
call `identity.sh resolve`, which is what makes the change small. If a task
starts editing them, something has gone wrong.

**Task 16 was not from this spec.** It fixed two pre-existing sites that
discarded `index.sh`'s exit status. The previous spec's ledger recorded that
fix as `fixed=1` while the code change had never landed — its Red phase failed
on both sites, proving the ledger had been asserting something untrue. The
`staleness-gated-reads` invariant now holds for the first time since it was
declared.

---

## 5. Traps and environment

**`ARCHITECTURE.md` is wrapped now, but still too big to read whole.** Its lines
were up to ~23,000 characters and are wrapped at 80 as of `fb9844c`, so a
bounded read finally costs what it asks for — a forty-line window at the worst
paragraph went from 94 KB to 3 KB. The file itself is unchanged in size: 214 KB,
and a whole-file read is still refused. Read it by `##` section, and by `###`
subsection inside `Plugin Conventions`, which is half the document on its own.
`grep -o` with wide context on this file has been OOM-killed in the past; prefer
`awk` or `sed -n` by line number.

**Reflowing markdown can silently open blocks.** A wrap that puts a word at the
start of a line turns that word into markup if it is `#`, a lone `-`/`*`/`+`, a
`1.`, a `>`, a `|`, or a fence. Prose *about* markdown is where this bites: a
paragraph naming a fenced block produced a line starting with ``` and flipped
fence parity for the rest of the file. The reflow used for `ARCHITECTURE.md`
carries such a word onto the previous line instead, over budget, and eight lines
sit 82–85 characters wide as a result.

**Never hand-edit `ARCHITECTURE.md` or any blueprint.** Use `/jim:arch` and
`/jim:blueprint`. A surgical edit bypasses the skill's grading, its
present-tense and provenance scans, and its `Last updated` stamp.

**A blueprint `Provides` entry must lead with a backticked token.**
`jimverify.sh faces` keys each entry off that token and emits nothing for an
entry that leads with bold, so a bold-first entry is readable by a person and
invisible to the face counters and the mechanical contract floor alike. Nothing
declares this convention, which is why it is here; it is filed as `#374`. Check
a new entry with `jimverify.sh faces <blueprint>` and confirm it appears before
believing the declaration landed.

**A config key's CLI name is not the name it wears in the file.**
`jimconf.sh keys` prints `specs`, `architecture`, `issues`; the `jimconf.toml`
those resolve against spells them `specs_path`, `architecture_path`,
`issues_path`. The resolver appends `_path` to every key outside the bare-name
families its own comment enumerates. So a sweep comparing the CLI names against
a document's table reports every path key as undocumented — a false alarm that
looks exactly like the real one, and one that reads as "README is missing ten
keys" until you check the resolver.

**A doc table can document several keys in one row.** README documents the five
`health_threshold_*` knobs as a single `health_threshold_<signal>` row naming
each signal, which is the better document and invisible to a row-per-key check.
The sweep added for `#363` reads family prefixes out of the document rather than
splitting the key, because two of those five carry an underscore in their own
suffix.

**The ID coordination registry is unreachable from the sandbox VM.**
`id_coordination_unreachable = provisional`, so every filing returns a `P-`
provisional ordinal. This is the designed degradation. The host realizes them
with `/jim:issue reconcile`. All ordinals are realized — 355 through 377 — with
none provisional at the time of writing.

**A reconcile can rewrite a file between your read and your commit.** The host
runs it out of band, and `/mnt/src/<project>` is the live workspace, so a
freshly filed issue you just verified as `P-…` can be `num: <n>` by the time you
`git add` it. Harmless when it happens, but the commit then carries someone
else's realization and says nothing about it. If a `num:` looks wrong against
what you saw, check the reflog before concluding history was rewritten — it
probably was not.

**Git push is restricted to the host.**

**A filtered subset is much cheaper than the suite.** `bash tests/issues.sh
identity` runs 107 cases in about twenty seconds, against roughly four minutes
for the file and fifteen for everything. Filter while iterating — but a filter
named after one surface silently excludes every case named after another, so
confirm the case you care about was selected before reading its silence as a
result.

**The full test suite takes 10–15 minutes** and exceeds a foreground timeout.
Run it backgrounded and poll for `^Ran `. Never run two concurrently, and count
subagent fan-out as concurrency — a fan-out running alongside the suite
collapses throughput. Redirect the whole output to a file rather than piping it
through `tail`: the aggregate prints one `Ran N tests` line at the very end, and
a `tail -40` keeps that line while discarding the `FAIL` that explains it.

**Do not end a suite-running command with `grep -c`.** `grep -c` exits 1 when
the count is zero, so `… ; grep -c '^FAIL' log` reports a perfectly green run as
a failed command. It is the mirror of the `tail` trap above: one hides a real
failure, this one invents a fake one. Read the aggregate line, not the chain's
exit status.

**A green per-file run does not mean the suite is green.** Corpus rules over
`tests/*.sh` live in `scripthygiene.sh`, so a new case can pass in its own file
and fail the suite — an unpinned `sort -u` did exactly that here.

**No real contributor addresses in specs, plans, research, security docs or
mockups.** Use `alice@company.com` / `you@example.com`. Issue *files*
legitimately carry `filed-by`.

**`VISION.md`'s "not a team-coordination primitive" line** is a known live
divergence the developer is handling separately. It is recorded in this spec's
research and the previous one's. Do not re-raise it as new.

---

## 6. If you are picking up what is left

The seventeen are done and `plan.md` is `complete`. What remains is the seven
this remediation *filed*, plus `#53`.

Read `remediation.md` first — the analysis, and § *Progress*, which records what
each fix actually did rather than what its issue asked for.

**Take `#377` before the other contract-graph issues.** `#372`, `#373`, `#374`,
`#376` and `#377` all come out of one root: the two halves of every group face
are named in disjoint vocabularies, so no `Requires` token resolves to any
`Provides` entry and three of the reconcile pass's six finding classes are
decided by reading prose. Fixing an instance under the current naming adds an
entry that only judgment can match, which is the state the instance was filed
about. `#372`, `#374` and `#375` are closable from this group; `#373`, `#376`
and `#377` need `platform`'s and `sdlc`'s faces.

Four methods from this cycle are worth reusing before they are forgotten.

**Mutation testing**, which audited the test-quality pair — the established
technique, applied by hand because no generated implementation exists for shell.
One behaviour removed per mutant, the subset run against each, the cases that go
red recorded; twenty-three mutants at about twenty seconds each found three
defects nobody had reported. `docs/notes/process-improvements.md` § *Audit the
surface, not the case* has the method, the field's vocabulary, and the two ways
it silently reports a false negative. The harness itself was scratch and is
gone; it is a dozen lines and worth rebuilding rather than hunting for. It is
also worth applying to a *new* guard and not only to an audit: every case added
in the last two batches was confirmed red against the code without its guard,
which is a thirty-second check that says whether the case tests the guard or
merely the outcome.

**A full group-blueprint regeneration**, which is affordable if the evidence
gathering fans out: twenty read-only Sonnet agents, one per spec, one per script
cluster, plus the skill surface, `ARCHITECTURE.md` and the test files, each
returning a fixed structured report rather than prose. Judgment — what the face
should say — stays with the caller; the agents only supply grounded facts. That
is what turned a one-entry edit into a regeneration that caught a stale Requires
claim, missing config keys and three undeclared invariants. Fan-out is a
per-session grant, so ask before assuming it. Do not run it alongside the suite.

**Deriving a doc check from code rather than restating the roster in the test.**
Both sweeps added for `#363` read their expectations out of the scripts —
`jimconf.sh keys`, and each migration script's own usage text — so a new key or
subcommand fails the check without anyone maintaining a list. The counter-example
is in the same file: the allocator's sweep carries its verbs in an array, and a
verb that shipped without reaching the documentation went unnoticed by it. When
the population cannot be derived, that is a finding about the script, not a
reason to hand-write the list.

**Verifying a mechanical transform structurally rather than by reading it.** The
`ARCHITECTURE.md` rewrap was checked two ways before it was installed: both
versions collapse to identical text under whitespace normalization, and every
block-structure count matches across them — fences, headings, bullets, quotes,
table rows, blank lines. The second check is the one that earned its keep. A
wrapped line beginning with ``` flipped fence parity and silently reclassified
several hundred lines as code, which a 2,700-line diff will not show you and the
first check cannot see. Any transform over a structured document deserves a
count of its structures on both sides.

Whatever you take, the closing move is the same each time: a `## Resolution`
note on the issue naming the commits and the case that pins the fix, and
`transition.sh close <id> --as done` rather than an edit to `status:`.
