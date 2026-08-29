---
spec: "docs/specs/issue/013-recorded-identity-schemes/spec.md"
reviewed_phases: [spec, plan]
status: "Needs Plan Review"
date: "2026-08-23"
---

# Security Review: Recorded identity schemes

## Summary

**Findings:** 1 Critical · 10 Notable · 5 Advisory

Both lenses now applied. The spec-phase pass found no Critical: its theme was
**integrity of attribution** — a reversible, display-time alias mapping made
permanent in tracked files through inputs no gate constrained. The plan-phase
pass adds six findings including the review's **first Critical**: the plan hands
an unvalidated, attacker-settable value to `git` as an argument, and the
identity character set admits values `git` reads as options. Two of the six are
spec↔plan misalignments. **Elevation of Privilege is no longer N/A** — the
spec-phase pass justified that marking on the grounds that no capability derives
from a recorded identity, which the plan's command construction overturns.

## Coverage

- spec.md — reviewed 2026-08-23 (requirements-gap lens)
- plan.md — reviewed 2026-08-23 (design-flaw lens)

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes | Email addresses, forge account handles, organization account names — recorded in `filed-by` and `claimed-by` on every issue |
| Credentials | No | No password, token, key or secret is read, stored or compared |
| Session data | No | No session state exists in jim |
| Internal-only | Yes | The issue collection and its `INDEX.md`; the new configuration keys |
| Public | Yes | `ROADMAP.md` commits to publishing this repository, so recorded identities become public content |

## Findings

### 1. A repo-writable alias mapping becomes a permanent rewrite of attribution

- **Severity:** Notable
- **Description:** git's alias mapping is a *display-time* transform — `git log`
  re-reads it on every invocation, so a wrong or malicious mapping is corrected
  by fixing the file. This spec resolves identities through that mapping and then
  **writes the result into tracked issue files**. Anyone with commit access can
  add a line mapping another contributor's address onto their own, run the
  conversion or a re-normalization, and permanently reattribute that person's
  filed issues across the whole collection. Deleting the mapping afterwards does
  not undo it: the mapped values are now the stored values, and nothing records
  that a mapping was ever applied. This is a genuine escalation over git's own
  behavior, not a restatement of it.
- **Suggestion:** State in Out of Scope that recorded attribution inherits the
  trust model of the project's alias mapping — repository write access — and
  that the persisted result is **not** reversible by removing the mapping. Add an
  acceptance criterion requiring the preview of any operation that resolves
  through a mapping to name that it did so, so an operator can see the transform
  before approving it rather than after.
- **Route:** Spec
- **Relates to:** § Resolving one person's several addresses

### 2. Recorded attribution is not a function of the repository

- **Severity:** Notable
- **Description:** Identity resolution reads whatever alias mapping exists on the
  machine running the operation. Two maintainers running the same conversion over
  the same collection can therefore write **different** `filed-by` values, and
  neither result is recoverable from the repository alone. This is not
  hypothetical for this project: its mapping file is deliberately untracked, so
  the mapping that will stamp several hundred files exists on exactly one machine
  and in no commit. A collection whose attribution depends on unversioned local
  state cannot be audited or reproduced.
- **Suggestion:** Add an acceptance criterion that any preview which resolves
  identities reports whether a mapping was found and how many records it altered,
  so a run that silently differs from another operator's is visible before apply.
  Separately, state whether a project is expected to track its mapping — the spec
  currently takes no position, and the two answers have very different audit
  properties.
- **Route:** Spec
- **Relates to:** § Attribution of the existing collection

### 3. The domain setting is a new untrusted input with no stated validation

- **Severity:** Notable
- **Description:** The spec constrains `identity_domain` only to naming "exactly
  one domain". Nothing states what a domain may contain. Depending on how
  membership is tested, a value carrying pattern metacharacters — or a bare
  wildcard — could match every address and extract local parts from all of them,
  including relay addresses the ladder is supposed to handle by their own rule.
  The result is not a crash but silent over-extraction: identities recorded in a
  form nobody selected. This is the same class as this group's earlier
  blocklist-versus-allowlist finding, applied to a key that did not exist then.
- **Suggestion:** Add an acceptance criterion requiring the configured domain to
  clear a positively enumerated character set before it is used, refusing
  anything outside it exactly as an unrecordable identity is refused. Reuse the
  existing identity charset discipline rather than defining a second rule that
  can drift from it.
- **Route:** Spec
- **Relates to:** § Organization-local accounts

### 4. The ambiguity refusal has no stated scope, and the wrong scope is a capture denial-of-service

