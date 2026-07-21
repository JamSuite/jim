---
spec: "spec.md"
reviewed_phases: [spec]
status: "Needs Plan Review"
date: "2026-07-21"
---

# Security Review: Partition split

## Summary

**Findings:** 0 Critical · 4 Notable · 3 Advisory (Finding 7 resolved by spec
amendment; Findings 1–6 held open for the plan phase)

Spec-phase review (no plan.md yet — plan lens deferred to the plan gate). The
spec inherits 043/046's closed injection surfaces by construction (structural
enumeration, capability-backed gatherer, scrubbed gate diffs, config-only mode
binding — ACs 10/15/18); the findings concentrate on the four surfaces split
genuinely *adds*: a cross-parent move primitive, machine-consumed ledger remap
values, an N-target change-set handoff, and the archive-wide rewrite expansion.
LINDDUN omitted (no PII / Credentials / Session data).

## Coverage

- spec.md — reviewed 2026-07-21 (requirements-gap lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | No | Operates on spec/blueprint/config/ledger files; no personal-data fields handled by the feature. |
| Credentials | No | The feature handles no credentials — but numbered spec bodies it rewrites and quotes *may* contain developer-pasted secrets; covered by AC 15 (scrubbed diffs) and AC 18 (scrub before persistence/presentation). |
| Session data | No | None. |
| Internal-only | Yes | Group identities, spec bodies, per-spec remap set, ledger `op=` events. |
| Public | Yes | The spec archive is committed; committed artifacts are effectively public. |

## Findings

### 1. The cross-parent move primitive must replace the sibling constraint with equivalent bounds

- **Severity:** Notable
- **Description:** `rename-tracked`'s sibling constraint (`dirname(old) ==
  dirname(new)`, slug basename — jimledger.sh:279-284) is a security guard: the
  primitive can rename, never relocate. Split requires exactly what it refuses —
  `docs/specs/cart/006-x → docs/specs/checkout/001-x` — so a new or relaxed
  primitive is unavoidable (research Rec 3). Dropped without replacement bounds,
  it becomes a general tracked-path relocator: a corrupted change-set row could
  direct `git mv` at paths far outside the operation (skills/, agents/, .github/).
- **Suggestion:** Give the new verb a bound set at least as tight as what it
  replaces: both endpoints `valid-relpath` + realpath-under-worktree-top; source
  must be an existing tracked `NNN-slug` spec dir under `<specs>/<old>/`; target
  parent must be `<specs>/<child>` for a child in the operation's approved
  target set; target basename `NNN-slug`-shaped; no-clobber. Negative tests for
  each refusal (the `tests/jimledger.sh:1163-1225` guard-case template).
- **Route:** Plan
- **Relates to:** AC 7, AC 9

### 2. The vacated-id floor makes ledger values machine-consumed for the first time — parse fail-closed

- **Severity:** Notable
- **Description:** Every existing ledger consumer treats event values as display
  data or whitelisted counters; nothing feeds deterministic behavior from them.
  If AC 11's floor derives from the `op=split`/`op=rename` remap events (the
  natural home — spec Insight 2 flags this for security examination), the ledger
  becomes an input to `next-id`: a hand-edited or merge-tampered ledger line
  (committed content is attacker-influenceable per ARCHITECTURE's trust
  boundary) could inject a huge floor (`moved=cart/998:x/001` → next-id 999,
  then `%03d` overflow to 4-digit ids and downstream shape-check breakage) or a
  malformed element into a deterministic path.
- **Suggestion:** Whitelist-parse per the `identity-check` precedent
  (jimpartition.sh:1348-1364): event-type gate, per-element shape gate (group
  slug + 3-digit id), invalid elements ignored — an unparseable remap element
  contributes no floor effect, never an error that blocks minting. The floor
  only ever *raises* the dir-derived max (monotonic merge). Name the id-space
  policy at the 999 boundary (refuse-and-report beats silent 4-digit ids).
- **Route:** Plan
- **Relates to:** AC 11; spec Insight 2

### 3. The `--split` change-set must be re-validated against the approved target set

- **Severity:** Notable
- **Description:** 043's `--rename` arm re-validates each handed-over change-set
  row (`valid-relpath` + slug, out-of-scope targets refused) against one
  `(old, new)` pair. Split's change-set is per-row-targeted across N children
  and travels between skills as a temp file; without per-row target validation,
  a corrupted or stale row could direct identity edits at a group outside the
  approved operation (or a path outside the operation's artifact scope).
- **Suggestion:** The `--split` arm refuses any row whose target is not in the
  gate-approved child set and any path outside the operation's scope — the 043
  refusal semantics generalized from one target to the approved set. Refusals
  are location-only and fail the arm before any edit.
- **Route:** Plan
- **Relates to:** AC 13

### 4. Archive-wide re-point amplifies the rewrite over-match blast radius

- **Severity:** Notable
- **Description:** 046 confined `rewrite-identity` to the moved set, and its
  known over-match edges (dotted `cart.json`-style tokens, `group/NNN`-shaped
  values outside `group:` — 046 review Finding 1) were low-risk *because* the
  edit surface was small and every edit gate-diffed. AC 8 extends identity
  edits to unmoved specs across the whole archive **and to the non-spec
  reference classes (issue `origin:` frontmatter and bodies, brainstorm and
  debug documents, moved dirs' sibling artifacts — the 2026-07-21 AC 8
  amendment)**, and the number-remap arm (research Rec 2) adds `NNN`-half
  rewriting. The same over-match now has
  archive-wide reach, and gate-diff review fatigue scales with edit count — the
  existing open issues #77 (narrow the over-match) and #78 (guard/negative-branch
  test gaps) graduate from low-priority to load-bearing preconditions.
- **Suggestion:** In the plan: (a) key the ref-rewrite arm on the remap set
  itself — only typed refs whose `NNN` half appears in the approved remap are
  re-pointed (the remap is the whitelist; a ref to an unmoved spec is never
  touched); (b) batch invocations per target child so the guards-before-any-edit
  property holds across the widened surface; (c) schedule #77/#78's narrowing
  and negative tests with or before this build.
- **Route:** Plan
- **Relates to:** AC 8, AC 19; issues #77, #78

### 5. Bound and charset-design the remap event value

- **Severity:** Advisory
- **Description:** `cmd_event` appends the k=v tail verbatim — no size or
  charset gate (jimledger.sh:376-379) — and the remap set scales with moved-spec
  count. The reconcile extractors ignore `op=split` lines (whitelist drops
  unknown keys — safe), but the new consumers this spec creates (the floor, the
  `identity-check` split arm) will parse it, and remap elements carry `/` and
  separator-sensitive characters (`;` joins pairs, TAB delimits fields).
- **Suggestion:** Design the remap value's element charset to exclude `;`/TAB,
  cap the value (element count or bytes — the 044 `valid_sluglist` ≤256-byte
  precedent) with an explicit overflow policy (spill to additional keys or
  events rather than truncate silently), and have every consumer charset-gate
  elements on read.
- **Route:** Plan
- **Relates to:** AC 12; spec Insight 5

### 6. Name the gatherer's third dispatch role explicitly

- **Severity:** Advisory
- **Description:** `agents/gatherer.md` names two dispatch roles (partition
  proposal evidence; rename classification residue with freeze-on-doubt).
  Split adds a third: per-child assignment evidence and spanning-case
  disambiguation. Leaving the role implicit invites contract drift — the
  agent's untrusted-content and fail-closed rules should bind the new dispatch
  shape as explicitly as they bind the first two.
- **Suggestion:** Extend the gatherer contract with the split dispatch role:
  inputs (child slug + proposed territory + substrate slice), returned evidence
  shape, and the rule that returned assignment suggestions are proposal
  evidence only — the gate binds, never the agent (AC 18's boundary restated at
  the contract).
- **Route:** Plan
- **Relates to:** AC 3, AC 18

### 7. The close event should record the run's outcome — RESOLVED by spec amendment

- **Severity:** Advisory
- **Description:** Rename's close event carries
  `outcome=<renamed|blocked|declined>` (043), so the durable record
  distinguishes a completed rename from a declined gate. AC 12 enumerates the
  `op=split` event's contents (source, targets, mode, frozen count, remap) but
  omits an outcome disposition — a declined or blocked split would be
  indistinguishable from an interrupted one in the ledger.
- **Suggestion:** Add `outcome=<split|blocked|declined>` (bounded enum, 043
  parity) to AC 12's durable-record enumeration.
- **Route:** Spec
- **Relates to:** AC 12

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | N/A | No authentication or external identity surface; a local, human-gated doc operation (043/046 precedent). |
| Tampering | Yes | Findings 1, 2, 3, 4, 5 — the move primitive's bounds, ledger-derived floor, change-set re-validation, over-match amplification, event-value hygiene. |
| Repudiation | Yes | Finding 7 (outcome disposition); otherwise strong — the `op=split` event with mode, frozen count, and the per-spec remap is a complete audit bridge. |
| Information Disclosure | No | No issues found — scrubbed gate diffs (AC 15), scrub-before-persistence/presentation (AC 18), and the location-only verb-output discipline (046 Finding 6, shipped) cover the new surfaces, including issue bodies carrying per-side evidence (AC 5/6). |
| Denial of Service | No | No issues found — gatherer fan-out rides the existing `verify_fanout_cap` batching; scans are linear; Finding 5's size cap is record hygiene, not availability. |
| Elevation of Privilege | No | No issues found — no new tool grants: new verbs ride the partition skill's existing script grants, `--split` is an internal blueprint arm, the gatherer stays `Read`/`Glob`/`Grep`. (Pre-existing wildcard-grant breadth is tracked separately as issue #52.) |

## Routing Recommendations

### Spec amendments
- Finding 7: **applied 2026-07-21** — AC 12 now enumerates the
  `outcome=<split|blocked|declined>` disposition (043 parity).

### Plan amendments (held — consume at /jim:plan)
- Finding 1: cross-parent move verb with the full replacement bound set + negative tests.
- Finding 2: fail-closed whitelisted remap parse; monotonic floor; 999-boundary policy.
- Finding 3: `--split` change-set re-validation against the approved target set.
- Finding 4: remap-keyed ref rewriting; per-child batching; #77/#78 scheduled with the build.
- Finding 5: remap value charset/cap/overflow policy; consumers charset-gate on read.
- Finding 6: gatherer contract names the split dispatch role.
