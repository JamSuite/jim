---
title: "Recorded identity schemes"
type: feature
group: "issue"
id: "013"
status: approved
---

# 013 Recorded identity schemes

## Overview

Let a project choose the form a contributor identity takes when it is recorded,
resolve one person's several addresses to a single form, and provide a supported
way to change a recorded identity after the fact.

## Problem Statement

An issue records who filed it and who holds it, taking whatever address version
control supplies. That is a reasonable default and a poor permanent answer,
because the address a contributor commits under is neither stable nor singular.

One person routinely commits under several addresses — a work address on one
machine, a personal one on another, and a forge's private-relay address whenever
they commit through the web interface. Each is a different string, so every
by-person view splits one contributor into several. A forge relay address also
carries a numeric account id alongside the account name, so recorded verbatim it
reads as machine noise in a file whose whole purpose is to be read by people.

Two forces turn this from a cosmetic concern into a decision that has to be made
before the collection is populated rather than after:

- **The collection is attributed once.** Recovering a filer for every existing
  issue reads each file's creating commit — a one-shot operation over the whole
  collection. Whatever form it writes is the form several hundred files carry.
- **Nothing can change it afterward.** The recovery skips any issue already
  carrying the fields, so re-running it is a no-op, and no other operation
  rewrites a recorded identity. The form is effectively write-once, and the
  holder field is worse than write-once: a claim leaves no trace in the file's
  creation history, so it cannot be recovered even in principle.

This project's own history illustrates the shape: four distinct addresses across
two people, one of whom appears under three different display names.

**This is not a privacy feature, and the spec should not be read as one.**
Rewriting identities inside issue files changes nothing about the commit history
sitting beside them, which retains every address a contributor has ever used and
is larger than the issue collection by orders of magnitude. Genuine redaction
means rewriting version-control history, which is outside jim's remit. A
contributor who wants non-routable attribution configures a forge relay address,
and this spec's contribution there is only that jim records it legibly. The goal
is consistency and legibility — one contributor reading as one identity.

## User Stories

- As a developer, I can choose the form a recorded identity takes, so the
  collection reads as account names rather than raw relay addresses.
- As a developer in an organization, I can have internal addresses recorded as
  account names, so by-person views match how the organization refers to people.
- As a maintainer, I can have one contributor's several addresses resolve to a
  single recorded identity, so by-person views do not split them.
- As a maintainer, I can change a recorded identity across the whole collection
  when someone's address or account changes, so past attribution stays correct.
- As a maintainer, I can re-apply the project's current form to a collection
  recorded under a previous one, so choosing a form is not a decision I make
  once and can never revisit.
- As a maintainer, I am told when the form I have chosen would record two
  different people as the same identity, so the collection is never quietly
  wrong about who did what.
- As a maintainer, I am told when the collection no longer matches the form the
  project has configured, so I discover that drift rather than stumble into it.

## Acceptance Criteria

**Choosing the form**

- [ ] A project selects one of three forms for recorded identity. The selection
      belongs to the project, not to each contributor, so one collection cannot
      hold identities recorded under different rules.
- [ ] The forms are ordered: each records everything the form below it records,
      plus one further extraction.
- [ ] One form applies no extraction at all, recording the whole address rather
      than a part of it.
- [ ] By default a project extracts forge relay account names and records every
      other address unchanged.
- [ ] Every recorded identity is lower case, under every form — including the
      form that extracts nothing, so case variance in a contributor's address
      never splits them either.

**Forge relay accounts**

- [ ] An address issued by a forge's private-relay service is recorded as the
      account name it carries, not as the full address.
- [ ] Every relay form the forge issues records as the same account name — the
      form carrying a numeric account id ahead of the name, and the older form
      carrying the name alone. A contributor whose account predates the
      id-bearing form is not recorded differently from anyone else.
- [ ] Ordinary mail that merely resembles a relay address — an address carrying
      a tag on its mailbox, for instance — is recorded unchanged. Only addresses
      actually issued by the relay service are extracted.
- [ ] A relay address that yields no account name is recorded unchanged, never
      as an empty identity.

**Organization-local accounts**

- [ ] Under the organization-local form, an address inside the project's
      configured domain is recorded as the account part preceding that domain.
- [ ] An address outside the configured domain is recorded as the form below
      would record it, so a contributor who also commits through a forge's web
      interface does not split into two identities.
- [ ] A tag appended to a mailbox is not part of the recorded account, so one
      mailbox is one identity.
