# Remediation — recorded identity schemes

Written after the post-build review returned `major-drift`. This records where
the increment actually stands, what the open issues have in common, and the
order I would fix them in. It is analysis, not a plan: nothing here has been
approved, and the sequencing is a recommendation.

> **Executed as of 2026-08-25.** All seventeen are closed — the two that
> blocked, the fail-open pair, the documentation set, the test-quality pair, the
> contract declaration, the small-correctness batch, the mechanical sweep, and
> the line-length convention. § *Progress* at the end records what landed, where
> this analysis under-scoped the work — ten more times after the first batch —
> and what the remediation filed rather than fixed. Every issue closed reached
> further than it named, in one case by finding that half of it was already
> right: seventeen for seventeen.
> The diagnostic sections below are left as they were written:
> they describe the defects as found, and the issues' own resolution notes cite
> them.

## Where we stand

The feature works. A project selects a form, one contributor's several
addresses collapse to one identity, the collection was converted, and 371
issues now read as two identities where four addresses used to sit. The suite
is green at 1,443 tests across 16 files, all 21 plan tasks are `[x]`, and 31 of
33 acceptance criteria are fully satisfied.

The build also shipped a security regression, and the review found it by
reading the code rather than by running the tests.

| artifact | state |
| :--- | :--- |
| `spec.md` | approved — 33 ACs |
| `plan.md` | `complete` — 21/21 tasks, 17/17 review issues |
| `security.md` | `Needs Plan Review` — 16 findings, all applied |
| `review.md` | **`major-drift`** — 14 findings, `undelegated=0` |
| plan `status:` | `complete` — closed 2026-08-25, after all seventeen |
| collection | converted; 5 integrity warnings, all pre-existing wikilink noise |

The plan was held at `approved` while it was true that a build whose own review
recorded a `major-drift` verdict and an open security regression should not
carry a status saying otherwise.

*It reads `complete` as of 2026-08-25. Every issue the review raised is closed,
the security regression is fixed, and both blueprint violations hold again
(§ Progress).*

## What the open issues have in common

Seventeen issues were filed on 2026-08-23. Two are critical, and both were
introduced by this increment.

### The two that block

**`#365` — values carrying `<` or `>` bypass the charset gate.** *(critical —
**closed** 2026-08-24, `2da3693`)*

The pipeline puts alias resolution ahead of the charset gate, correctly: a
mapping is keyed on addresses, so extracting first would leave it nothing to
match. But the value is handed to the mapping lookup wrapped in angle brackets,
so a value that already contains one produces malformed bracket structure, and
the extraction that reads git's answer takes the text after the **last** `<`.

```
junk<attacker@evil.example  ->  attacker@evil.example
a<b                         ->  b
a>b                         ->  a
```

Each result is charset-clean, so it clears the gate on its own merits with no
memory that the original was disallowed. This reaches the filer at filing, the
holder at a transition, the recovered filer, and the re-normalization — every
write path but the explicit remap.

Two documents currently assert the property this breaks: `identity.sh`'s own
SECURITY MODEL header, and `ARCHITECTURE.md` § Security Considerations →
Recorded identity, which was refreshed during this build's completion gate. The
blueprint's `identity-validated-before-record` invariant is `violated`, and the
fork resolved `fix` — so the blueprint still declares the property the code
must return to.

**`#360` — path composed from an unvalidated slug.** *(critical — **closed**
2026-08-24, `2536459` + `a54cb98`; the reach was three sites, not the two named
below)*

`apply_identity_plan` builds `"$dir/$slug.md"` with no validator call. No
traversal is reachable — the slug is a byte-identical reconstruction of a
globbed directory entry — but the project has settled this question three times
in the other direction: `new.sh` validates even allocator-derived ids and says
why, `index.sh` validates this identical category, and `migrate.sh` was fixed
once before for exactly this shape.

### The pattern underneath them

The two critical issues, and several of the others, share one shape: **a guard
was moved or added, and the thing it guarded stopped being guarded without
anything saying so.**

- `#365` — a step inserted ahead of the gate turned the gate into a sanitizer
- `#361` — a fallback (`ident_form="$ident_value"` on a failed normalize) turned
  a check into a silent pass *(closed, `82c5a69`)*
