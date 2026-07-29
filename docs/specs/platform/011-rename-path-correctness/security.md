---
spec: "docs/specs/platform/011-rename-path-correctness/spec.md"
reviewed_phases: [spec]
status: Needs Spec Review
date: "2026-07-29"
---

<!-- Budget: findings are actionable and specific. No vague "consider security" entries. -->

# Security Review: Rename-path correctness gates

## Summary

**Findings:** 0 Critical · 2 Notable · 2 Advisory

Reviewed `spec.md` under the requirements-gap lens (no `plan.md` yet). The spec
corrects a read path over a **push-writable** registry, so the whole review turns
on what a crafted-but-well-formed record can do once three previously-ignored
fields start being consulted. Both Notable findings are consequences the spec's
criteria leave implicit rather than defects in them; both were reproduced by
executing the allocator. LINDDUN is omitted — no PII, credentials, or session
data is read by any changed path.

## Coverage

- spec.md — reviewed 2026-07-29 (requirements-gap lens)

*No `plan.md` exists yet; the design-flaw lens has not run. Findings 3 and 4 are
recorded now so planning inherits them.*

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | The changed paths read ordinals, group tokens, and durable ids only. The registry's `<who>` provenance field (derived from `git config user.name` / `user.email`) and the human-readable title-derived slug are never consulted by resolution or the high-water fold. The disclosure surface those create is `platform/007` / `issue/010`'s, acknowledged there and unchanged here. |
| Credentials | No | No credential is read, stored, or transmitted; every changed function is a pure read over a local log. |
| Session data | No | None exists in this system. |
| Internal-only | Yes | Project-internal spec ordinals, issue ordinals, durable ids, group names, and registry records. |
| Public | No | The coordination branch is readable by anyone with repo read access — a `platform/007` property, unaffected by this spec. |

## Findings

### 1. Counting rename sources widens an unbounded fold, and past 999 the registry stops being re-seedable

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

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No identity assertion is consumed by any changed path; the registry's self-asserted `<who>` provenance is not read by resolution or the fold. |
| Tampering | Yes | Findings 1, 2, 3 — the registry is push-writable, and `platform/007`'s erosion guard detects truncation or rewrite but not a well-formed append. |
| Repudiation | N/A | Provenance is advisory by `platform/007`'s non-goal; this spec adds no audit or attribution claim. |
| Information Disclosure | No | No new output surface. Resolution and `peek` already print ids; no changed path reads the identity or slug fields. |
| Denial of Service | Yes | Findings 1 (ordinal inflation and the un-re-seedable threshold) and 4 (O(n²) chain walk). |
| Elevation of Privilege | N/A | An id carries no authority (`platform/007` non-goal), so no permission is derivable from a record this spec reads. |

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
*No `plan.md` exists yet; these carry to planning, where `/jim:plan`'s gate reads
this artifact.*

- **Finding 3:** keep the ordinal's numeric check and the durable id's boundary
  check as separate gates; fixture the split.
- **Finding 4:** resolve the group-rename chain once into a lookup so the fold
  stays a single pass.

*No findings route to Issue — Findings 1–4 all land inside this spec's own scope,
and the adjacent seed-side magnitude cap is already tracked as issue #121.*