- **Severity:** Notable
- **Description:** The spec says that when two addresses would record as the same
  identity, "the operation names both and records nothing" — without saying which
  operations are guarded. Read as covering every write, one colliding pair
  anywhere in the collection blocks **all** filing and every transition until a
  human resolves it. Under the organization-local form that state is reachable
  without malice — two contributors whose accounts differ only outside the
  extracted part — and reachable *deliberately* by any contributor who configures
  a colliding address, since nothing verifies what someone puts in `user.email`.
  A refusal that protects a bulk rewrite becomes a self-inflicted outage when it
  runs on the capture path.
- **Suggestion:** Scope the check explicitly. On the bulk operations, which build
  a whole-collection plan before writing, compare across the plan and refuse the
  run. On the single-record paths, refuse only the record being written, against
  the identity being written — never against the collection at large.
- **Route:** Spec
- **Relates to:** § Refusing an ambiguous result

### 5. Extraction presents an unverified value in a form that reads as authenticated

- **Severity:** Notable
- **Description:** git does not verify `user.email`; any contributor can set any
  value. Recording `alice@company.com` is visibly a self-asserted address, and a
  reader treats it as such. Recording **`alice`** reads like an account name
  issued by an identity provider — and under the organization-local form it is
  textually indistinguishable from one. The spec therefore strengthens the
  *appearance* of authority without changing the guarantee behind it. This group
  already documents that the holder field is a coordination signal rather than a
  provenance guarantee; extraction extends that caveat to the filer and makes it
  materially easier to misread.
- **Suggestion:** Carry the existing tamper-evidence exclusion forward into this
  spec's Out of Scope explicitly, naming extraction as the reason it matters more
  here than it did before: a recorded identity is what a contributor configured,
  not what any system verified.
- **Route:** Spec
- **Relates to:** § Forge relay accounts, § Organization-local accounts

### 6. The architecture document asserts a security property this spec removes

- **Severity:** Notable
- **Description:** `ARCHITECTURE.md` § Security Considerations → Recorded
  identity states that the value "is stored as version control supplies it — not
  normalized, hashed, or mapped", and attaches a **security rationale** to that
  choice: the collection is published content and the commit history already
  carries the same addresses. This spec reverses the behavior while conceding the
  rationale (privacy is explicitly out of scope). The risk is not the reversal —
  it is that the architecture refresh which runs at build completion may update
  the *mechanism* sentence while leaving the *rationale* sentence standing, so
  the document would continue asserting a property the code no longer has. A
  later security review reading only that paragraph would conclude identities are
  stored verbatim and reason from a false premise, exactly as this review would
  have if the paragraph had not been re-read.
- **Suggestion:** Name the superseded architectural statement in the spec — as an
  Out of Scope entry or a Handoff note — so the refresh replaces the whole
  paragraph rather than patching it. The replacement should say what is now true:
  the value is normalized under a project-selected form, resolved through the
  project's alias mapping, and rewritable after the fact.
- **Route:** Spec
- **Relates to:** § Problem Statement, § Resolving one person's several addresses

### 7. Lower-casing merges mailboxes the standard treats as distinct — and disables the check that would catch it

- **Severity:** Advisory
- **Description:** RFC 5321 §2.4 states the local-part of a mailbox "MUST BE
  treated as case sensitive". The spec both lower-cases every recorded identity
  and declares that two addresses differing only in case are "one address, not a
  collision" — so the single mechanism that would surface a genuine merge is
  switched off for precisely this input. Against every major mail provider this
  is safe, since all of them fold case. It is *not* guaranteed against a
  self-hosted organization mail server, which is exactly the deployment the
  organization-local form is designed for.
- **Suggestion:** Record the accepted risk in Out of Scope with the RFC citation,
  stating that jim treats case-folded local parts as one identity by choice and
  that a mail system distinguishing them is unsupported.
- **Route:** Spec
- **Relates to:** § Choosing the form, § Refusing an ambiguous result

### 8. The mismatch surface must not publish identity values

- **Severity:** Advisory
- **Description:** The spec requires a configured-form mismatch to be surfaced
  without running a rewrite. The natural home for that signal is the collection's
  existing integrity-warning channel, whose output lands in the generated index —
  a tracked file that will be published. A warning naming the mismatched *value*
  would therefore write contributor addresses into a file that currently derives
  everything it shows from the records it summarizes.
- **Suggestion:** Add an acceptance criterion that the mismatch surface names the
  affected records and the count, never the identity value itself. The value is
  already available to anyone who opens a named record.
- **Route:** Spec
- **Relates to:** § Changing a recorded identity