- `#358` — a mode flag that is only set when its operand is non-empty turned an
  exclusivity check into a no-op *(closed, `d576a9e`)*
- `#356` — one function's resolution root diverged from another's, so a
  disclosure can describe a mapping other than the one applied

Each is fail-**open** in a place the surrounding code fails closed. That is the
common cause worth naming, because fixing the four individually without naming
it invites the fifth.

### The rest, grouped

**Documentation the increment left behind** — `#364` (README and the feature doc
omit the feature), `#369` (help text tells users to close an issue by hand),
`#370` (a spec mockup diverging from the emitted report), `#368` (the skill
instructs two scripts its grant does not permit) — *all four closed
2026-08-24* — and `#355` (ARCHITECTURE.md lines too long for its own consumers
to read), which is not a document fix and is still open.

**Test quality** — `#362` (six cases that pass against a wrong implementation),
`#357` (the remap apply path, fault injection, and placement routing all
untested).

**Structural / declaration** — `#367` (the `issue` face never declares the
validator-lockstep contract `platform` requires), `#363` (nothing mechanically
checks that a config key or subcommand reaches its reference).

**Small correctness** — `#366`, `#371`, `#359`.

## Suggested remediation

### Order

*(Every step below but the last two is done. They are left as written — the
reasoning is what the resolution notes answer, and § Progress records where it
fell short.)*

**First, `#365`.** ✓ It is the only issue that makes a shipped document false, and
it is small. The gate needs to judge the value the caller supplied, not only
the value the mapping handed back — checking the pre-image against the accepted
set before it is composed into the lookup argument preserves both properties at
once: the mapping still runs first, and an out-of-set value is still refused.
Add a case with a bracket-bearing value through `resolve`, `normalize` and
`map`; none exists today.

**Then `#360`**, in the same pass. ✓ It is a one-line gate, and the sibling
`apply_schema_plan` has the same shape — fix both or the next reader copies the
wrong one.

Those two clear the blueprint violations and let the plan be marked complete
honestly.

**Then `#358` and `#361`**, ✓ which are the same fail-open pattern in the argument
parser and the mismatch surface. Worth fixing together so the shared cause is
visible in one diff.

**Then the documentation set**, ✓ of which `#368` is the one users actually hit —
the skill instructs `transition.sh` and `migrate.sh` and grants neither. `#364`
belongs with it: the identity documentation was deferred so it would land with
that grant fix rather than scatter. *(`#355` was held back — see § Progress.)*

**`#362` and `#357` are worth doing before the next increment builds on this
code**, not after. ✓ Six non-discriminating tests is a coverage figure that reads
better than it is. *(It was nine — see § Progress.)*

**`#363` last, and deliberately.** It is the only issue that prevents recurrence
rather than fixing an instance. The same missing sweep let `migrate.sh schema`
ship undocumented in one increment and `migrate.sh identity` in the next —
twice, silently. A mechanical check is worth more than the individual doc fixes
it would have caught.

### What not to do

**Do not fold any invariant to match the current code.** Both violations
resolved `fix` at the blueprint fork, so the blueprint declares the properties
the code must return to. Softening either would encode a regression as intent.

**Do not treat `#359`, `#366`, `#370`, `#371` as urgent.** They are real and
small, and bundling them into the critical work would obscure it.

### A process note worth keeping

The two most valuable defects of this whole cycle were found the same way:

- the collision check refusing mailmap-unified addresses — found by running the
  verb against the real collection, after 30 tests passed over it
- the bracket bypass — found by adversarial reading, after 78 new tests passed
  over it

In both cases every fixture avoided the interesting shape. The tests were not
too few; they were drawn from the same imagination as the code. Exercising a
new verb against real data before believing the suite is what caught the first,
and would likely have caught the second.

Three findings reported during the review were also **refuted** by running one
command each — an attribution hijack, an arithmetic-subscript leak, and a
false-negative in the collision fallback. All three were confidently argued.
Verifying a claim before recording it is cheap; recording a wrong one is not.

## Progress — 2026-08-25

Seventeen issues closed across sixty-three commits (`2da3693`..`2c14c5a`). The
suite is green at **1,575** across 16 files; twenty-eight cases were added or
strengthened, each confirmed to fail against an implementation missing the
behaviour it names.

