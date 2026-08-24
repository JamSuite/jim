# Remediation — recorded identity schemes

Written after the post-build review returned `major-drift`. This records where
the increment actually stands, what the open issues have in common, and the
order I would fix them in. It is analysis, not a plan: nothing here has been
approved, and the sequencing is a recommendation.

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

## What the open issues have in common

Seventeen issues were filed on 2026-08-23. Two are critical, and both were
introduced by this increment.

### The two that block

**`#365` — values carrying `<` or `>` bypass the charset gate.** *(critical)*

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

**`#360` — path composed from an unvalidated slug.** *(critical)*

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
  a check into a silent pass
- `#358` — a mode flag that is only set when its operand is non-empty turned an
  exclusivity check into a no-op
- `#356` — one function's resolution root diverged from another's, so a
  disclosure can describe a mapping other than the one applied

Each is fail-**open** in a place the surrounding code fails closed. That is the
common cause worth naming, because fixing the four individually without naming
it invites the fifth.

### The rest, grouped

**Documentation the increment left behind** — `#364` (README and the feature doc
omit the feature), `#369` (help text tells users to close an issue by hand),
`#370` (a spec mockup diverging from the emitted report), `#368` (the skill
instructs two scripts its grant does not permit), `#355` (ARCHITECTURE.md lines
too long for its own consumers to read).

**Test quality** — `#362` (six cases that pass against a wrong implementation),
`#357` (the remap apply path, fault injection, and placement routing all
untested).

**Structural / declaration** — `#367` (the `issue` face never declares the
validator-lockstep contract `platform` requires), `#363` (nothing mechanically
checks that a config key or subcommand reaches its reference).

**Small correctness** — `#366`, `#371`, `#359`.

## Suggested remediation

### Order

**First, `#365`.** It is the only issue that makes a shipped document false, and
it is small. The gate needs to judge the value the caller supplied, not only
the value the mapping handed back — checking the pre-image against the accepted
set before it is composed into the lookup argument preserves both properties at
once: the mapping still runs first, and an out-of-set value is still refused.
Add a case with a bracket-bearing value through `resolve`, `normalize` and
`map`; none exists today.

**Then `#360`**, in the same pass. It is a one-line gate, and the sibling
`apply_schema_plan` has the same shape — fix both or the next reader copies the
wrong one.

Those two clear the blueprint violations and let the plan be marked complete
honestly.

**Then `#358` and `#361`**, which are the same fail-open pattern in the argument
parser and the mismatch surface. Worth fixing together so the shared cause is
visible in one diff.

**Then the documentation set**, of which `#368` is the one users actually hit —
the skill instructs `transition.sh` and `migrate.sh` and grants neither. `#364`
belongs with it: the identity documentation was deferred so it would land with
that grant fix rather than scatter.

**`#362` and `#357` are worth doing before the next increment builds on this
code**, not after. Six non-discriminating tests is a coverage figure that reads
better than it is.

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