### 9. The collision refusal moves identities into a different channel

- **Severity:** Advisory
- **Description:** The spec deliberately relaxes the never-echo rule so an
  ambiguity refusal can name both colliding addresses, reasoning that both are
  already stored in the collection. That reasoning is sound about *content* and
  incomplete about *channel*: refusals surface on stderr, which in an automated
  run lands in build output that frequently has a wider audience than the
  repository. Two contributor addresses then appear somewhere the collection
  itself is not readable.
- **Suggestion:** Name the colliding **records** and the single normalized value
  they both produce, rather than both source addresses. The refusal stays fully
  actionable — the source addresses are one file-open away via the named
  records — without copying personal data into a log stream.
- **Route:** Spec
- **Relates to:** § Refusing an ambiguous result

### 10. The rewrite guards are anti-accident, not anti-adversary

- **Severity:** Advisory
- **Description:** The preview, the explicit apply gate and the drift guard are
  real protections against a stale plan or a mistaken invocation. None of them
  constrains an operator who *intends* to misattribute: the remap operation is by
  design a primitive that rewrites who did what, across an entire collection, in
  one command. There is nothing wrong with shipping it — the capability is the
  feature — but the guards should not be read as integrity controls, because a
  future reader weighing whether attribution can be trusted will find them and
  reasonably conclude that it can.
- **Suggestion:** State in Out of Scope that the rewrite guards protect against
  operator error and stale previews, not against a hostile operator, and that
  attribution integrity rests on repository write access alone.
- **Route:** Spec
- **Relates to:** § Changing a recorded identity

### Plan-phase findings (2026-08-23)

### 11. An attacker-settable value is passed to `git` where it is read as an option

- **Severity:** Critical
- **Description:** Design Decision 2 orders the pipeline length-gate → alias
  mapping → charset gate, so the raw configured value reaches
  `git check-mailmap` as an argument **before** validation. The hyphen is a
  member of the accepted identity character set, so a value beginning with one
  is not merely unvalidated at that point — it would still be accepted after
  validation. Verified against the installed git in a scratch repository:
  `git check-mailmap "--help"` prints the manual page, and
  `git check-mailmap "-x"` returns `error: unknown switch 'x'`. Confirmed
  independently that `identity.sh validate` **accepts** `--help`, `-x` and
  `--stdin` today. The command's option surface includes `--stdin`, which
  changes where it reads input from, so the consequence is not bounded to a
  noisy stdout. Reordering the pipeline does not fix this; the value is
  option-shaped either way.
- **Suggestion:** Pass the value after an end-of-options separator —
  `git check-mailmap -- "<value>"`. Verified in the same scratch repository:
  `git check-mailmap -- "-x"` returns `<-x>` and `git check-mailmap -- "--help"`
  returns `<--help>`, both treated as data. Add a task and a regression case
  covering a leading-hyphen identity, since the charset will keep admitting one.
- **Route:** Plan
- **Relates to:** Design Decision 2 (pipeline order), Task 7

### 12. The new integrity warning does not route through the existing sanitizer

- **Severity:** Notable
- **Description:** Task 17 adds a warning to `index.sh` that names issue slugs,
  and `index.sh` already sanitizes every value it interpolates into generated
  rows for exactly this reason. The task specifies the content of the warning —
  records, counts, no identity values — but never says the slugs pass through
  that sanitizer. This is the same finding this group recorded during the
  previous spec, where it was Advisory; a second instance in the same file, on a
  path that writes published content, is not still Advisory.
- **Suggestion:** State in Task 17 that the warning composes through the existing
  row sanitizer, and add a case with a slug containing sanitizer-relevant
  characters.
- **Route:** Plan
- **Relates to:** Task 17

### 13. A mistyped scheme degrades silently where the spec chose to refuse

- **Severity:** Notable
- **Description:** The plan's Interface Contract states that an unrecognized
  `identity_scheme` "falls back to the default and notes the fallback on
  stderr". The spec settled the parallel question in the opposite direction: an
  organization-local form with no domain **refuses every operation**, explicitly
  because "this project already made a degraded read carry a non-zero status
  rather than trust a message to be noticed". Under the plan as written, a
  project that typed `locale` instead of `local` records every identity under
  `github` — a form it did not choose — with only a stderr note that the same
  reasoning already rejected as insufficient.
- **Suggestion:** Refuse an unrecognized scheme, matching the domain case. If the
  fallback is kept deliberately, say why this input differs from the one the spec
  refused, so the asymmetry is a decision rather than an inconsistency.