### The two that blocked, and the fail-open pair

| issue | | commits |
| :--- | :--- | :--- |
| `#365` bracket bypass | closed | `2da3693` (fix + `identity.sh` header), `b00ad3d` (`ARCHITECTURE.md` via `/jim:arch`) |
| `#360` unvalidated slug | closed | `2536459`, `a54cb98` |
| `#358` argument parser | closed | `d576a9e` |
| `#361` mismatch surface | closed | `82c5a69` |

Both blueprint violations are cleared. `/jim:verify issue` returned
`identity-validated-before-record` and `id-gate-before-path` as `holds` under
independent judges reading the code without being told what changed. The group
ledger carries both records — `violated=1`, then `violated=0` — rather than one
amended line, so the trajectory survives.

One fix here belongs to no issue: `d74039e`, a fourth `id-gate-before-path` site
in `transition.sh`, found by the verify judge and fixed in the same pass.


### The documentation set

| issue | | commits |
| :--- | :--- | :--- |
| `#368` skill tool grant | closed | `5978e1d`, `136a2a5`, `006c430`, `74dd602` (`ARCHITECTURE.md` via `/jim:arch`) |
| `#364` user-facing docs | closed | `136a2a5`, `dafb06d`, `b84a523` |
| `#369` close-by-hand help | closed | `a9235e6`, `fc943fd` |
| `#370` integrity mockup | closed | `627c761` |

`#355` was deliberately left out. It is not a document fix: it wants a decision
about whether `/jim:arch` wraps its generated prose on every refresh, and a
rewrap of a 204 KB file whose oversize unit *is* the line. Doing it inside a
documentation pass would have buried that decision in a diff about something
else.

### Test quality

| issue | | commits |
| :--- | :--- | :--- |
| `#362` non-discriminating cases | closed | `2275999` |
| `#357` coverage gaps | closed | `5e79803` |

Both were audited by **mutation testing** — the established technique,
applied by hand because no generated implementation exists for shell — before
being fixed: twenty-three mutants over
`identity.sh`, `migrate.sh identity` and the configured default, the identity
subset run against each, the cases that went red recorded. A case its own mutant
does not kill is the finding, and the whole census costs about twenty seconds per
mutant. Every one of the twenty-one cases added or strengthened was then checked
the same way — the mutant it exists to catch, applied, and the case confirmed to
go red.

The method is written up in `docs/notes/process-improvements.md` § *Audit the
surface, not the case* (`1e794a5`), together with the two silent false negatives
it produces: a mutant that did not apply, and a case the filter never selected.

### The contract declaration

| issue | | commits |
| :--- | :--- | :--- |
| `#367` validator-lockstep undeclared | closed | `a353589` (the face), `649485c` (the derived graph) |

Done as a **full regeneration** of the group's blueprint rather than the
one-entry edit the issue describes, and the difference is the whole story: the
targeted edit would have satisfied the issue's literal text while leaving four
other things wrong, including the new entry itself.

The regeneration ran as a twenty-agent fan-out over the group's thirteen specs,
its nine scripts, the skill surface, `ARCHITECTURE.md` and both test files — the
evidence gathering is what a full generate is for, and it is not affordable by
hand. `ARCHITECTURE.md` needed bounded `awk` reads throughout; the whole-file
read its own skill instructs is refused.

Beyond the declaration, the regenerated face corrected a stale Requires claim
(`platform.jimfile-cli` credited with `next-id`/`next-num`, which the group no
longer calls — minting moved to the allocator), added the recorded-identity
config keys missing since that increment, and gained three invariants the code
already upheld with nothing declaring them.

`ARCHITECTURE.md`'s test-corpus roster was corrected in the same pass
(`2bccec6`): it named seven of sixteen files and called them all per-script
tests where six are corpus rules. Its entry for a directory's own tests now
names the directory rather than its members, which retires the rot rather than
refreshing it.

### The small-correctness batch