- [ ] Domain comparison ignores case, so an address is inside the configured
      domain regardless of how it was typed.
- [ ] The domain setting names exactly one domain. A value naming several is
      refused rather than partially honored.
- [ ] The configured domain clears a positively enumerated character set before
      it is used for anything, and a value outside that set is refused exactly
      as an unrecordable identity is — so a setting carrying pattern characters
      can never widen what the form extracts. *(External constraint, sourced to
      the positively-enumerated-charset discipline documented in
      `ARCHITECTURE.md` § Security Considerations → Recorded identity.)*
- [ ] Selecting the organization-local form without configuring a domain
      refuses every operation that would record an identity, and the refusal
      names the setting to supply.

**Resolving one person's several addresses**

- [ ] An address the project's version control maps to another is recorded as
      the form of the address it maps to, not the form of the address that was
      written. A mapping therefore reaches every form, including those that
      extract.
- [ ] Alias resolution applies everywhere an identity is recorded — when an
      issue is filed, when it is claimed, and when a filer is recovered from
      history — so no two write paths disagree about who someone is.
- [ ] An address the mapping does not name is carried through unchanged.
- [ ] Any preview that resolves identities through the alias mapping discloses
      that it did so, whether a mapping was found at all, and how many records
      it altered — so an operator sees the transform before approving it rather
      than inferring it from the result afterwards.

**Refusing an ambiguous result**

- [ ] An operation that plans a change across the whole collection refuses the
      entire run when two distinct source addresses within it would record as
      the same identity.
- [ ] An operation that records a single identity is judged only against the
      identity it is writing, so one colliding pair somewhere in the collection
      can never block capture or a transition.
- [ ] Two source addresses differing only in case are one address, not a
      collision — case is normalized before anything is compared, so a
      contributor is never refused for having typed their own address two ways.
- [ ] A refusal caused by a value that cannot be recorded names neither the
      value nor any issue content.
- [ ] An ambiguity refusal names the colliding records and the single value they
      would both produce, rather than the two source addresses. It stays
      actionable, because each named record carries its own address — without
      copying contributor addresses into a channel whose audience may be wider
      than the collection's.

**Changing a recorded identity**

- [ ] An operator can replace one recorded identity with another across the
      whole collection, supplying the old and new values explicitly.
- [ ] The replacement covers every field that records an identity, including the
      holder — which no derivation can recover, and which is therefore the
      reason an explicit mapping is required rather than a re-derivation.
- [ ] An operator can re-apply the project's current form to identities recorded
      under a previous one, without supplying any mapping.
- [ ] Both operations show what they would change and write nothing until the
      operator explicitly applies them.
- [ ] An apply is refused when the collection has changed since the preview the
      operator approved.
- [ ] When the collection holds identities the project's current form would
      record differently, that mismatch is surfaced without the operator having
      to run a rewrite to discover it. The surface names the affected records
      and their count, never the identity values — it is written into generated
      content the project publishes, and each named record already carries its
      own value.
- [ ] The identity shown in any view is the identity recorded in the file, so a
      contributor reads as one identity everywhere without a view having to
      resolve, map, or re-derive anything at display time.

**Attribution of the existing collection**

- [ ] Recovering historical filers records them in the project's current form,
      so a converted issue and a newly filed one agree.

## UI Mockup

Applying the current form to a collection recorded under a previous one:

```
Identity re-normalization plan — docs/issues

  renormalize  20260817-unify-the-two-issue-frontmatter-parsers
                 filed-by   alice@company.com -> alice
  renormalize  20260813-begin-does-not-report-which-arm-it-took
                 claimed-by bob@company.com -> bob
  unchanged    20260812-three-load-bearing-place-sh-guards-are-unpinned

  2 to re-normalize · 350 unchanged · 0 ambiguous

PLAN-HASH: 4f21ba09

This migration is destructive — recovery is via your version control.
```

Replacing one identity with another:

```
Identity remap plan — docs/issues

  from  alice@company.com
  to    1234+alice@users.noreply.github.com

  remap  20260817-unify-the-two-issue-frontmatter-parsers   filed-by
  remap  20260813-begin-does-not-report-which-arm-it-took   filed-by, claimed-by

  2 to remap · 350 unchanged

PLAN-HASH: 91c7d0ee
```

Refusing an ambiguous result:

```
error: two records hold addresses that become the same identity under the
       current form:
         20260817-unify-the-two-issue-frontmatter-parsers
         20260813-begin-does-not-report-which-arm-it-took
       both record as: alice
error: nothing was written; open either record to see the address it holds
```

