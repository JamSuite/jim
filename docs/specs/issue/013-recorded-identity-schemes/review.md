---
spec: "issue/013"
type: "feature"
base_sha: "21519321eaac90767d43076e95adce6130a46ca0"
head_sha: "937bf9d5833325c2173f95f5f216f86d35a1e869"
commits: "24"
commits_test: "4"
commits_feat: "15"
commits_fix: "1"
commits_refactor: "0"
files_changed: "9"
insertions: "2228"
deletions: "74"
spec_runs: "1"
spec_interruptions: "0"
spec_duration_seconds: "5288"
research_runs: "1"
research_interruptions: "0"
research_duration_seconds: "777"
plan_runs: "1"
plan_interruptions: "0"
plan_duration_seconds: "31964"
sec_runs: "2"
sec_interruptions: "0"
sec_duration_seconds: "32927"
build_runs: "1"
build_interruptions: "0"
build_duration_seconds: "7001"
review_runs: "2"
review_interruptions: "0"
review_duration_seconds: "1415"
artifacts_present: "spec,research,security,plan,ledger"
plan_deviations: "3"
security_regressions: "1"
invariant_violations: "2"
contract_violations: "0"
alignment: "major-drift"
date: "2026-08-23"
---

# Review: Recorded identity schemes

## Summary

The build did what it was asked: 21 of 21 tasks, 31 of 33 acceptance criteria
fully satisfied, no scope creep, every bash convention clean, and 1,443 tests
green across 16 files. It also introduced a **security regression that
falsifies the security model its own file header states**, and reintroduced a
path-composition shape this same file has already been fixed for once.

The regression is the reason for the verdict. Before this change,
`identity.sh validate` ran directly on the raw value, so any identity carrying
`<` or `>` — bytes outside the accepted set — was refused. The change inserts
alias resolution *ahead of* the charset gate, and the extraction that reads
git's answer takes the text after the **last** `<`. A malformed value is
therefore reduced to a shorter, charset-clean substring that clears the gate on
its own merits, with no memory that the original was disallowed:

```
junk<attacker@evil.example  →  attacker@evil.example   rc=0, recorded
a<b                         →  b                       rc=0, recorded
a>b                         →  a                       rc=0, recorded
```

Every write path except the explicit `--from/--to` remap reaches this: the
filer at filing, the holder at a transition, the schema conversion's recovered
filer, and `--renormalize`. It breaks the blueprint's `critical`
`identity-validated-before-record` invariant, and it makes false both
`identity.sh`'s own SECURITY MODEL header ("only that set is accepted, and
everything outside it is refused") and the `ARCHITECTURE.md` § Recorded
identity paragraph refreshed at build completion.

**Range note.** The ledger's recorded build range ends at `937bf9d`, but four
source-bearing commits landed after it — including `08db10b`, a fix to the
collision check found by running the verb against the real collection. This
review covers the effective range `2151932..HEAD` (2,343 insertions across 7
source files), not just the recorded one. A review scoped to the ledger's range
would have missed both the defect and its fix.

**Verdict trajectory.** `minor-drift` was recorded first, then amended to
`major-drift` when the living-intent sensor's evidence arrived and was verified
by hand. Both lines stand on the ledger; this artifact is authoritative.

## Alignment

### vs. Spec acceptance criteria

31 of 33 fully satisfied, verified per-criterion against the tree rather than
against the plan's coverage table. Two partials:

- **"Selecting the organization-local form without configuring a domain
  refuses every operation that would record an identity."** Satisfied for
  `resolve`/`normalize` — so filing, transitions, the schema conversion and
  `--renormalize` all refuse. **Not** enforced for `migrate.sh identity
  --from/--to`, which validates only the charset and writes under a
  configuration every other path refuses. Defensible as design (a remap does
  not *derive* through the form, so the domain is logically irrelevant to what
  it writes) but the AC's wording is unqualified, and the plan's coverage table
  maps this AC only to `identity.sh`'s own gating — it never asserted the remap
  path was in scope. Worth a decision rather than a silent settlement.
- **"Any preview that resolves identities through the alias mapping discloses
  that it did so, whether a mapping was found at all, and how many records it
  altered."** Satisfied for `--renormalize`. `migrate.sh schema`'s preview
  discloses nothing, though it resolves through the mapping twice — once via
  git's own `%aE`, once via `map_alias` inside `normalize`. The spec's text is
  unscoped; the plan and the spec's UI mockups both scope it to the rewrite
  previews. Spec text and plan scope are in tension.

### vs. Plan tasks

All 21 tasks executed in order, each with a Red phase confirmed by Bash output
before Green. No task was skipped or silently merged. Three deviations, all
recorded below rather than absorbed.