| issue | | commits |
| :--- | :--- | :--- |
| `#359` unmatchable `identity_domain` | closed | `d0bc02d` (guard + README), `d4e09a9` |
| `#356` misrooted alias disclosure | closed | `6eefd6e`, `72ac702` |
| `#371` quiet degradation pair | closed | `13b35b5`, `ba86f8c` |
| `#366` unpredictable apply | closed | `73acbdb` (guard + `SKILL.md`), `73870a3` |

Four issues that had been carried since the review as "small and real". Each was
censused against its own mechanism before being fixed, and three of the four
reached further than the issue named — the fourth reached *less*, which is its
own kind of finding.

`#356` is the one where the census confirmed the instance was the whole rule:
every version-control call in the group's identity path splits the same way, a
fact about the collection rooted at the collection directory and a fact about
identity resolution rooted at the process. Exactly one site sat on the wrong
side of that line.

### The mechanical sweep

| issue | | commits |
| :--- | :--- | :--- |
| `#363` hand-enumerated rosters | closed | `16f6815` (both sweeps), `ec97331` (allocator header), `e27b4ea` |

Held to last on purpose, and worth it: by the time it ran, the drift it was
filed about had already been repaired by the documentation pass, so both sweeps
went in as regression guards over a corpus that was already correct. That is the
right shape for a check whose purpose is to stop a class recurring.

Both sweeps derive their expectations from code rather than restating them.
The migration half reads each script's own usage text — not its dispatch table,
which also carries an internal primitive the script deliberately does not
advertise — and checks both directions: a subcommand with no row, and a row
outliving its subcommand. The config half walks `jimconf.sh keys` and accepts
the three shapes the tables actually use, including the family row that
documents five keys at once.

Each direction was mutation-checked rather than assumed: dropping a table row,
adding a row for a subcommand that does not exist, and dropping a key from
README each turn the relevant case red.

### The line-length convention

| issue | | commits |
| :--- | :--- | :--- |
| `#355` unreadable line lengths | closed | `be1ac8a` (the rule), `fb9844c` (the rewrap), `2c14c5a` |

Held back from the documentation pass on purpose, because it was a decision
about generated output rather than a document fix, and it stayed last for the
same reason: the other sixteen were work, and this one was a fork.

`/jim:arch` now hard-wraps every paragraph and list item it writes at 80
columns, and names what it must never wrap — table rows, fenced blocks, the
Mermaid diagram, headings, and a URL longer than the budget. The
differential-update step changed with it: it had instructed reading the existing
document *fully*, which is precisely what the document had outgrown, so the
skill could not follow its own process on the file it maintains. It reads by
section now, which is worth doing only because wrapping makes a bounded read
cost what was asked for.

The rewrap was applied as a mechanical reflow and **verified as
whitespace-only** rather than asserted: both versions collapse to identical text
under whitespace normalization, and every block-structure count matches across
them. A forty-line window at the worst paragraph fell from 94 KB to 3 KB.

One hazard is worth carrying forward. Breaking a line before a word that opens a
markdown block turns prose into a heading, a list item, or — in a document that
discusses fenced code — a fence. The first attempt did exactly that: a paragraph
naming ``` produced a line beginning with it, flipping fence parity for every
line after and silently reclassifying hundreds. It was caught by the structural
check rather than by reading the diff, which is the argument for running that
check at all.

### Where this analysis under-scoped the work

**`#360` reached three sites, not two.** Its Scope named `apply_schema_plan` as
the sibling and the order above repeated that count. A verify judge — asked
whether the *invariant* held rather than whether the *issue* was fixed —
enumerated every composition site and counted guards: **0 / 1 / 1**. The
unguarded one was `apply_plan`'s fallback arm in the prefix migration, which
neither the issue nor the first fix pass had looked at. A second judge run then
found a fourth site in `transition.sh`, where `resolve_slug` answers with a
directory-derived name on two of its three branches.

**`#358`'s deferred question was the serious half.** Its Scope asked whether to
harden the swallow idiom generally and left the answer to the fixer. The answer
is yes, and the unenumerated part held the worst instance: a value-less
`--expect` consumed the flag authorizing a destructive whole-collection write
and left the drift guard unarmed, reachable in all three migration subcommands.
Confirmed by running it — the collection was rewritten with no drift check.

