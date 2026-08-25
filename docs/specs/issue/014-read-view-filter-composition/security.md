---
spec: "docs/specs/issue/014-read-view-filter-composition/spec.md"
reviewed_phases: [spec, plan]
status: Needs Plan Review
date: "2026-08-25"
---

# Security Review: Read-view filter composition

## Summary

**Findings:** 0 Critical · 1 Notable · 3 Advisory *(open)* — the eight findings
from the spec-only pass are all resolved; see § Resolved in this pass.

Second pass, dual lens: the spec's four amendments landed and `plan.md` now
exists, so the design-flaw lens ran alongside the requirements-gap one. LINDDUN
stays active — the feature makes contributor identity a queryable axis and
writes it into a generated artifact. Still no Critical findings, honestly rather
than softly: a read-only view over a local collection, no network, no
credentials, no session state, no privilege boundary between callers. The one
Notable is a boundary the plan does not reach: the routing decision that chooses
*which collection* a read serves is made before dispatch, by a helper the task
breakdown never touches, and both of the plan's new argument shapes break it.

## Coverage

- spec.md — reviewed 2026-08-25 (requirements-gap lens; re-reviewed after the
  first pass's four amendments)
- plan.md — reviewed 2026-08-25 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes | `filed-by` and `claimed-by` hold a contributor's email address, or an account name extracted from one under the project's `identity_scheme`. This spec makes both queryable and writes both into `INDEX.md`. |
| Credentials | No | No passwords, tokens, keys, or secrets are read or written. |
| Session data | No | No sessions exist; every invocation is a stateless read. |
| Internal-only | Yes | Issue slugs, ordinals, labels, and `origin` paths naming internal spec directories. |
| Public | Yes | The collection and its index publish to the destination branch named by `issue_placement`; whether that branch is public is the project's choice, not this feature's. |

## Resolved in this pass

Every finding from the spec-only pass is addressed. Retained below for the
record; none needs further action.

| # | Finding | Resolved by |
| :--- | :--- | :--- |
| 1 | Flag operand read as the collection directory | plan DD 1, tasks 6–8 |
| 2 | Filter values reaching awk as program text | plan DD 7 |
| 3 | Pre-widening index answers with silence | spec AC (index group); plan DD 6, task 12 |
| 4 | Out of Scope omits identity authenticity | spec Out of Scope entry |
| 5 | Refusal can echo a resolved identity | spec AC (person group); plan task 11 |
| 6 | Unquoted prefix comparison acts as a glob | plan DD 8, task 13 |
| 7 | `claimed-by` has no commit-history equivalent | spec Out of Scope clause |
| 8 | Documented identity discipline lists write paths only | plan Constitution Check + Out of Scope (gate-handled) |

## Findings

*Findings 9–12 are this pass's; 1–8 above are resolved and kept for the record.*

### 9. The routing decision is made before dispatch, and both new argument shapes break it

- **Severity:** Notable
- **Description:** Which collection a read serves is decided in `main()` by
  `route_placement` → `dir_given` (`render.sh:~100-130`), **before** any verb
  runs. The plan's task 7 fixes how `cmd_list` binds the collection but nothing
  in the breakdown touches `dir_given`, whose two relevant arms both assume the
  pre-filter argument grammar:
  - `list` matches on `[[ -d "$2" ]]` **without** an `is_filter_token` guard on
    that position. With flags, `$2` is a flag's operand, so `list --label auth`
    where `./auth` exists declines routing and silently serves the working-tree
    collection instead of the configured destination — violating the
    `render.sh` provides-face guarantee that "reads serve the collection at the
    configured placement rather than a branch-local copy."
  - `stats` matches on `(( $# >= 1 ))`, justified in its own comment: *"their
    operand is a directory or it is nothing — there is no filter to confuse it
    with."* Task 17 makes that false. Any filtered `stats` declines routing;
    verified against the current script, `render.sh stats --spec issue/011`
    already reports `'--spec' is not an existing collection directory`.

  This project runs `issue_placement=branch`, so both arms are live on day one
  rather than latent. The `stats` arm fails loudly, which is the better failure;
  the `list` arm fails silently, which is the one that matters.
- **Suggestion:** Add a task making `dir_given` filter-aware for both verbs —
  the routing decision and the binding decision must read arguments by the same
  grammar, or they will disagree exactly where it is least visible. Cover it
  with cases asserting that a filter whose operand names an existing directory
  still routes, and that a filtered `stats` routes.
- **Route:** Plan
- **Relates to:** plan task 7 and task 17; `issue` group blueprint § Provides:
  `render.sh` read views.

### 10. The plan reverses reserved-word precedence without stating the rule

- **Severity:** Advisory
- **Description:** Today the two argument readers disagree: `dir_given` guards
  its single-argument branch with `! is_filter_token`, while `cmd_list`'s shape
  read takes the trailing argument whenever it is a directory, with no such
  guard. Unrouted, `list open` with a directory named `open` present therefore
  binds `open` as the collection and applies no filter. DD 1 fixes this by
  construction — classification runs first, so a reserved word is consumed as a
  filter and never reaches the residue — but the plan does not name the rule it
  is establishing, and the rule has a user-visible corollary: a directory whose
  name collides with a reserved word can no longer be named as a collection.
- **Suggestion:** State the precedence explicitly — a reserved word always reads
  as a filter, never as a collection — and test it in both directions, so the
  corollary is a decision rather than a discovery.
- **Route:** Plan
- **Relates to:** plan DD 1; spec AC "The reserved reading of a bare word is not
  overridable".

### 11. A refusal echoes an operator token to a terminal unsanitized

- **Severity:** Advisory
- **Description:** The spec's mockup echoes the offending token
  (`error: unrecognized filter token: 17`), which is right — the operator typed
  it, so it discloses nothing. What is unaddressed is its *shape*. `row_safe`
  exists precisely because values reaching a rendered surface can carry control
  characters, and it strips them, deletes the separator, and bounds length
  before anything is emitted. A refusal writing raw argv to stderr is the same
  rendered surface with none of that treatment, so a token carrying terminal
  escape sequences is echoed intact.
- **Suggestion:** Put echoed tokens through the same discipline `row_safe`
  applies — strip control characters and bound the length — so the two surfaces
  that render untrusted-shaped text agree.
- **Route:** Plan
- **Relates to:** plan tasks 6 and 15; `issue` group blueprint § Provides:
  `index.sh` row sanitizer.

### 12. `read_graph_edges` says "the id charset" where `is_valid_id` means more

- **Severity:** Advisory
- **Description:** The plan's contract specifies the helper's slug pattern as
  `[A-Za-z0-9][A-Za-z0-9._-]*` — "the `is_valid_id` charset". `is_valid_id` is
  not only that charset: it separately rejects an empty value, caps length at
  128, and rejects any value containing `..` **before** applying the regex. A
  regex-only helper therefore accepts `a..b`, which `is_valid_id` refuses. No
  traversal follows — graph edges are compared against row slugs and never
  composed into a path — but `id-gate-before-path` is a critical invariant and
  this is the kind of near-miss that reads as compliance later.
- **Suggestion:** Say which semantics the helper implements and why the
  difference is safe here — that an edge slug is compared, never opened — or
  reuse `is_valid_id` outright. Either is fine; leaving "the id charset" to
  imply the whole function is not.
- **Route:** Plan
- **Relates to:** plan DD 5 and the `read_graph_edges` interface contract;
  `issue` group blueprint § Invariants `id-gate-before-path`.

### 1. A flag operand in trailing position is read as the collection directory

- **Severity:** Notable
- **Description:** *(Revised 2026-08-25 during planning — see the correction
  note at the end of this finding.)* The collection is identified by **shape**:
  `cmd_list:400-403` takes the trailing argument, and only when it is a
  directory. That is safe today only because no reserved bare word plausibly
  names one. Flags break the assumption, because a flag's operand can land in
  trailing position — and the failure is silent rather than loud. In this
  repository `list --label docs` would take `docs` as the collection and print
  `_No matching issues._` rather than filtering by that label.

  **The retarget also writes.** `ensure_index` refuses to create a directory,
  but on one that already exists it regenerates an index inside it. Verified
  directly: `render.sh list docs` creates `docs/INDEX.md` — an empty index, in
  the developer's checkout, written by a read verb. Removing the file and
  re-running the command recreates it. So the consequence is not only a wrong
  answer; it is a stray generated artifact in whatever existing directory the
  operand happens to name.

  `cmd_stats` carries the same trailing positional (`render.sh:236-245`) and
  gains the same parse surface.
- **Suggestion:** Consume every flag and its operand during parsing, and bind
  the collection from what remains rather than from raw argv. Cover it with a
  case asserting that a filter whose operand names an existing directory filters
  on that value instead of retargeting the collection — and that **no `INDEX.md`
  appears in that directory**, which is the observable that distinguishes a
  retarget from a mere empty result.
- **Route:** Plan
- **Relates to:** AC "A read view accepts several filters in one query, given in
  any order"; Handoff Insight 6.

> **Correction, in two steps.** As first written, this finding claimed the
> refusal ordering was the only guard and that a bound directory would reach
> `index.sh`'s `mkdir -p`. That is wrong: `ensure_index` opens with
> `[[ -d "$dir" ]] || return 0` — "a read never brings a collection into
> being" — so no read verb creates a directory, whatever the parse order.
>
> The first correction then went too far the other way, calling the surviving
> hazard merely a silent wrong answer. It is not. `ensure_index` declines to
> *create* a directory but happily regenerates an index inside one that already
> exists, so the retarget writes `INDEX.md` into it. That was verified by
> running it, not reasoned about. A read verb writing to the checkout is the
> original defect's whole shape — narrower in reach than a `mkdir`, identical in
> kind.
>
> The regression cases asserting *no directory was created* stay, and the plan
> now also asserts *no index was written*, which is the stronger observable.

### 2. Filter values must not reach an awk program as program text

- **Severity:** Notable
- **Description:** The new axes read the index's Issues rows and its Graph
  section, both parsed with awk. Every filter value is developer-supplied
  string data, and `ARCHITECTURE.md` § Skills already records why `-v` is the
  wrong channel for untrusted values in these scripts — awk processes a `-v`
  operand as a string literal and expands escape sequences, which is why the
  issue scripts pass values through the environment instead. Interpolating a
  filter value into the awk *program* itself is strictly worse than `-v`: it is
  code injection into the awk interpreter, not merely an escape-expansion
  surprise.
- **Suggestion:** State the rule where the plan can enforce it: awk programs are
  single-quoted literals; every filter value reaches awk through `ENVIRON`, and
  none is concatenated into program text. Where the comparison can be done in
  shell over rows already loaded, prefer that over passing the value to awk at
  all.
- **Route:** Plan
- **Relates to:** AC group "Composing a query"; `ARCHITECTURE.md` § Skills
  (backfill timestamp discussion).

### 3. A pre-widening index answers a person filter with silence, where the same question refuses loudly

- **Severity:** Notable
- **Description:** The spec settles two failure paths for the same user question
  — "what am I holding?" — and they behave oppositely. When the environment's
  identity cannot be resolved, the query **refuses loudly** with a non-zero
  status, and the spec's Open Questions justify that precisely: an empty result
  "would be indistinguishable from genuinely holding nothing." But Handoff
  Insight 4 accepts a second path to the same indistinguishable emptiness: the
  staleness gate rebuilds only when the index is older than the collection's
  files, so an index written before the row was widened can be served as
  current, and every person, kind, and outcome filter then matches nothing. The
  view reports that honestly and wrongly. One silent false negative was reasoned
  about and refused; the other was accepted two sections later.
- **Suggestion:** The condition is mechanically detectable without the version
  marker Insight 4 rightly rejects. `type` is non-empty on every record after
  012's conversion, so *rows exist but none carries `type`* identifies a
  pre-widening index with no stamp, no schema version, and no transition code.
  Add an AC requiring that a view whose index cannot answer the axis a filter
  names discloses that and carries a non-zero status, rather than reporting an
  empty match — the same rule the unresolvable-identity path already follows.
- **Route:** Spec
- **Relates to:** AC "When the environment's identity cannot be resolved …";
  Handoff Insight 4; `issue` group blueprint § Invariants
  `staleness-gated-reads`.

### 4. Out of Scope reasons about identity concentration but not identity authenticity

- **Severity:** Notable
- **Description:** The spec's Out of Scope carefully establishes that recording
  the filer and holder on every index row is a concentration change rather than
  a disclosure change. That reasoning is sound and it is not the risk a reader
  of `--filed-by` will run into. Spec 013 § Out of Scope states the actual one:
  version control does not verify the address a contributor configures, so
  neither does jim, and this "matters more under extraction than it did before:
  a bare address reads as self-asserted, while an extracted account name reads
  like something an identity provider issued, and the two are textually
  indistinguishable." Turning that value into a filter axis compounds exactly
  that. `--filed-by alice` reads like an authenticated query; it is a string
  comparison against a value its subject asserted about themselves, and anyone
  who can commit can assert a different one.
- **Suggestion:** Carry 013's exclusion forward into this spec's Out of Scope
  rather than leaving it one artifact away — a filter over unverified
  attribution is where a maintainer will actually rely on it. One entry stating
  that a person filter reports what was recorded, never what was verified, and
  that it is unsuitable as an attribution control.
- **Route:** Spec
- **Relates to:** Out of Scope § "Concentration of contributor identities in the
  index"; spec 013 § Out of Scope.

### 5. A person-filter refusal can echo an identity the operator never typed

- **Severity:** Advisory
- **Description:** `identity.sh` holds a strict discipline that a refused value
  never appears in its refusal — reasons are fixed strings so a terminal log
  cannot be made to carry a rejected value. The spec's refusal AC is written for
  the case where nothing resolves, which is safe. The uncovered case is where
  resolution *succeeds* and normalization then refuses: `--claimed-by me` under
  an `identity_scheme` that cannot judge the resolved address, or under the
  organization-local form with no `identity_domain` configured. The value being
  refused there came from the environment, not from the operator's keystrokes,
  so echoing it into the error is the situation 013's rule exists for. A value
  the operator typed themselves is a different matter and needs no such care.
- **Suggestion:** Specify that a refusal arising from a value the view resolved
  rather than the operator supplied names the condition and the setting to fix,
  never the value — matching `identity.sh`'s existing behavior instead of
  introducing a second convention beside it.
- **Route:** Spec
- **Relates to:** AC "When the environment's identity cannot be resolved …";
  `issue` group blueprint § Provides: `identity.sh`.

### 6. An unquoted prefix comparison turns a filter value into a glob

- **Severity:** Advisory
- **Description:** `--spec` and `--origin` are the only filters using a prefix
  comparison rather than equality. In bash, `[[ "$origin" == "$prefix"* ]]`
  matches literally only because `$prefix` is quoted; unquoted, its `*`, `?`,
  and `[` are pattern metacharacters, and a value containing one silently widens
  the match instead of narrowing it. The consequence is bounded — a read verb
  returning more rows than asked for, all of which the caller could already
  read — so this is a correctness defect with a security shape rather than a
  vulnerability. It would escalate if a prefix value were ever composed into a
  path, which the spec forbids.
- **Suggestion:** Require that prefix matching is literal, and cover it with a
  case asserting that `--origin '*'` matches records whose origin literally
  begins with an asterisk rather than every record.
- **Route:** Plan
- **Relates to:** AC "An origin match is a path prefix …".

### 7. `claimed-by` is the one recorded identity with no equivalent in commit history

- **Severity:** Advisory
- **Description:** The Out of Scope entry defends index concentration on the
  grounds that every value the index carries "is already in a file beside it."
  True, and it stops one step short of a distinction worth recording. A filer
  is also recoverable from the file's creating commit — 012's conversion does
  exactly that. A holder is not: spec 013 § Problem Statement notes that a claim
  "leaves no trace in the file's creation history, so it cannot be recovered
  even in principle." So `claimed-by` is the only identity here whose sole
  record is the file, with no parallel channel a reader already has.
- **Suggestion:** One clause in the existing Out of Scope entry noting that the
  filer has a commit-history equivalent and the holder does not, so the
  "already available elsewhere" argument covers one field and not both. It does
  not change the conclusion; it stops the argument being broader than its
  evidence.
- **Route:** Spec
- **Relates to:** Out of Scope § "Concentration of contributor identities in the
  index".

### 8. The documented identity discipline enumerates write paths only

- **Severity:** Advisory
- **Description:** `ARCHITECTURE.md` § Security Considerations → Recorded
  identity states that `identity.sh` is the single place deciding what a
  recordable identity is and what form it takes, and that "every write path
  routes through it — the emitter, the transition verbs, the conversion — so one
  definition cannot drift into several." This spec adds the first *read* path
  through the same definition: a person filter normalizes its query so that a
  query and a record agree. That is the correct design and the paragraph does
  not describe it, so the next reviewer reading that section will reason about a
  closed set of three write paths.
- **Suggestion:** Fold the read path into the plan's ARCHITECTURE.md refresh
  scope alongside the index-row format change the research already flags, so the
  enumeration stops being exhaustive-by-implication.
- **Route:** Plan
- **Relates to:** AC "A person filter matches a record when the query and the
  record name the same contributor under the project's configured form".

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Finding 4 (resolved) — a person filter reads as an authenticated query over self-asserted values. |
| Tampering | Yes | Findings 9, 10, 12 open; 2 and 6 resolved. A read served from the wrong collection, an argument grammar two readers disagree about, and a slug pattern narrower than the validator it cites. |
| Repudiation | N/A | Read verbs mutate nothing. The lifecycle verbs that record a holder already commit under a verb-scoped commit on the placement branch, so the audit trail is git's and is unchanged by this spec. |
| Information Disclosure | Yes | Finding 11 open — a refusal renders an untrusted-shaped token to a terminal with none of the sanitation the index rows get. Findings 4, 5, 7 resolved. |
| Denial of Service | No | Single-user local CLI with no network and no concurrency. All work is bounded by collection size over data the index already renders and `cmd_stats` already parses; the derived predicates add no unbounded read. |
| Elevation of Privilege | No | A read verb acquiring the ability to write is the only privilege-shaped surface, and two independent guards close it: argument classification before the collection binds, and `ensure_index`'s `[[ -d "$dir" ]]` existence check, which keeps `index.sh` from being invoked on a directory that does not exist. The `issue-analyst` subagent's `Bash(… render.sh *)` grant admits every new flag by construction; all are read-only, so `insights-capability-boundary` holds. |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | Yes | No new issues found. Linking one contributor's several addresses to one identity is the feature's declared purpose, settled in spec 013 and its Out of Scope; this spec queries that linkage rather than creating it. |
| Identifying | Yes | No open issues. Finding 7 (resolved) recorded that the filer is re-derivable from commit history while the holder is not, so the two fields do not carry the same re-identification story; the spec's Out of Scope now says so. |
| Non-repudiation | N/A | No mechanism here prevents a subject from denying an action; the recorded values are self-asserted, which is Finding 4's subject rather than a non-repudiation property. |
| Detecting | Yes | No new issues found. A contributor's presence in the collection is already evident from the issue files and from commit history; the filter is a convenience over data already co-located. |
| Data Disclosure | Yes | Finding 11 open — an unsanitized token rendered to a terminal. Findings 4, 5 and 7 resolved: the refusal path no longer echoes a resolved identity, and Out of Scope now covers both authenticity and the filer/holder asymmetry. |
| Unawareness & Unintervenability | Yes | No new issues found. 013 shipped the intervention path — a contributor's recorded identity is rewritable collection-wide behind a preview and an explicit apply gate — and the index already reports when recorded identities diverge from the configured form. |
| Non-compliance | N/A | The project states no privacy policy and processes no regulated data; the collection records what version control already publishes. |

## Artifact Misalignment

*Dual lens — spec and plan reviewed together.*

- **Finding 9 — filtered `stats` cannot reach its collection.** The spec
  requires that "the statistics view accepts the same filters as the list view,
  under the same combining rules." The plan's task 17 implements the parsing and
  scoping, but the design does not preserve the requirement under this project's
  own `issue_placement=branch` configuration: `dir_given`'s `stats` arm treats
  any argument as a supplied directory and declines routing, so a filtered
  `stats` never reaches the collection it is meant to summarize. The spec is the
  source of truth here and the gap is in the plan. Route: Plan.

No other spec↔plan inconsistency found. Every acceptance criterion appears in
the plan's coverage table with a task, the four amendments from the first pass
each trace to a task, and the plan's Out of Scope neither widens nor narrows the
spec's.

## Routing Recommendations

*Second pass: findings 1–8 are resolved and need no routing. Findings 9–12 all
route to Plan; nothing this pass routes to Spec.*

### Spec amendments

*All four from the first pass applied to `spec.md` on 2026-08-25. Handoff
Insight 4 was revised in the same pass, because Finding 3 reverses the silent
acceptance it recorded. No spec amendment arises from the second pass.*

- **Finding 3:** add an AC requiring that a view whose index cannot answer a
  named axis discloses that and carries a non-zero status, rather than reporting
  an empty match — detected via `type` emptiness across rows, not a schema
  stamp.
- **Finding 4:** add an Out of Scope entry stating that a person filter reports
  what was recorded, never what was verified, and is unsuitable as an
  attribution control.
- **Finding 5:** specify that a refusal over a value the view resolved rather
  than the operator supplied names the condition and the setting, never the
  value.
- **Finding 7:** add a clause to the existing concentration entry distinguishing
  the filer (recoverable from commit history) from the holder (not recoverable
  even in principle).

### Plan amendments

*Findings 1, 2, 6 and 8 are already reflected in `plan.md`. The four below are
outstanding.*

- **Finding 9:** add a task making `dir_given` filter-aware for `list` and
  `stats`, so the routing decision and the binding decision read arguments by
  one grammar. Cover a filter whose operand names an existing directory, and a
  filtered `stats`, both still routing.
- **Finding 10:** state the reserved-word precedence rule in DD 1 and test both
  directions, including the corollary that a directory named for a reserved word
  can no longer be named as a collection.
- **Finding 11:** sanitize echoed tokens the way `row_safe` sanitizes rendered
  row values — strip control characters, bound the length.
- **Finding 12:** say which of `is_valid_id`'s semantics `read_graph_edges`
  implements, and why the difference is safe where an edge slug is compared and
  never opened.

### Candidate issues

No findings route to Issue — all eight are in scope for this spec or its plan.
