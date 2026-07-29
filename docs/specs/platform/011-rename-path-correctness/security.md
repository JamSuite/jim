---
spec: "docs/specs/platform/011-rename-path-correctness/spec.md"
reviewed_phases: [spec, plan]
status: Active
date: "2026-07-29"
---

<!-- Budget: findings are actionable and specific. No vague "consider security" entries. -->

# Security Review: Rename-path correctness gates

## Summary

**Findings:** 1 Critical · 4 Notable · 3 Advisory *(cumulative; all 8 resolved)*

**The Critical was Finding 5**, now closed — and worth reading for how, because two
findings resolved by *reversing* their own suggestions:

- **Finding 1** asked for the allocator to be bounded to match the seed's 999
  guard. Implemented, that bound created Finding 5. The accepted fix aligns the
  guard upward instead, so the two sides share one legality value and neither can
  mint what the other refuses.
- **Finding 5** asked for exhaustion to be derived from corroborated ordinals.
  Written into the plan, that was shown not to work — an attacker appends a
  well-formed `allocate` record as easily as a rename. Removing the reachable
  ceiling altogether is what actually closes it.
- **Findings 2 and 6** closed by amending both artifacts from *name the redirect*
  to *refuse until acknowledged*, making the guarantee structural.

Two accepted trades are recorded rather than papered over: refusal converts a
stealth namespace redirect into a loud one-record denial, and the width limit still
refuses at its edge. Both rest on the same judgment — against an attacker-appendable
input, prefer a failure that names itself over a silent substitution.

Both artifacts cover a read path over a **push-writable** registry, so the whole
review turns on what a crafted-but-well-formed record can do once three
previously-ignored fields start being consulted. Every finding was reproduced by
executing the allocator rather than inferred from reading it. LINDDUN is omitted
— no PII, credentials, or session data is read by any changed path.

`status:` tracks current state rather than what the review originally found, so it
is `Active`: nothing is outstanding against either artifact. Tasks 5–7, blocked
while the ceiling conflict stood, are unblocked and both `[NEEDS CLARIFICATION]`
markers are cleared.

## Coverage

- spec.md — reviewed 2026-07-29 (requirements-gap lens)
- plan.md — reviewed 2026-07-29 (design-flaw lens)

*Re-run delta, in the order it settled: Findings 5–8 were **new** from the plan
lens. Findings 3, 4, 7, and 8 are **resolved** — the plan implements each
mitigation. Findings 2 and 6 are **resolved by amendment**, after 6 showed that
naming a redirect served humans but left the machine contract silent; both
artifacts moved to refuse-until-acknowledged. Findings 1 and 5 are **resolved by
reversal** — 1's own suggested bound produced 5, and 5's own suggested fix was
shown not to work, so the ceiling was removed rather than corrected (plan Design
Decision 3a holds the full record).*

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
in ascending order rather than severity order. Findings 1–4 came from the spec
lens, 5–8 from the plan lens; **Finding 5 is the Critical, and it is resolved.**
Every finding carries its disposition — nothing below is outstanding.

### 1. Counting rename sources widens an unbounded fold, and past 999 the registry stops being re-seedable

- **Status:** **Resolved, by the opposite fix to the one suggested.** This
  finding's own suggestion — bound the allocator to match the seed's 999 guard —
  was implemented, produced Finding 5, and was then reversed. Design Decision 3
  now aligns the *guard* upward instead: one shared digit-length value, with the
  seed's spec cap relaxed from a value check to that width. The un-re-seedable
  registry this finding identified is fixed at its actual cause — the two sides
  disagreeing — rather than by capping the side that was not wrong.
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

- **Status:** **Resolved** — after Finding 6, the spec and plan were amended from
  name-the-redirect to refuse-until-acknowledged. A crafted `group rename` can no
  longer cause a silent substitution: the request fails, naming the redirect, and
  proceeding requires an explicit `--follow-redirect`. See Finding 6 for the
  reasoning and the availability trade accepted alongside it.
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

