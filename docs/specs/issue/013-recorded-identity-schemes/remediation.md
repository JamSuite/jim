# Remediation — recorded identity schemes

Written after the post-build review returned `major-drift`. This records where
the increment actually stands, what the open issues have in common, and the
order I would fix them in. It is analysis, not a plan: nothing here has been
approved, and the sequencing is a recommendation.

> **Partly executed as of 2026-08-24.** Ten of the seventeen are closed — the
> two that blocked, the fail-open pair, the documentation set bar one, and the
> test-quality pair. § *Progress* at the end records what landed, where this
> analysis under-scoped the work — five more times after the first batch — and
> what remains. The
> diagnostic sections below are left as they were written: they describe the
> defects as found, and the issues' own resolution notes cite them.

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
| `plan.md` | approved — 21/21 tasks complete |
| `security.md` | `Needs Plan Review` — 16 findings, all applied |
| `review.md` | **`major-drift`** — 14 findings, `undelegated=0` |
| plan `status:` | **still `approved`** — deliberately not marked complete |
| collection | converted; 5 integrity warnings, all pre-existing wikilink noise |

The plan is not marked complete because a build whose own review records a
`major-drift` verdict and an open security regression should not carry a status
that says otherwise.

*The security regression is now fixed and both blueprint violations are cleared
(§ Progress). `plan.md` still reads `approved`: the reason recorded above no
longer holds, and the gate is the developer's to close.*

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

## Progress — 2026-08-24

Ten issues closed across thirty commits (`2da3693`..`b516c0d`). The suite is
green at **1,568** across 16 files; twenty-one cases were added or strengthened,
each confirmed to fail against an implementation missing the behaviour it names.

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

Both were audited by mutation before being fixed: twenty-three mutants over
`identity.sh`, `migrate.sh identity` and the configured default, the identity
subset run against each, the cases that went red recorded. A case its own mutant
does not kill is the finding, and the whole census costs about twenty seconds per
mutant. Every one of the twenty-one cases added or strengthened was then checked
the same way — the mutant it exists to catch, applied, and the case confirmed to
go red.

The method is written up in `docs/notes/process-improvements.md` § *Audit the
surface, not the case* (`1e794a5`), together with the two silent false negatives
it produces: a mutant that did not apply, and a case the filter never selected.

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

This is § *The pattern underneath them* seen from the other side: **an analysis
naming where a rule is broken is not an enumeration of where the rule applies.**
Every one of them was found by asking what the rule covers, never by re-reading
the issue — and the documentation set repeated the pattern after that lesson had
been named and written down, which is worth knowing about how much a written
rule protects you. Two rules were added to `docs/notes/process-improvements.md`
from the first batch (`42c11be`, `b1a13fb`) — one on partial enumerations, one
correcting what that file said to do with a case that pins a guard's boundary
rather than the guard.


### What remains

Seven of the seventeen:

| group | issues |
| :--- | :--- |
| Documentation | `#355` |
| Structural | `#367`, `#363` |
| Small correctness | `#356`, `#359`, `#366`, `#371` |

None of them is critical. `#53` is open and critical, and predates this
increment.

`#363` is still worth last, and is now much better evidenced than when it was
filed. Five of the six fixes closed since carry sites a mechanical sweep would
have caught: a subcommand missing from the Migrations table, config keys missing
from two config tables, a grant that did not cover its own body, a script header
enumerating eight of twelve verbs, and a field the conversion stopped writing
under the name its own usage still gives.

`#367` is the other structural one and is unchanged. `#356`, `#359`, `#366` and
`#371` remain small and real; the note above about not bundling them into
critical work no longer applies, since there is no critical work left in this
batch to obscure.