## Out of Scope

- **Privacy, redaction, and unlinkability.** Rewriting an identity in an issue
  file does not remove it from the commit history beside it. A collection whose
  every address has been rewritten still sits in a repository that publishes
  each of them, so a rewrite that presented itself as redaction would be
  claiming something it cannot deliver. This spec changes how identity is
  *recorded*, not what the repository discloses.
- **Forges other than GitHub.** One forge's relay addresses are recognized.
  Adding another should be cheap, but no second forge's format is asserted
  here — none has been verified, and guessing one would produce exactly the
  confidently-wrong attribution this spec exists to prevent.
- **Per-contributor choice of form.** A contributor cannot select their own
  form. Two forms live in one collection only during a re-normalization, never
  as a steady state.
- **Authoring or maintaining the alias mapping.** jim reads a mapping the
  project's version control already carries. It does not create one, write to
  one, require one, or define its format.
- **Organizations spanning several domains.** The organization-local form
  extracts within one configured domain. Extraction across a set of domains
  would collapse accounts across a union nobody has checked for uniqueness,
  which is the one place the organization's own guarantee does not reach.
- **Re-deriving identities from history under a new form.** Re-normalization
  reads the value already recorded, not the commit that produced it. An identity
  already reduced to an account name has lost the address it came from, so the
  forms can be applied in one direction only.
- **Verifying the organization's uniqueness assumption.** jim refuses when two
  addresses in the collection collide; it does not audit a directory, validate a
  domain, or assert that accounts are unique in general.
- **Recording an identity's history.** A field holds the current value. The
  sequence of values it has held stays recoverable from version control, not
  from the record.
- **Refusing a filing for the kind of identity it carries.** No contributor is
  turned away for committing under a routable address, a relay address, or any
  other form. The project's setting decides how a value is transformed, never
  whether its owner may file.
- **Attribution integrity beyond repository write access.** Recorded attribution
  inherits the trust model of the alias mapping *as version control resolves it*
  — not of one file at a known path. Repository configuration can redirect where
  the mapping is read from, so the boundary is anyone who can commit or set that
  configuration, which is the same set in practice. Version control's own use of that mapping is a
  display-time transform and therefore reversible — this spec persists its result
  into tracked files, so a mapping that was wrong when a rewrite ran is not
  corrected by fixing the mapping afterwards. The preview discloses that a
  mapping was applied; nothing prevents an operator from applying one deliberately.
- **Guarding the rewrites against a hostile operator.** The preview, the explicit
  apply gate and the drift guard address operator error and stale plans. They are
  not integrity controls and should not be read as any: replacing one identity
  with another across a whole collection is the feature, so an operator who
  intends to misattribute is served by the tool exactly as one who intends to
  correct a rename.
- **Verifying that a recorded identity belongs to the person named.** Version
  control does not check the address a contributor configures, so neither does
  jim. This matters more under extraction than it did before: a bare address
  reads as self-asserted, while an extracted account name reads like something an
  identity provider issued, and the two are textually indistinguishable. The
  recorded value is what a contributor configured — never what any system
  confirmed.
- **Mail systems that distinguish local parts by case.** Every recorded identity
  is lower-cased, and two addresses differing only in case are treated as one.
  RFC 5321 §2.4 holds that a mailbox local-part "MUST BE treated as case
  sensitive" while also stating that exploiting that sensitivity "impedes
  interoperability and is discouraged". jim follows the guidance rather than the
  letter, because it is keying an identity rather than routing mail. An
  organization whose mail server genuinely distinguishes them is unsupported.
- **Deciding whether a project tracks its alias mapping.** jim reads whichever
  mapping is present and takes no position on committing it. The consequence is
  worth stating plainly rather than discovering: an untracked mapping means the
  recorded attribution is not reproducible from the repository alone, and two
  operators can produce different results from the same collection. The preview's
  disclosure is what makes that visible; closing it is the project's call.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point to
evaluate, not a directive.*

### Insight 1: The three forms are one nested rule, not three parallel ones

- **Relates to AC:** *"The forms are ordered: each records everything the form
  below it records, plus one further extraction."* and *"An address outside the
  configured domain is recorded as the form below would record it."*
- **Surfaced as:** three selectable schemes, described as a flat set.
- **Levelled-up requirement (already in the ACs):** each form contains the one
  below it, so a contributor never splits across forms.
