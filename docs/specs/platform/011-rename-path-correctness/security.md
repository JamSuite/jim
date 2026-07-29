---
spec: "docs/specs/platform/011-rename-path-correctness/spec.md"
reviewed_phases: [spec, plan]
status: Needs Plan Review
date: "2026-07-29"
---

<!-- Budget: findings are actionable and specific. No vague "consider security" entries. -->

# Security Review: Rename-path correctness gates

## Summary

**Findings:** 1 Critical · 4 Notable · 3 Advisory *(cumulative; 3 resolved by the
plan)*

**The Critical is Finding 5** — the plan's mitigation for Finding 1 introduces a
denial-of-allocation vector that Finding 1 itself did not have: bounding the fold
at the ceiling and erroring on exhaustion means one crafted record can drive a
group to the ceiling and permanently prevent it from allocating again. Route:
Plan.

Reviewed `spec.md` under the requirements-gap lens (no `plan.md` yet). The spec
corrects a read path over a **push-writable** registry, so the whole review turns
on what a crafted-but-well-formed record can do once three previously-ignored
fields start being consulted. Both Notable findings are consequences the spec's
criteria leave implicit rather than defects in them; both were reproduced by
executing the allocator. LINDDUN is omitted — no PII, credentials, or session
data is read by any changed path.

**Both Spec-routed findings were applied to `spec.md` in this same run** (see
Routing Recommendations), so `status:` is `Active` — it tracks current state, not
what the review originally found. Nothing Critical or Notable is outstanding
against the spec. The two Advisory findings routed to Plan remain open by design;
planning has not run.

## Coverage

- spec.md — reviewed 2026-07-29 (requirements-gap lens)
- plan.md — reviewed 2026-07-29 (design-flaw lens)

*Re-run delta: Findings 1, 3, and 4 are **resolved** — the plan implements each
mitigation. Finding 2 is **partially resolved**: the plan chose a mechanism that
satisfies the requirement today but not by construction (see Finding 6).
Findings 5–8 are **new** from the plan lens.*

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | The changed paths read ordinals, group tokens, and durable ids only. The registry's `<who>` provenance field (derived from `git config user.name` / `user.email`) and the human-readable title-derived slug are never consulted by resolution or the high-water fold. The disclosure surface those create is `platform/007` / `issue/010`'s, acknowledged there and unchanged here. |
| Credentials | No | No credential is read, stored, or transmitted; every changed function is a pure read over a local log. |
| Session data | No | None exists in this system. |
| Internal-only | Yes | Project-internal spec ordinals, issue ordinals, durable ids, group names, and registry records. |
| Public | No | The coordination branch is readable by anyone with repo read access — a `platform/007` property, unaffected by this spec. |

## Findings

Numbering is stable across runs so routing history stays traceable, so these read
in ascending order rather than severity order. Findings 1–4 are the spec-phase
findings with their disposition; **5–8 are new, and Finding 5 is the Critical.**

### 1. Counting rename sources widens an unbounded fold, and past 999 the registry stops being re-seedable

- **Status:** **Resolved by the plan** — Design Decision 3 bounds the fold and
  tasks 5–7 fixture and implement it. The bound is the right mitigation; the
  exhaustion behavior the plan pairs with it is not (Finding 5).
- **Severity:** Notable
- **Description:** D2 makes the high-water fold consult a rename record's *source*
  ordinal. That field is attacker-appendable on the coordination branch, and the
  fold applies no magnitude bound, so one well-formed crafted record moves a
  group's or the issue counter's next ordinal arbitrarily far. Two consequences,
  both reproduced: (a) the fold's `10#` arithmetic silently wraps — a 20-digit
  ordinal in the already-folded rename-destination position yields a next-ordinal
  of `7766279631452241920`, so the same input class reaches the source field once
  D2 lands; (b) `alloc_next_id_spec` accepts and mints 4-digit spec ordinals
  (`dashboard/1000` → `dashboard/1001`), while the seed refuses any ordinal above
  999 (`jimalloc.sh:469`). An inflated group therefore mints spec ids that the
  bootstrap can never re-derive — a one-way door, and D2 makes it one record away
  rather than 999 real specs away. The direction is still safe (a consumed id is
  never freed), so this is availability and recoverability, not reuse.
- **Suggestion:** Extend the spec's conservative-fold criterion from a direction
  guarantee to a *bounded* one: a folded ordinal that exceeds the representable
  ordinal range is skipped as malformed rather than counted. Reconcile the bound
  with the seed's existing 999 guard so the two agree on what a legal spec
  ordinal is — the seed-side cap is already tracked as issue #121; this is the
  fold-side half, which that issue does not cover.
