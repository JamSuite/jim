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

The feature is built, the collection is converted, and the increment is **not
finished**.

| artifact | state |
| :--- | :--- |
| `spec.md` | `approved` — 33 acceptance criteria |
| `research.md` | `Active` |
| `plan.md` | `approved`, 21/21 tasks `[x]` |
| `security.md` | `Needs Plan Review` — 16 findings, all applied |
| `review.md` | **`major-drift`** — 14 findings |
| `remediation.md` | the analysis and the suggested fix order |

`plan.md` is deliberately **not** `status: complete`. Two critical issues from
the review are open and unfixed; marking it complete would make the plan's
status contradict its own review. That gate is the developer's to close.

Two frontmatter values look wrong and are not:

- **`security.md` stays `Needs Plan Review`.** That field records what a review
  *found*, not whether it was acted on. The previous spec's did the same
  through its build. Do not "fix" it.
- **`research.md` is `Active`** because its status gates whether planning
  proceeds. Different field, different semantics.

### The two that block

- **`#365` — values carrying `<` or `>` bypass the recorded-identity charset
  gate.** A regression this build introduced. Read `remediation.md` § *The two
  that block* for the mechanism; it is reproducible in one command.
- **`#360` — the identity rewrite composes a path from an unvalidated slug.**

Both are `in-change` violations of `critical` blueprint invariants, and both
were resolved **`fix`** at the blueprint fork — meaning the blueprint still
declares the properties the code must return to. **Do not fold either
invariant to match the current code.** That was decided explicitly.

`#53` and `#368` are also open and critical but predate this increment.

---

## 2. Building deep context

**This document is not enough grounding to change this code.** Read in this
order; the two blueprints are not optional.

### First — `docs/specs/issue/000-blueprint/spec.md` (the group's blueprint)

This is the `issue` group's current-state specification: what it is
responsible for, the surface it exposes, and the **ten invariants its code must
uphold**, each with a criticality and a verification method. It is the document
that decides whether a change to this group is correct, and it is what
`/jim:verify` judges the code against.

Two of those invariants are currently violated by this increment
(`identity-validated-before-record`, `id-gate-before-path`). You cannot
evaluate a fix for `#365` or `#360` without having read what they actually say
— the invariant text is the specification of the fix, and both are more
demanding than the issue titles suggest.

Note especially that the `identity.sh` **Provides** entry was updated by this
increment and now declares four verbs and the form/mapping behaviour, while
still asserting the refusal guarantee the code currently breaks. That tension
is deliberate and is the point of resolving `fix`.

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

**`ARCHITECTURE.md` has enormous lines.** The longest is ~23,000 characters; a
four-line read costs ~16,000 tokens and a whole-file read is refused. Use
`Read` with a small `limit`, or `grep -o` with bounded context — but note
`grep -o` with wide context on this file has been OOM-killed; prefer `awk` or
`sed -n` by line number. This is tracked as `#355`.

**Never hand-edit `ARCHITECTURE.md` or any blueprint.** Use `/jim:arch` and
`/jim:blueprint`. A surgical edit bypasses the skill's grading, its
present-tense and provenance scans, and its `Last updated` stamp.

**The ID coordination registry is unreachable from the sandbox VM.**
`id_coordination_unreachable = provisional`, so every filing returns a `P-`
provisional ordinal. This is the designed degradation. The host realizes them
with `/jim:issue reconcile`. All ordinals in this increment are realized —
355 through 371 — with none provisional at the time of writing.

**Git push is restricted to the host.**

**The full test suite takes ~9 minutes** and exceeds a foreground timeout. Run
it backgrounded and poll for `^Ran `. Never run two concurrently, and count
subagent fan-out as concurrency — a fan-out running alongside the suite
collapses throughput.

**No real contributor addresses in specs, plans, research, security docs or
mockups.** Use `alice@company.com` / `you@example.com`. Issue *files*
legitimately carry `filed-by`.

**`VISION.md`'s "not a team-coordination primitive" line** is a known live
divergence the developer is handling separately. It is recorded in this spec's
research and the previous one's. Do not re-raise it as new.

---

## 6. If you are here to fix `#365`

Read `remediation.md` first — it has the suggested approach and the reasoning
for the order. Then the `identity-validated-before-record` invariant in the
group blueprint, because that text is the specification of what "fixed" means.

The shape of the fix is not "sanitize harder". The gate must judge the value
the caller supplied, not only the value the mapping handed back — the mapping
legitimately runs first, and an out-of-set value must still be refused. No test
currently exercises a bracket-bearing value through any verb, so the regression
case is new work.

When it lands, three things should follow in the same pass: the two documents
that currently assert the broken property (`identity.sh`'s SECURITY MODEL
header, and `ARCHITECTURE.md` § Recorded identity via `/jim:arch`), and a
`## Resolution` note on the issue naming the commit and the case that pins it.