- **Deflection reason:** Razor.
- **Architect note:** a flat set is the tempting shape and it is wrong in a way
  that only shows up in production. Organization-local extraction applied to a
  relay address yields the numeric id joined to the account name — worse than
  either alternative. And an organization member who merges a pull request in
  the browser authors under a relay address, which is outside the organization's
  domain: if the organization-local form does not inherit the relay rule, that
  person's browser commits and terminal commits record as two identities, inside
  a single organization, with no duplicate address anywhere to explain it.
- **Routing hint:** Architect to decide.

### Insight 2: Alias resolution has to run before extraction, not after

- **Relates to AC:** *"an identity resolves through that mapping before any
  extraction is applied."*
- **Surfaced as:** "mailmap should be fully supported."
- **Levelled-up requirement (already in the ACs):** one contributor resolves to
  one identity wherever an identity is recorded.
- **Deflection reason:** Delegation.
- **Architect note:** ordering is load-bearing. A mapping is keyed on addresses,
  so extracting first leaves nothing for it to match. Verified behavior worth
  relying on: the mapping lookup accepts a bare angle-bracketed address with no
  name, returns an unmapped address unchanged, and matches case-insensitively —
  so it composes as an unconditional filter with no present/absent branch.
  Note the asymmetry to close: the environment's identity is currently read
  straight from configuration and consults no mapping, while a filer recovered
  from history is read through a mapping-aware spelling. Those two paths
  currently disagree, and both feed the same field.
- **Routing hint:** Architect to decide.

### Insight 3: Relay recognition keys on the service suffix, never on a character

- **Relates to AC:** *"Only addresses actually issued by the relay service are
  extracted."* (deflected from an earlier AC that specified suffix matching as
  the test — Razor.)
- **Surfaced as:** extracting the account name from a private relay address.
- **Levelled-up requirement (already in the ACs):** ordinary mail is recorded
  unchanged.
- **Deflection reason:** Constraint-Sourcing.
- **Architect note:** the separator that appears in a relay address is ordinary
  in real mail, where it marks a tag on a mailbox. Keying recognition on it
  would rewrite an unrelated address into whatever followed the separator.
  Note the deliberate asymmetry with the organization-local form, which *does*
  discard a tag: within one organization's domain a tagged address is the same
  mailbox and therefore the same person, whereas in a relay address the same
  character separates an account id from an account name. Same character, two
  meanings, two rules — worth a comment where they meet.

  Two relay forms are in circulation, confirmed against the forge's own
  reference: one carries a numeric account id ahead of the account name, the
  older one carries the name alone with no separator at all. Recognition must
  therefore strip the service suffix and then an *optional* leading id, or every
  contributor on the older form records as a full address while everyone else
  records as a handle. Note also what extraction gives up: the forge documents
  that commits made under the name-only form stop being associated with an
  account when its owner renames it, while the id-bearing form survives a
  rename. Extracting the name discards the durable half — a deliberate trade,
  since the name is what a reader recognizes, and the reason the remap tool
  belongs in the same increment rather than a later one.
- **Routing hint:** Architect to decide.

### Insight 4: One definition, three write paths

- **Relates to AC:** *"Alias resolution applies everywhere an identity is
  recorded."*
- **Surfaced as:** applying the chosen form when an issue is filed.
- **Levelled-up requirement (already in the ACs):** no two write paths disagree
  about who someone is.
- **Deflection reason:** Razor.
- **Architect note:** three call sites record an identity — the emitter's filer,
  the transition verbs' holder, and the filer recovered by the conversion. The
  existing separation between resolving the environment's identity and judging
  an already-obtained one exists precisely so those paths cannot drift; the new
  transformation belongs at that same seam rather than in whichever caller
  happens to need it first. If only the environment-reading path learns the
  form, newly filed issues and converted ones disagree permanently.
- **Routing hint:** Architect to decide.

### Insight 5: The ambiguity check rides a plan that is already built

- **Relates to AC:** *"When two distinct source addresses would be recorded as
  the same identity, the operation names both and records nothing."*
- **Surfaced as:** a concern that organization-local extraction could merge two
  people.
- **Levelled-up requirement (already in the ACs):** an ambiguous result is
  refused and named, never silently recorded.
- **Deflection reason:** Delegation.
- **Architect note:** the existing previewed migrations build a complete plan in
  memory before writing anything, and already refuse an entire run when a single
  row cannot be resolved. Detecting a collision is a comparison over that plan
  rather than new machinery, and it needs no judgment — which matters, because
  the alternative to a mechanical check here is discovering the merge months
  later in a by-person view that looks perfectly plausible.