- **Route:** Spec
- **Relates to:** the D2 criterion (vacated ordinal never reissued) and the
  conservative-miscounting criterion.

### 2. Group aliasing lets one crafted record silently redirect a group's allocation namespace

- **Status:** **Partially resolved** — the spec now requires the redirect to be
  named, and Design Decision 5 routes the advisory to stderr, which is visible in
  every path today. But stderr is discardable, so the requirement holds by
  convention rather than by construction (Finding 6).
- **Severity:** Notable
- **Description:** D3 teaches the high-water to follow `group rename` records, and
  the settled decision is that asking about a renamed-away group answers for its
  current name. A single crafted `group rename <victim> <attacker>` record
  therefore makes `peek spec <victim>` and `allocate spec <victim>` answer under
  `<attacker>` — and once the spec consumer is wired (issue #112), a developer
  scoping work in `<victim>` would have the spec created in the `<attacker>`
  group's directory. Both tokens pass `alloc_valid_token`, so there is no path
  traversal or option injection; the exposure is a *silent* namespace redirect
  that the developer never sees, on a surface whose whole purpose is to be the
  authoritative answer. The spec's criteria describe the redirect as correctness
  (the resolver and allocator must agree) without stating that a redirect is
  followed unconditionally and unannounced.
- **Suggestion:** State in the criterion that the redirect is followed, and decide
  whether the verb *reports* it — e.g. answering `<attacker>/003` while naming the
  group-rename record that redirected the query, so a redirect the developer did
  not expect is visible rather than silent. This composes with the return-contract
  ambiguity research already flagged for the PM on the same criterion.
- **Route:** Spec
- **Relates to:** the two D3 criteria (group-rename aliasing; renamed-away group).

### 3. D4's relaxed validity gate must stay numeric-only

- **Status:** **Resolved by the plan** — Design Decision 2 and task 9 keep the
  numeric check and the durable-id boundary as separate gates, with `existing[]`
  keyed only on a boundary-valid id.
- **Severity:** Advisory
- **Description:** D4 is fixed by counting a record's ordinal even when its paired
  durable id fails the id boundary — today `alloc_reconcile_realize:373`
  `continue`s before the `max` update at `:375`. Relaxing that gate means a record
  the boundary rejected still influences a computed value. Safe only if the
  relaxation is strictly numeric: the rejected durable id must not additionally
  become an `existing[]` key, reach a path, or reach a git argument on the
  strength of its sibling ordinal now being trusted.
- **Suggestion:** Keep the two gates separate in the design — count the ordinal on
  a numeric-class check alone, while continuing to key the already-realized map
  only on a boundary-valid durable id. Add a fixture asserting a
  boundary-invalid durable id raises the high-water without entering the map.
- **Route:** Plan
- **Relates to:** the D4 criterion (allocation and reconcile agree).

### 4. Group-chain resolution is an attacker-appendable input to a potential O(n²) walk

- **Status:** **Resolved in intent by the plan** — Design Decision 4 resolves the
  chain once into a map. Whether the map's *construction* is itself linear is the
  open half (Finding 8).
- **Severity:** Advisory
- **Description:** D3 requires following a multi-hop group-rename chain. Records
  are appendable by anyone who can push, so the chain's length is
  attacker-influenced. A naive implementation that re-walks the chain once per
  folded record turns a linear pass into O(n²) over an input the attacker grows —
  mild resource exhaustion on every allocation and preview, not just once.
- **Suggestion:** Resolve the group-rename chain once into a lookup before
  folding, keeping the fold a single pass regardless of chain length. Reinforces
  the same trap research flagged as a performance note.
- **Route:** Plan
- **Relates to:** the D3 criterion (multi-hop chain).

### 5. The ordinal bound plus a hard exhaustion failure lets one record permanently deny a group

- **Severity:** **Critical**
- **Description:** Design Decision 3 pairs two changes: the fold skips ordinals
  above `ALLOC_MAX_SPEC_ORD` (999), and `alloc_next_id_spec` **errors** when
  `max+1` would exceed it. A crafted record whose ordinal sits exactly *at* the
  ceiling is not out of range, so it is counted — driving the group's high-water
  to 999 and making every subsequent allocation fail. One pushed record
  (`spec rename dashboard/999 x/001`, a source under D2's new counting, or a
  destination even today) permanently denies allocation to that group. Verified
  against current code in the destination position: a single crafted record
  already yields `dashboard/1000`, which today is an ugly-but-usable id and under
  the plan becomes a hard stop. Recovery is worse than the symptom — the only way
  back is editing the registry, and rewriting that history trips the erosion guard
  for every clone. This is strictly worse than Finding 1, whose consequence was
  wasted ordinals and a non-re-seedable registry: the mitigation converts a
  recoverability problem into an availability one.
- **Suggestion:** Decide exhaustion from *corroborated* ordinals only. Keep the
  fold counting everything, so the permanent-gap guarantee stays unconditional,
  but derive the ceiling check from ordinals that have their own `allocate`
  record — a source-only or destination-only ordinal at the ceiling with no
  allocation anywhere is itself evidence of a crafted record, and should not be
  able to close the group. That preserves both properties the spec asks for
  without letting one record weaponize the bound. Fixture the crafted-ceiling case
  explicitly.
- **Route:** Plan
- **Relates to:** Design Decision 3; the bounded-miscounting criterion; Finding 1.

### 6. The redirect is visible to a human but not named in the machine contract

- **Severity:** Notable
- **Description:** The spec requires a redirect to be named and "never applied
  silently"; Design Decision 5 satisfies that with a stderr advisory, reasoning
  that stdout is a parsed contract. **The channel is sounder than it first
  appears** — an earlier draft of this finding overstated the risk. jim's
  documented standard invocation is `!`-injection, which substitutes stdout only
  (`ARCHITECTURE.md:383`), but `ARCHITECTURE.md:503` *forbids* `!`-injection for
  any call carrying a runtime-value placeholder like `<group>`: the primitive
  tokenizes bash at load time and unquoted angle brackets hard-fail the parser.
  Every id-resolution call site is therefore a fenced block run through the Bash
  tool, where stderr does reach the agent — and it is structurally forced to stay
  that way. All four in-tree call sites confirm it, and no caller suppresses
  stderr today.

  What remains is not the channel but the **contract**. Two residual paths:
  `skills/partition/SKILL.md:413` documents its input as "passed **verbatim from
  `jimfile.sh next-id <target>` stdout**" — an explicitly stdout-only contract
  that would carry a redirect out of band if ever repointed at the allocator; and
  a future script consumer capturing with `$(… 2>/dev/null)` drops the notice,
  while `$(… 2>&1)` is worse — it folds the advisory prose *into* the captured id.
  The consumer that makes either reachable, the spec-ID wiring, is unwritten, so
  the guarantee currently rests on habits rather than a stated obligation.
- **Suggestion:** The machine-visible signal **already exists and needs no new
  channel**: `allocate spec dashboard …` returns `ui/003`, so the returned id
  carries the group, and a redirect is detectable by comparing the group asked for
  against the group received. The gap is that no contract says so — a consumer may
  reasonably assume the returned prefix is the one it passed. State in the
  Interface Contracts that the returned group is authoritative and may differ from
  the requested one, and carry that to the spec-ID wiring as an inherited
  constraint. That makes the disclosure structural at zero cost, with stderr
  remaining the human-facing courtesy.

  Note what the stricter alternative would cost: having `peek`/`allocate` *refuse*
  an aliased group unless the caller acknowledges the redirect is non-discardable
  by construction, but it contradicts the spec criterion as written — "asking for
  the next id of a group that has been renamed away **answers** for the group's
  current name." Choosing refusal means amending that criterion, not just the
  plan.
- **Route:** Plan
- **Relates to:** Design Decision 5; the renamed-away-group criterion; Finding 2.

### 7. Alias-map cycle termination is specified but unfixtured, and a hang is worse than a wrong answer

- **Severity:** Notable
- **Description:** The plan's Interface Contract states that each `group rename`
  record applies at most once in file order "so a cycle terminates." That is the
  right rule, but it lives in a comment: task 4's fixtures are unspecified as to a
  cycle, and **no group-rename cycle fixture exists today** — the only group-rename
  test is a single hop. A crafted pair (`group rename A B`, `group rename B A`) fed
  to a map builder that iterates to a fixpoint instead of walking in file order
  hangs, and it hangs inside every allocation and every preview, not just a
  resolve. The spec-rename cycle case is fixtured; the group-rename one is not.
- **Suggestion:** Require an explicit group-rename cycle fixture and a multi-hop
  chain fixture in task 4, asserting termination and the resolved value. A hang has
  no error message and no timeout here, so a passing test is the only evidence the
  rule was actually implemented.
- **Route:** Plan
- **Relates to:** Design Decision 4; task 4; the multi-hop criterion.

### 8. Eager transitive closure can reintroduce the O(n²) the map was meant to remove

- **Severity:** Advisory
- **Description:** Design Decision 4 answers Finding 4 by resolving the chain
  "once into a map," and the Interface Contract describes emitting fully-followed
  pairs in "one pass." Building a transitive closure in a single sequential pass
  requires, for each `A→B` record, re-pointing every entry currently mapping to
  `A` — an O(map) step per record, so O(n²) overall on the same
  attacker-appendable input Finding 4 flagged. The mitigation may therefore not
  mitigate.
- **Suggestion:** Specify memoized lazy resolution instead of eager closure: walk
  each distinct group's chain once on first use and cache the result, bounding
  total work by the log length regardless of chain shape. Worth stating in the
  contract, since "one pass" reads as already-linear and would not prompt the
  implementer to check.
- **Route:** Plan
- **Relates to:** Design Decision 4; Finding 4.

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity assertion is consumed by any changed path; the registry's self-asserted `<who>` provenance is not read by resolution or the fold. |
| Tampering | Yes | Findings 1, 2, 3, 5, 6 — the registry is push-writable, and `platform/007`'s erosion guard detects truncation or rewrite but not a well-formed append. |
| Repudiation | N/A | Provenance is advisory by `platform/007`'s non-goal; this spec adds no audit or attribution claim. |
| Information Disclosure | No | No new output surface. Resolution and `peek` already print ids; no changed path reads the identity or slug fields. Finding 6 is the inverse — a signal that may fail to *reach* the developer. |
| Denial of Service | Yes | **Finding 5 (Critical)** — one record permanently closes a group. Also Findings 1 (ordinal inflation), 4 and 8 (O(n²) chain walk), 7 (non-terminating alias walk hangs every allocation). |
| Elevation of Privilege | N/A | An id carries no authority (`platform/007` non-goal), so no permission is derivable from a record this spec reads. |

## Artifact Misalignment

- **Finding 6 — the visibility requirement reaches humans but is unstated for
  machines.** The spec requires a redirect to be named and never applied silently.
  The plan's stderr advisory delivers that to a human, and the invocation shape is
  structurally forced to keep stderr reachable. But nothing in the contract tells a
  *program* that the group it receives may differ from the group it asked for, so a
  consumer can honor the letter of the plan and still substitute one group for
  another without noticing. Route: Plan — the spec's requirement is right and the
  channel is adequate; what is missing is the contract sentence that makes the
  returned id's own group the disclosure.
- **Finding 5 is a design flaw, not a misalignment.** The spec asks that
  miscounting never free a consumed id and never exceed what the bootstrap
  accepts; the plan honors both. It simply chose an exhaustion behavior the spec
  did not contemplate, and that behavior is weaponizable. The fix is in the plan.

## Routing Recommendations

### Spec amendments
- **Finding 1 — applied 2026-07-29.** The conservative-miscounting criterion is
  now bounded as well as directional: an ordinal beyond what the registry's
  bootstrap accepts is skipped as malformed, so no single record can push a group
  past the point where the registry can still be rebuilt from the tree.
- **Finding 2 — applied 2026-07-29.** The renamed-away-group criterion now
  requires the answer to name the redirect it applied; a redirect is never applied
  silently. The developer settled the open half (visible, not silent), which also
  closes research's return-contract signal — the same gap seen from the caller's
  side rather than the attacker's.

### Plan amendments

- **Finding 3 — landed.** Design Decision 2 and task 9 keep the gates separate.
- **Finding 4 — landed in intent.** Design Decision 4 resolves the chain once;
  Finding 8 covers whether the construction is actually linear.
- **Finding 5 (Critical):** derive the exhaustion check from ordinals that carry
  their own allocation record, so the fold still counts everything for the gap
  guarantee but one crafted ceiling record cannot close a group. Fixture the
  crafted-ceiling case.
- **Finding 6:** state in the Interface Contracts that the returned group is
  authoritative and may differ from the requested one — the returned id already
  carries the redirect, so this makes the disclosure structural without a new
  channel. Carry it to the spec-ID wiring as an inherited constraint. (The
  refuse-unless-acknowledged alternative is stronger but contradicts the
  renamed-away-group criterion, so it would need a spec amendment too.)
- **Finding 7:** require a group-rename cycle fixture and a multi-hop fixture in
  task 4 — the termination rule is currently comment-only and untested.
- **Finding 8:** specify memoized lazy chain resolution rather than eager closure.

*No findings route to Issue this run.*

*No findings route to Issue — Findings 1–4 all land inside this spec's own scope,
and the adjacent seed-side magnitude cap is already tracked as issue #121.*