**`#361` could not be fixed as its Direction worded it.** Counting an
unnormalizable value as an ordinary mismatch points the operator at
`--renormalize`, which provably skips exactly those records (`migrate.sh:643`).
The warning would never clear — the permanent nag the surface is designed not to
be. It became a third class with its own remedy instead.

**`#364` could not be fixed as scoped, for a structural reason.** It asks for
four frontmatter fields to reach the feature doc's example block. No
user-facing document named a verb that moves any of them, so filling the block
in would have shown `claimed-by` and `outcome` with nothing saying what writes
them. The lifecycle went in with the fields — README command table,
`WORKFLOW.md` subcommand list, a new feature-doc section — and two further
enumerations in those same documents turned out stale from the same increment:
the `list` filter set, missing `active`, and the typed relation buckets,
missing `part-of`.

**`#369` named two sites and its claim was true of four.** `WORKFLOW.md`
carried the identical close-by-hand instruction and is the surface a user is
likelier to reach than a script's `help`; `migrate.sh`'s header and usage call
the `type` field `kind`. Both found by sweeping what the issue asserted, not by
re-reading the issue. The help had also fallen behind the surface it exists to
enumerate — five lifecycle verbs and `reconcile` absent from a listing of
subcommands.

**`#368` moved the convention rather than only the grant.** Its Direction asked
for verb scoping, and `ARCHITECTURE.md` § Permission Conventions said a
multi-verb consumer keeps the script-level clause unless an executor is among
the withheld verbs. `migrate.sh` carries no executor; what it carries is a
subcommand that renames every file in the collection. Taking the tighter grant
therefore meant the document stopped describing the code, so the rule was
generalized to cover a destructive whole-collection write alongside an
executor.

**`#362` under-reported by half, and `#357` named one site of two.** The six
non-discriminating cases were six of nine; the three nobody reported are the same
shape as the six, an assertion matching a substring two branches share. `#357`
named `apply_identity_plan` for both its structural gaps, and a count across the
three applies put fault coverage at 2/0/0 and placement routing at 1/0/0 — the
sibling conversion had the same two absences.

Neither was found by reading the issues. The first came out of mutating the
surface and recording which cases went red; the second out of counting the guard
per sibling site, which is the census this section already names. **A reported
count is a lower bound.**

**One of `#357`'s asks was declined rather than met.** It wanted a
fault-injection seam matching the prefix migration's. Both branches turned out
reachable from outside — an unwritable directory fails the `mktemp` for real — so
the cases drive the real failure and the seam was not added. The sibling carries
seams because its failure points sit inside git plumbing, which nothing external
can reach; the asymmetry is justified rather than a gap.

**`#367` named one coupling and the rule reached three.** A first census said
"exactly one gap" — and was wrong in an instructive way: it enumerated the
*declared* edges, so it could only ever find gaps in edges someone had already
declared. Censusing the sync markers in the code instead found three
byte-identity couplings crossing the `issue`/`platform` boundary — `is_valid_id`
(declared by one face), `valid-branch` and `ts-shape` (declared by neither) —
and a fourth marker that is deliberately asymmetric and says so, which recording
as lockstep would have made false. Closing the named leak opened an undeclared
one, correctly: the coupling became visible.

The same issue then supplied its own sharpest instance. Written in the obvious
shape the new face entry was invisible to `jimverify.sh faces`, which reads only
entries leading with a backticked token — a declaration a person could read and
no tool could see, which is precisely the failure `#367` exists to fix. Two
long-standing entries, the § 7a candidate-batch contract among them, are still
in that shape.

This is § *The pattern underneath them* seen from the other side: **an analysis
naming where a rule is broken is not an enumeration of where the rule applies.**
Every one of them was found by asking what the rule covers, never by re-reading

**`#359` named a typo; the rule is label validity.** The issue reported a
leading dot in `identity_domain` clearing every gate and then matching no
address. A leading dot is one of several shapes that do that — a trailing dot,
consecutive dots, a leading or trailing hyphen, a hyphen on either side of a dot
— and each is the same unusable configuration reached by a different slip. The
guard that landed is label-boundary validity, and the case pins nine values. The
opposite edge needed pinning too: a single-label domain like `localhost` is
matchable and stays accepted, so the guard refuses what can never match rather
than everything without a dot.