- **Routing hint:** Architect to decide.

### Insight 6: Two rewrite operations that differ only in where the new value comes from

- **Relates to AC:** *"supplying the old and new values explicitly"* and
  *"re-apply the project's current form … without supplying any mapping."*
- **Surfaced as:** tooling to update a collection when an email or account
  changes.
- **Levelled-up requirement (already in the ACs):** past attribution stays
  correct when a person's identity changes, and a form change is applicable to
  data already recorded.
- **Deflection reason:** Story-Link.
- **Architect note:** these are one operation parameterized two ways — the new
  value is supplied for a remap and computed for a re-normalization — and both
  want the preview, the explicit apply gate, and the drift guard the existing
  migrations already share. That guard is deliberately a single copy today, for
  a reason that applies here too. Worth deciding whether they are one verb with
  two argument shapes or two verbs over shared internals; the atomic per-file
  write and the index regeneration are common either way.
- **Routing hint:** Architect to decide.

### Insight 7: Recovering a filer follows renames, and rename detection can be wrong

- **Relates to AC:** *"Recovering historical filers records them in the
  project's current form."*
- **Surfaced as:** existing behavior, re-examined while verifying attribution.
- **Levelled-up requirement (already in the ACs):** a converted issue and a
  newly filed one agree.
- **Deflection reason:** Constraint-Sourcing.
- **Architect note:** the recovery follows a file through renames so a file
  moved since creation still reports its creating commit. Rename detection is
  content-similarity based, so two issue files with near-identical content can
  be linked, and the later one then reports the earlier one's author. Observed
  directly while testing: three files with identical content all attributed to
  the author of the first. Real issues differ enough that this is unlikely
  rather than impossible, and the ambiguity check does not catch it — a
  mis-attribution produces a plausible identity, not a colliding one. Worth a
  deliberate decision to accept, rather than an accident.
- **Routing hint:** Researcher to investigate.

### Insight 8: One architectural statement is superseded, rationale included

- **Relates to AC:** *"An address the project's version control maps to another
  is recorded as the form of the address it maps to."* (surfaced by the security
  review — architecture contradiction.)
- **Surfaced as:** the security review re-reading `ARCHITECTURE.md` before
  reasoning about trust boundaries.
- **Levelled-up requirement (already in the ACs):** the recorded value is
  normalized and mapping-resolved rather than stored as supplied.
- **Deflection reason:** Constraint-Sourcing.
- **Architect note:** `ARCHITECTURE.md` § Security Considerations → Recorded
  identity currently states the value "is stored as version control supplies
  it — not normalized, hashed, or mapped", and attaches a **security rationale**
  to that choice. This spec reverses the behavior and concedes the rationale
  (privacy is out of scope here). The refresh that runs at build completion must
  replace the whole paragraph rather than patch its mechanism sentence, or the
  document will keep asserting a property the code no longer has — and the next
  security review will reason from it. What is true afterwards: the value is
  normalized under a project-selected form, resolved through the project's alias
  mapping, and rewritable after the fact behind a preview. This is pipeline-owned
  work, not a follow-on issue.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Should the no-extraction form also lower-case what it records?~ → Yes;
      every form lower-cases. The no-extraction form is defined by extracting
      nothing, not by transforming nothing, and leaving it as the one path where
      case variance survives would have re-introduced the identity split the
      spec exists to close. It also removes a trap in the ambiguity check, which
      would otherwise have refused a contributor's own address typed two ways as
      though two people had collided.
- [x] ~Should a mismatch between the configured form and what the collection
      holds be surfaced, short of running a re-normalization?~ → Yes. A form
      that can be changed without any signal that several hundred records now
      disagree with it is a setting whose effect is invisible until someone
      reads a by-person view and mistrusts it.
- [x] ~Which form should be the default?~ → The forge-relay form. A relay
      address recorded verbatim is noise, and extraction is inert for every
      address that is not a relay.
- [x] ~Should the organization-local form ship at all, given its extraction is
      wrong for addresses whose account part is not person-shaped?~ → Yes. That
      is a reason for a project not to select it, not a reason to withhold it;
      the organization case it serves has unique person-shaped addresses by
      construction.
- [x] ~What happens when the organization-local form is selected with no domain
      configured?~ → Refuse every operation that records an identity. A warning
      would be the weaker choice: this project already made a degraded read
      carry a non-zero status rather than trust a message to be noticed.