Task 16 deserves note: it was authorized during the *previous* spec's blueprint
fork and recorded on that ledger as `fixed=1`, but the code change never
landed. Its Red phase failed on both `apply_plan` and `apply_schema_plan`,
confirming the ledger had been asserting something untrue. The
`staleness-gated-reads` invariant now holds for the first time since it was
declared.

### vs. ARCHITECTURE.md

Conventions clean across every new function, independently audited: no
`source`/`eval` on untrusted data, bash + POSIX only, `set -uo pipefail`,
`BASH_SOURCE`-relative composition, `#!/usr/bin/env bash`, and — checked
specifically because this project bans it — **no spec IDs or artifact
references in any new script comment**.

One contradiction, and it is the regression above: the § Recorded identity
paragraph asserts the value "clears a positively enumerated character set" and
that unanticipated input "fails closed". For `<`/`>` it does not. That
paragraph was rewritten during this build's completion gate, so the document
and the code were made inconsistent in the same session.

## Investigation

### High-stakes regions investigated

Twelve regions triaged from the diff spine and dispatched to independent
investigators, plus eight blueprint judges. Every claim reported below that
concerned runtime behavior was re-verified by hand before being recorded —
three were refuted that way.

| region | evidence gathered |
| :--- | :--- |
| `identity.sh` command construction | `map_alias` passes the value wrapped and after `--`; length bound precedes every path to it; malformed/empty/absent git output all fall back to the value unchanged |
| `identity.sh` form logic | all relay/organization-local cases traced input-by-input; the `+` asymmetry confirmed running in opposite directions, not swapped |
| `identity.sh` refusals and gates | every refusal string is fixed; no rejected value reaches stderr |
| `mark_ambiguous` / `refuse_ambiguous` | post-fix comparison correct; `\|` delimiter safe because the charset excludes it; refusal names records and the shared value only |
| `apply_identity_plan` | awk `-v` backslash hazard closed by the charset excluding `\` and `"`, on both plan paths; no path traversal; every failure branch cleans its temp file; second apply performs zero writes |
| `index.sh` mismatch surface | distinct-value memoization correct and collection-wide; slugs pass the existing display sanitizer; identity values never enter the generated markdown |
| all 33 spec ACs | per-criterion sweep against the tree, including the claim that `new.sh`/`transition.sh` needed no change — verified at `new.sh:204` and `transition.sh:228` |
| index-status call sites | all 11 invocations across the repo enumerated; every one captures the status and propagates it to the process exit code |
| bash conventions | six rules checked across five scripts and two test files |
| test discrimination | every new case examined for whether a wrong implementation would still pass it |
| config family + remap surface | all three registration points present; `jimconf.toml.example` claims checked line-by-line against the code |
| the post-build fix | `map` verb checked as a faithful prefix of `normalize`; both new call sites traced |

### Coverage

Depth `thorough`. The fan-out **ran**: 12 investigators dispatched, 12
returned; 8 judges dispatched, 8 returned. `undelegated=0`. The configured
fan-out cap of 10 was lifted for this run with the developer's explicit
authorization, so no region was dropped for cap reasons and there is no
un-investigated remainder.

Three reported findings were **refuted** by hand-verification rather than
recorded:

1. An attribution-hijack via `<`/`>` in the mapping call — refuted. Git
   normalizes to the *first* parseable contact, so `real@x.com><injected@y.com`
   yields `real@x.com`, the legitimate address. (The *separate*
   embedded-`<` truncation is real and is Finding 1.)
2. An arithmetic-subscript leak in `index.sh` — refuted. `(( m[$v] ))` with an
   unbalanced `]` reads cleanly on bash 5.3.15 with no error and no leak.
3. A false-negative in `mark_ambiguous`'s map-failure fallback — refuted.
   `map_alias` returns 0 for "no repo" and "no match", so `map` fails only when
   the *mapped result* is unrecordable; the fallback's worst case is a spurious
   refusal, never a silent merge.

## Living intent

Sensor ran against `docs/specs/issue/000-blueprint/spec.md` after the verdict
was assigned, so its results did not inform the alignment judgment.

### Violations

- **`identity-validated-before-record` (critical) — `violated`, channel
  `in-change`.** A value carrying `<` or `>` is not refused as an out-of-set
  value; the alias step's extraction reduces it to a charset-clean substring
  that then clears the gate. Evidence: `skills/issue/scripts/identity.sh:172`.
- **`id-gate-before-path` (critical) — `violated`, channel `in-change`.**
  `apply_identity_plan` composes `"$dir/$slug.md"` with no validator call on
  the slug. No traversal is reachable — the slug is a byte-identical
  reconstruction of a glob-enumerated directory entry, dotfiles excluded — but
  the invariant's text is unconditional, `index.sh:404` validates this identical
  category of value, `new.sh:259-266` explicitly refuses "safe by provenance"
  reasoning, and this same file was fixed once before for this exact class.
  Evidence: `skills/issue/scripts/migrate.sh:852`. The sibling
  `apply_schema_plan` (`:503`) has the same shape and is pre-existing.