**`#371` was half a defect, and the other half was already right.** Its two
paths looked like one inconsistency: a timestamp failure that degraded quietly,
and a publish failure that returned without unwinding the door while every other
exit aborted. The first was real and now refuses before writing. The second
turned out to be deliberate — `place.sh` frees a handle only after a successful
publish, so a refused commit keeps the edits for a retry, and adding the
"missing" abort would have destroyed the developer's work to make the code look
symmetrical. The issue itself asked for this to be *determined* rather than
inferred, which is the reason it did not get fixed into a bug. Both the guard
and the comment above it now say why the asymmetry is correct.

**`#366` reached the fixtures, not just the preview.** Adding the anchor check
turned four existing cases red — and each of them described a legacy issue as
`title`, `status` and `priority` alone, a record the conversion could never have
completed, standing in for the ordinary case. The fixtures were wrong before the
check existed and nothing could see it. They now share a `schema_legacy` helper
carrying the shape the real corpus has, and the unanchored form appears only in
the case that is about it. This is the *Fixtures inherit the author's blind
spot* note from this cycle, landing a second time.

**`#363` found two more of its own rule.** Its Direction named two sweeps and a
third candidate already covered. Censusing for hand-enumerated rosters instead
found a fourth: the allocator's operator verbs reach the documentation through a
list written into the test, so a *new* verb is invisible to the check meant to
catch exactly that. It is not derivable the way the others are — the script does
not distinguish its hand-run verbs from the ones other scripts call — so it is
filed as `#375` rather than bodged. And the evidence that it matters was sitting
right there: `lift` had shipped without reaching `jimalloc.sh`'s own header
roster, which enumerated the commands and stopped at `catch-up`. Nothing caught
it, because nothing could.

**`#355` was a decision, and the decision was not the whole fix.** It reported
line lengths, and wrapping is what it asked for — but wrapping alone would have
left the skill's own instruction to read the document *fully* just as
unfollowable as before, since reflowing a file does not shrink it. The fix that
landed changes both: the rule for what `/jim:arch` writes, and the step that
says how it reads what is already there. And the remaining obstacle turned out
to be a different problem wearing the same symptom — one section is half the
document, which no formatting rule addresses, filed as `#378`.

This is § *The pattern underneath them* seen from the other side: **an analysis
naming where a rule is broken is not an enumeration of where the rule applies.**
Every one of them was found by asking what the rule covers, never by re-reading
the issue — and the documentation set repeated the pattern after that lesson had
been named and written down, which is worth knowing about how much a written
rule protects you. Two rules were added to `docs/notes/process-improvements.md`
from the first batch (`42c11be`, `b1a13fb`) — one on partial enumerations, one
correcting what that file said to do with a case that pins a guard's boundary
rather than the guard.

### What the remediation left behind

Nothing of the seventeen. `#53` is open and critical, and predates this
increment.

Seven issues were filed *by* this remediation rather than fixed by it. None is
part of the seventeen or this increment's debt:

| issue | what it is | closable here? |
| :--- | :--- | :--- |
| `#372` | the fourth `ts-shape` copy no test compares | yes |
| `#373` | platform's undeclared half of the branch-gate mirror | no — `platform`'s face |
| `#374` | the faces verb drops nine entries across four faces | yes |
| `#375` | the allocator's verb sweep is hand-listed, not derived | yes |
| `#376` | the prov-token grammar crosses into `sdlc`, undeclared | no — two faces |
| `#377` | no requires token resolves to any provides entry | no — all four faces |
| `#378` | one section is half the architecture document | yes |

`#377` is the root the other contract-graph issues are instances of: the two
halves of every face are named in disjoint vocabularies — the artifact on one
side, the capability on the other — so `leak`, `dead-surface` and `breaking` are
decided by reading prose rather than by a join. Fixing it is a naming pass
across four group blueprints plus a mechanical check, which is a larger piece of
work than anything in the seventeen and was deliberately not folded into them.

### The gate that closed

`plan.md` reads `status: complete` as of 2026-08-25. It had been held at
`approved` because two critical issues from the review were open and unfixed,
and marking it complete would have made the plan's status contradict its own
review. All seventeen are closed, both blueprint violations hold again under
judges reading the code cold, and the suite is green at 1,575.