- **Status:** **Resolved — the bound was removed rather than corrected.** This
  finding's own suggestion (derive exhaustion from corroborated ordinals) was
  written into the plan and **found not to work**: an attacker appends a well-formed
  `spec allocate dashboard/999 …` as easily as a rename, verified to drive the
  high-water to 999, so corroboration separates malformed logs from well-formed
  ones and never attacker records from legitimate ones. Two further candidates also
  failed — see plan Design Decision 3a for the full record. The accepted fix aligns
  the bootstrap's guard upward instead of capping allocation, leaving no reachable
  ceiling for a plausible ordinal and therefore no denial. The vector is not
  eliminated but is made self-identifying: a record claiming 999 is
  indistinguishable from real history, while one claiming fifteen nines is
  obviously crafted and safe to delete.
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

- **Status:** **Resolved by amendment** — the developer accepted refusal. The spec
  criterion now requires the request to be refused until acknowledged; Design
  Decision 5 implements it with `--follow-redirect`, Design Decision 7 documents
  the resulting failure modes, and the Interface Contract states that the returned
  group is authoritative and may differ from the one requested. Both halves of the
  suggestion landed: the structural refusal *and* the contract sentence, which
  still matters on the acknowledged path.
- **New consequence to track:** refusal introduces a second one-record denial
  vector alongside Finding 5 — a crafted `group rename` now blocks a group's
  allocation until a human acknowledges it, where before it silently redirected.
  Accepted deliberately (a refusal that names the redirect is itself detection;
  a silent redirect yields nothing), and recorded in the spec's Open Questions as
  an accepted trade. It does **not** relieve Finding 5: two independent one-record
  denial paths is the state unless Finding 5's corroboration fix also lands.
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

- **Finding 6 — closed by amending both artifacts.** The spec asserted that a
  redirect is never applied silently while the plan's mechanism delivered that to a
  human only, leaving a program able to honor the letter and still substitute one
  group for another. Rather than strengthen the plan alone, the criterion itself
  moved from *name the redirect* to *refuse until acknowledged* — so the spec now
  asserts a property the plan can preserve by construction. Both artifacts changed;
  no misalignment remains.
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
- **Finding 5 (Critical) — routed, and the suggested fix does not hold.** Writing
  it into the plan showed the conflict is between two spec criteria, not inside the
  plan: the gap guarantee demands the returned id exceed an attacker-controlled
  high-water while the ceiling criterion forbids exceeding a fixed bound, and a
  crafted ordinal *at* the ceiling makes both unsatisfiable. Deriving exhaustion
  from corroborated ordinals alone does not help, because the returned value still
  has to clear the uncorroborated high-water — and corroboration is defeated anyway
  by an attacker appending a well-formed `allocate` record. **Resolved by removing
  the ceiling instead:** the seed's arbitrary 999 guard is relaxed to the same
  digit-length value the fold uses, so allocation has no reachable ceiling and the
  registry stays rebuildable. Plan Design Decision 3a records all four candidates
  and why three failed; the `[NEEDS CLARIFICATION]` markers are cleared and tasks
  5–7 unblocked.
- **Finding 6 — landed, via the stronger route.** The developer chose
  refuse-unless-acknowledged and amended the renamed-away-group criterion to match,
  so the guarantee is structural rather than contractual. The contract sentence
  landed too — the returned group is authoritative and may differ — since it still
  governs the acknowledged path. Design Decision 7 enumerates the resulting
  terminal-vs-retryable failure modes for the spec-ID wiring to consume.
- **Finding 7 — landed.** Task 3 now requires a group-rename cycle fixture
  alongside the multi-hop one, and Design Decision 4 states the termination rule
  with the reason a passing test is the only evidence it was implemented.
- **Finding 8 — landed.** Design Decision 4 now specifies memoized lazy resolution
  and records eager closure as rejected, with the O(map)-per-record reason that
  made "one pass" misleading.

*No findings route to Issue this run.*

*No findings route to Issue — Findings 1–4 all land inside this spec's own scope,
and the adjacent seed-side magnitude cap is already tracked as issue #121.*