### Coverage

10 invariants; appetite `low` (judge everything); 8 change-selected and judged,
2 `skipped` with reason `scope` (`materialization-contained` and
`insights-capability-boundary` — `place.sh`'s materialization and the analyst
agent were untouched). 6 hold: `single-emitter`, `untrusted-body-never-shell`,
`atomic-index-write`, `staleness-gated-reads`, `placement-gate-before-git`,
`placeholder-by-position`. Cap 10, none capped, `undelegated=0`.

Territory conformance: **0 strays**; 880 files bucketed as scaffolding or other
groups' code (`docs/` 773 · `skills/` 66 · `tests/` 14 · root 14 · `agents/` 11
· other 2). `jimconf.sh` and `tests/jimconf.sh` belong to `platform` — the
ordinary domain→platform straddle, not a stray.

### Contracts

The graph names `issue` as provider on 7 edges; 1 was change-selected because
the build touched its provides-side code: **`platform → validator-lockstep`**,
requiring byte-identical `is_valid_id` across `jimfile.sh`, `index.sh` and
`render.sh`. **Holds** — all three copies cksum `3250514351`, 508 bytes, and the
diff never touched the function. The other six (`new.sh` emitter, the § 7a
candidate-batch contract, the placement door, placement-read) have provides-side
code this build did not touch. `edges_checked=1`, `edge_violations=0`.

## Metrics

| metric | value |
| :--- | :--- |
| commits (recorded range) | 24 — 15 feat · 4 test · 1 fix · 4 chore/docs |
| commits (effective range) | 30 |
| insertions / deletions | 2,343 / 52 across 7 source files |
| tests added | +78 in `tests/issues.sh`, +3 in `tests/jimconf.sh` |
| suite | 1,443 tests across 16 files, all green |
| spec → plan → build | 5,288s · 31,964s · 7,001s |
| security phases | 2 runs, 32,927s |
| interruptions | 0 at every stage |

## Security regressions

**1 — introduced by this build.** The charset gate no longer refuses values
carrying `<` or `>`; they are silently reduced to a substring and recorded.
Detail in Finding 1. This is a regression rather than a pre-existing gap:
before the change, `validate` ran on the raw value with no mapping step ahead
of it.