- **Route:** Plan
- **Relates to:** Interface Contracts, spec § Organization-local accounts

### 14. The mismatch warning's behavior on an unresolvable scheme is unspecified

- **Severity:** Notable
- **Description:** Task 17 has `index.sh` shell out to `identity.sh normalize`,
  which now reads configuration. `jimconf.sh` deliberately **refuses** rather
  than returning a default when a run starts below the project root. The plan
  does not say what the warning does with that refusal. If the failure is
  flattened into "no scheme configured" and the default is assumed, the warning
  is computed under a form the project may not have selected, and the result is
  written into generated content the project publishes.
- **Suggestion:** Specify that an unresolvable scheme omits the mismatch warning
  and says so, rather than computing it under an assumed form — the same
  distinction `jimconf.sh` already draws between an unset key and a failed
  resolution.
- **Route:** Plan
- **Relates to:** Task 17, Design Decision 6

### 15. The alias mapping is not necessarily the file the plan assumes

- **Severity:** Advisory
- **Description:** The plan and spec both speak of "the project's alias mapping"
  as though it were one file at a known path. `git check-mailmap` honors repo
  configuration that redirects the mapping to an arbitrary path or blob.
  Verified: with `mailmap.file` set to an unrelated file, an address that
  resolves to itself by default instead resolves to whatever that file names.
  The consequence is bounded — the mapped result still passes the charset gate
  before it is recorded — but the trust statement in the spec's Out of Scope
  ("anyone who can commit can change it") understates the surface: anyone who can
  set repository configuration can also redirect where it is read from.
- **Suggestion:** Widen the Out of Scope wording from the mapping *file* to the
  mapping *as version control resolves it*, so the stated trust boundary matches
  the mechanism.
- **Route:** Plan
- **Relates to:** Design Decision 2, spec § Out of Scope

### 16. The spec's refusal mockup contradicts its own amended criterion

- **Severity:** Notable
- **Description:** The spec's ambiguity criterion was amended during the
  spec-phase routing to require that a refusal name "the colliding records and
  the single value they would both produce, rather than the two source
  addresses". The § UI Mockup was not amended with it, and still shows a refusal
  printing both source addresses. A coder implementing the mockup produces
  exactly the behavior Finding 9 was raised to prevent, and the mockup is the
  more concrete of the two.
- **Suggestion:** Update the spec's refusal mockup to name records and the single
  produced value. This is a spec edit, not a plan one — the plan already follows
  the criterion.
- **Route:** Spec
- **Relates to:** spec § UI Mockup, spec § Refusing an ambiguous result

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | Yes | Findings 1, 5 — an unverified value recorded in a form that reads as verified; a mapping that can claim another contributor's address |
| Tampering | Yes | Findings 1, 10, 15 — attribution rewritable across the collection, irreversibly and without record; the mapping's source is itself redirectable |
| Repudiation | Yes | Findings 5, 6 — nothing binds a recorded identity to the person named, and the architecture document would still claim otherwise |
| Information Disclosure | Yes | Findings 8, 9, 12 — identity values reaching a published index or a log channel; unsanitized slugs reaching generated content |
| Denial of Service | Yes | Finding 4 — a colliding identity blocking the capture path |
| Elevation of Privilege | Yes | Finding 11. **Reclassified from N/A.** The spec-phase marking rested on no capability deriving from a recorded identity, which stays true — but the plan gives that value a second role as an argument in a constructed command, where it crosses from data into control |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | Yes | Finding 1 — deliberately linking one person's addresses is the feature; the threat is a mapping that links them *wrongly*, permanently |
| Identifying | No | Extraction never increases identifiability. A relay address already contains the handle, and extraction discards the numeric id, so the pseudonymous form the forge issues is preserved rather than resolved |
| Non-repudiation | No | The privacy threat is inverted here: attribution is trivially deniable because nothing verifies it. Recorded as a STRIDE Repudiation concern (Finding 5) rather than a privacy one |
| Detecting | N/A | Nothing infers a subject's presence indirectly; a contributor is either recorded on a record or is not, and reading either requires repository access |
| Data Disclosure | Yes | Findings 8, 9. That contributor addresses become public content at all is this group's pre-existing finding, unchanged by this spec and not restated here |
| Unawareness & Unintervenability | No — improved | This group previously recorded that a contributor had no supported way to change how they appear. This spec creates exactly that path. Residual: it defines the mechanism without stating who may invoke it (Finding 10) |
| Non-compliance | No | No regulatory claim is made or implied, and the spec explicitly disclaims delivering privacy |

## Artifact Misalignment

- **Finding 13 — a mistyped scheme degrades where the parallel case refuses.**
  Spec states that a form which cannot be applied refuses every identity-recording
  operation, and records the reasoning that a stderr message is too weak a signal
  to rely on. Plan states that an unrecognized `identity_scheme` falls back to the
  default and notes it on stderr. Two inputs of the same kind, opposite handling,
  and the plan takes the option the spec's own reasoning rejected. Route: Plan.
- **Finding 16 — the spec's mockup contradicts the spec's criterion.** Spec's
  criterion requires an ambiguity refusal to name the colliding records and the
  single produced value; spec's § UI Mockup still prints both source addresses.
  The plan follows the criterion, so the artifact at fault is the spec, and the
  mockup is the version a coder is more likely to copy. Route: Spec.

## Routing Recommendations

**The ten spec-phase findings were routed into `spec.md` on 2026-08-23, before
any plan existed.** The spec grew from 29 to 33 acceptance criteria, gained five
Out of Scope entries and one Handoff insight; that applied state is below.
`status:` is now `Needs Plan Review` — the plan-phase pass added a Critical, and
`status:` records what a review found rather than whether it was acted on.

### Spec amendments

- **Finding 1 — applied.** Out of Scope: *Attribution integrity beyond
  repository write access*, stating that the persisted result is not reversible
  by fixing the mapping afterwards. Paired with the disclosure AC below.
- **Finding 2 — applied.** New AC under § Resolving one person's several
  addresses: a preview discloses that it resolved through a mapping, whether one
  was found, and how many records it altered. Out of Scope: *Deciding whether a
  project tracks its alias mapping* — jim takes no position, and the
  reproducibility consequence is stated rather than left to be discovered.
- **Finding 3 — applied.** New AC under § Organization-local accounts, carrying
  an external-constraint citation to the charset discipline already documented in
  `ARCHITECTURE.md`.
- **Finding 4 — applied.** § Refusing an ambiguous result split into two
  criteria: whole-run refusal for operations that plan across the collection,
  single-record judgment on the write paths, so a collision can never block
  capture.
- **Finding 5 — applied.** Out of Scope: *Verifying that a recorded identity
  belongs to the person named*, naming extraction as why the caveat matters more
  than it did before.
- **Finding 6 — applied.** Handoff Insight 8 names the superseded
  `ARCHITECTURE.md` paragraph and states what replaces it, so the
  build-completion refresh replaces the security rationale rather than patching
  the mechanism sentence around it.
- **Finding 7 — applied.** Out of Scope: *Mail systems that distinguish local
  parts by case*, with the RFC 5321 §2.4 citation on both sides of the question.
- **Finding 8 — applied.** The mismatch criterion now requires naming the
  affected records and their count, never the identity values.
- **Finding 9 — applied.** New criterion: an ambiguity refusal names the
  colliding records and the single value they produce, not the two source
  addresses.
- **Finding 10 — applied.** Out of Scope: *Guarding the rewrites against a
  hostile operator*, so the preview and drift guard are not mistaken for
  integrity controls.

### Plan amendments

**All five were applied on 2026-08-23.**

- **Finding 11 (Critical) — applied.** Design Decision 2 gains the end-of-options
  separator with the verified evidence and a fourth rejected alternative
  (narrowing the charset). Task 7 carries the separator; **new Task 7a** pins
  option-shaped identities (`--help`, `-x`, `--stdin`) as a permanent regression
  property, since the charset admits leading hyphens by design.
- **Finding 12 — applied.** Task 17 and Decision 6 both state that slugs compose
  through `index.sh`'s existing row sanitizer.
- **Finding 13 — applied.** The Interface Contract and Task 2 now **refuse** an
  unrecognized scheme rather than falling back, matching the domain case. An
  absent key still takes the default; only an unrecognized *value* refuses.
- **Finding 14 — applied.** Task 17 and Decision 6 specify that a scheme which
  cannot be resolved omits the warning and says so, preserving `jimconf.sh`'s
  distinction between an unset key and a failed read.
- **Finding 15 — applied**, to the spec rather than the plan. The remedy was
  wording in the spec's Out of Scope, so the route recorded above was imprecise:
  the entry now describes the mapping *as version control resolves it*.

### Spec amendments (plan-phase pass)

- **Finding 16 — applied.** The § UI Mockup refusal now names two colliding
  records and the single produced value, and points the reader at the records
  for the addresses.

### Candidate issues

None. Every finding is a gap in this spec's or plan's own requirements;
nothing surfaced as an out-of-scope follow-on.