No secrets were committed. No trust boundary was weakened elsewhere: the awk
interpolation into YAML is bounded by the charset excluding `"` and `\`, the
`git check-mailmap` invocation is quoted and separator-guarded, and the new
index warning never emits an identity value.

## Findings

### 1. Values carrying `<` or `>` bypass the charset gate — critical

`normalize` runs `map_alias` before `validate`. The extraction reads the text
after the **last** `<` in git's answer, so a malformed value is truncated to a
charset-clean substring that then passes on its own merits.
`junk<attacker@evil.example` records as `attacker@evil.example`. Reaches
`new.sh:204`, `transition.sh:228`, `migrate.sh:437` and `migrate.sh:619`; only
`--from/--to` is immune. No test exercises a bracket-bearing value.
`skills/issue/scripts/identity.sh:168-185`.

### 2. `apply_identity_plan` composes a path from an unvalidated slug — high

`migrate.sh:852`. Not reachable as traversal, but inconsistent with the rule as
written and with `index.sh:404` / `new.sh:259-266`. The sibling
`apply_schema_plan:503` shares it (pre-existing).

### 3. The mismatch surface is fail-open on values it cannot normalize — notable

`index.sh:606-612`. When `normalize` fails, `ident_form` falls back to the
value itself, which trivially equals itself, so the record is reported as
conforming. Verified: a collection holding `bob]smith@…` and `has space@…`
reports neither, flagging only the clean relay address. A value that cannot be
normalized can never legitimately equal a normalized form, and those are
exactly the records a form migration needs surfaced.

### 4. The argument parser swallows a flag as a `--from`/`--to` value — notable

`migrate.sh:902-903`. Verified: `identity docs/issues --from --apply --to
new@example.test` runs a preview with `from = "--apply"`, rc 0, no error. The
hyphen is in the accepted charset, so the swallowed flag passes validation.

### 5. Mode exclusivity is bypassed by a value-less `--from` — notable

`migrate.sh:912`. `remap` is set only when `from`/`to` are non-empty, so
`--renormalize --from` trips neither the both-modes check nor the both-halves
check. Verified: it runs a full re-normalization silently. With `--apply` this
rewrites the whole collection on an intent the parser never confirmed.

### 6. `README.md` omits both new config keys — notable

The "Supported keys" table lists every other family, including dynamic-suffix
ones. A user scanning it for how to control the recorded form will not find it.

### 7. `docs/features/issues.md` omits the feature entirely — notable

Config table, migrations table and the frontmatter example are all silent on
identity. The migrations table still says "Four one-shot commands" and lists
neither `schema` (pre-existing) nor `identity`. The new index warning points
users at `migrate.sh identity --renormalize`, a command this doc never explains.

### 8. Six new tests do not discriminate — advisory

Most notably `case_migrate_identity_usage_refuses_both_modes`, which asserts the
error contains `renormalize` — text present in *both* refusal branches, so
collapsing them into one generic message would still pass. Also: two mailmap
passthrough cases that git satisfies even with `map_alias` deleted; a
scheme-default case that rules out `local` but never pins `github`; a
lower-case no-op a `cat` would pass; and an index-regeneration case checking
only that the file exists.

### 9. `alias_source` and the applied mapping resolve from different roots — notable

`alias_source` is `-C "$dir"`-scoped; the mapping actually applied resolves
from the process's working directory. Under placement routing `$dir` can be a
materialized directory with no `.git`, so the disclosure can read "none found"
while a mapping from the developer's checkout was in fact applied.

### 10. A leading-dot domain silently no-ops — advisory

`identity_domain = ".company.example"` clears every gate, then matches no real
address, making organization-local extraction a permanent no-op with no signal.

### 11. `apply_identity_plan`'s awk lacks its sibling's completion guard — advisory

`apply_schema_plan` ends with `END { exit (scalars && member) ? 0 : 1 }`;
`apply_identity_plan` has no equivalent, so a file missing the target field
would be moved into place unchanged and counted as rewritten. Reachability is
narrow — the plan is rebuilt inside the same invocation that applies it — so
this is an inconsistency with an established pattern, not a live defect.

### 12. The collision check cannot see an already-converged record — advisory

A record already holding value `V` emits no rewrite row, so it contributes
nothing to the distinctness count. A genuinely different contributor's address
normalizing to `V` is therefore not flagged. Architecturally unavoidable — the
original address is unrecoverable once the field reads its final form — and
deliberately chosen, since treating it as a collision would make re-normalizing
a part-migrated collection impossible. Recorded as a known limitation.

### 13. Coverage gaps in the new write path — advisory

The remap `--apply` path has no test (all remap cases stop at preview, all
apply cases use `--renormalize`). `apply_identity_plan` has no fault-injection
seam, unlike `apply_plan`'s `MIGRATE_FAIL_STAGING`/`MIGRATE_FAIL_COMMIT`. No
case pairs `identity --from/--to` with an active placement branch.
`transition.sh`'s index-failure path has no test.

### 14. No mechanical check that a config key reaches its reference — notable

`docsurfaces.sh` has an introduction-sweep for `jimledger.sh` verbs and none for
`migrate.sh` subcommands or `jimconf.sh` keys. That is why `schema` slipped
through the previous build undocumented and `identity` slipped through this one
— the same hole, twice, silently.

## Deviations & feedback

**Three deviations from the plan, all deliberate and stated:**

1. **Case folding was moved ahead of extraction**, against the plan's data-flow
   diagram which folds last. The diagram's order is wrong for mixed case:
   `1234+Dev@Users.NoReply.GitHub.com` would fail the exact suffix match and
   record as a full address while the same person's lower-case spelling records
   as `dev` — the split the spec exists to close. Folding first is the only
   order satisfying both the lower-case and the relay criteria. Pinned by test.
2. **`identity.sh` gained a fourth verb, `map`**, beyond the plan's three-verb
   interface contract. Required by the post-build collision fix: a normalized
   value cannot say which of the two steps moved it, so the comparison needs the
   mapping step exposed. It also retired a duplicate `git check-mailmap` call.
3. **`jimconf.toml.example` was added to the manifest** before the build, on the
   developer's approval, after the omission was spotted during preparation.

**On the plan's claim that "the separator is the whole fix."** Imprecise. The
value is wrapped in angle brackets because that is the input form the command
accepts, and the wrapping alone neutralizes option shape —
`git check-mailmap "<--help>"` with no separator returns `<--help>` as data.
The separator is still correct and cheap. Two independent routes reached this
correction: hand-verification during the build, and the test-discrimination
audit noting the mutant is not isolable.

**On process.** The most valuable defect of the whole cycle — the collision
check refusing mailmap-unified addresses — was found by *running the verb
against the real collection*, not by the 30 tests that passed over it. Every
test fixture used addresses the mapping said nothing about, so the gap sat in
the blind spot between them. Finding 1 has the same shape: no fixture carries a
bracket-bearing value. The lesson is not "write more tests" but "exercise the
thing against real data before believing the suite."
