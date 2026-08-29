---
spec: "docs/specs/issue/015-epic-authoring-and-views/spec.md"
reviewed_phases: [spec, plan]
status: "Needs Plan Review"
date: "2026-08-28"
---

# Security Review: Epic authoring and views

## Summary

**Findings:** 0 Critical · 10 Notable · 4 Advisory

Two passes. The spec-lens pass (findings 1–5) found the increment's risk
concentrated in two places — a **second structure** in a generated artifact
whose safety properties were written for the first, and a **second id-shaped
operand** on a write path whose validator ordering was written for one. All
five are dispositioned.

The plan-lens pass (findings 6–14) found something different in kind. The plan
answers all three of the spec pass's routed findings correctly at the level of
*design*, and every safety claim it makes about the existing code held up
under attack. What did not hold is a cluster of **integrity defects in
mechanisms the plan describes but does not specify precisely enough to be
built right** — a comparison with no defined normal form, a field-reader that
cannot see the field, an edge set that is not deduplicated, and a heredoc that
changes meaning when it is made to interpolate. None is a vulnerability; every
one causes the system to assert something false about itself, which is the
failure class this collection's own history is thickest with.

## Coverage

- spec.md — reviewed 2026-08-27 (requirements-gap lens)
- plan.md — reviewed 2026-08-28 (design-flaw lens)

The plan-lens pass was run adversarially: three independent readers, each given
a distinct slice and instructed to default to refuting rather than confirming,
alongside the reviewer's own pass. Every finding below was reproduced by
execution before being recorded — a claim that only survived reading is marked
as such. Findings 6 and the reader-found half of finding 11 were reached
**independently by two routes**, which is recorded here because convergence
from different starting points is a confidence signal this project has decided
is worth keeping.

## Data Classification

| Category | Present? | Notes |
| :--- | :--- | :--- |
| PII | Yes | Contributor identities in `filed-by` and `claimed-by`. An umbrella is an issue and carries both; the spec adds no new identity field and no new identity display. Inherited from spec 012 / 013. |
| Credentials | No | No secret, key, token or password is read, stored or transported. |
| Session data | No | No session state exists in this system. |
| Internal-only | Yes | Issue bodies, `origin` paths naming internal spec directories, and project-internal ordinals. |
| Public | Yes | The collection is published content — the index and the issue files reach the same destination by the same door. |

## Findings

### 1. The index's new section inherits a safety property written for a different shape

- **Severity:** Notable
- **Description:** The spec requires that "a record's own field values can
  never corrupt the structure of the index that carries them," and sources
  that to the existing row sanitizer, which strips the row separator and
  control characters and bounds length. That sanitizer was designed for a
  **flat, single-line, separator-delimited row**. The section this spec adds
  is a different structure: a per-umbrella line carrying an untrusted title
  and a derived count, followed by **indented member lines**. Nesting is a
  structural dimension the row format does not have, and the property "cannot
  forge a row" does not by itself establish "cannot forge a nesting level or a
  member entry." The blueprint's `row-shape-is-the-writers` invariant is
  likewise written in terms of rows and `key: value` pairs.
- **Suggestion:** State the containment requirement in terms of the new
  section's own structure rather than by citing the row sanitizer — that no
  field value can introduce a line into the section, change a member's
  apparent umbrella, or alter nesting depth. That forces the plan to
  demonstrate the sanitizer covers the new dimension instead of assuming
  inheritance, and it gives the plan-lens pass something specific to check.
- **Route:** Spec
- **Relates to:** AC — "A record's own field values can never corrupt the
  structure of the index that carries them" (§ What the index records)

### 2. The roster derivation has no stated termination guarantee, and the index only warns about the records that would break it

- **Severity:** Notable
- **Description:** The spec forbids epic-inside-epic at the write path and
  requires the index to *report* violations that arrive by hand-edit. Reporting
  is not refusing: a violating record persists in the collection and is read by
  every derivation on every subsequent write. Two records naming each other as
  umbrellas are representable, and nothing in the ACs requires the roster or
  progress derivation to terminate over them. The blast radius is
  disproportionate to the cause — the index regenerates on **every** write, and
  every group's end-of-phase candidate batch files through the emitter that
  triggers it, so a non-terminating derivation stops all filing project-wide,
  not just epic views.
- **Suggestion:** Add a requirement that the derivations terminate for any
  content the collection can hold, including membership that violates the
  containment rule. The spec already decided membership is one level; the
  derivation should depend on that decision being *enforced at read time*, not
  on it having been enforced at write time. This is the reason the write-path
  refusal and the index warning are not redundant.
- **Route:** Spec
- **Relates to:** AC — "The collection index reports any membership that
  violates either rule" (§ What an umbrella may contain) and "An umbrella's
  roster can never disagree…" (§ The umbrella's own views)

### 3. A second id-shaped operand reaches a write path whose validator ordering was written for one

- **Severity:** Notable
- **Description:** Every existing lifecycle verb takes exactly one id, and the
  script gates it deliberately: the id clears the validator **before any path
  is composed from it, including the stat inside the slug resolver**, and the
  resolved slug is re-validated afterwards because only one of the resolver's
  two arms returns a value the first check covered. `join`/`leave` introduce a
  second id-shaped operand — the umbrella — and the ACs require only that an
  unresolvable umbrella be refused. "Refused because it names no record" and
  "validated before it is composed into a path" are different properties, and
  only the first is stated. The group's blueprint carries `id-gate-before-path`
  at **critical**.
- **Suggestion:** Require that an umbrella reference clear the same validation
  as the issue reference, in the same order relative to any path composition or
  filesystem access. Stating it at the spec level matters because the natural
  implementation — resolve the umbrella against the index to check it exists —
  reads like validation while performing a lookup, and the existing code's
  comment exists precisely because that distinction was subtle the first time.
- **Route:** Spec
- **Relates to:** AC — "A developer can put an existing issue under an umbrella,
  and take it out again, through a single command each" (§ Creating an umbrella
  and joining it)

### 4. Membership cardinality is unbounded, and the index renders it on every write

- **Severity:** Advisory
- **Description:** An issue may name several umbrellas and nothing enforces a
  count — a deliberate decision carried from spec 012. The new section renders
  membership into a committed artifact that regenerates on every write, so the
  cost of an unbounded field is paid repeatedly and by every reader of the
  repository, not once by its author. One spec in this collection's own history
  generated 88 issues, so a full roster is already large at realistic scale
  without anyone behaving unusually.
- **Suggestion:** The spec's second open question already asks whether the
  section lists every member or a capped view. Settle membership *cardinality*
  in the same decision rather than only the display: they are one question
  about how much a single record can add to a generated file. Measuring against
  the real collection, as the preceding increment did for its row widening, is
  the cheap way to answer it.
- **Route:** Spec
- **Relates to:** AC — "An issue can belong to several umbrellas" (§ Creating an
  umbrella and joining it); Open Question 2

### 5. Derived progress is computed from records the umbrella's author does not control

- **Severity:** Advisory
- **Description:** Membership is stored on the member and the roster is derived,
  so any record can enter any umbrella's roster by editing its own frontmatter,
  and the umbrella's file records nothing about it. The progress figure an
  umbrella reports is therefore a function of records its author neither owns
  nor can see from the file. This is within the project's stated trust boundary
  — repository write access — and it follows directly from the storage model
  the spec chose deliberately. It is not a defect. It is an integrity property
  that the spec does not currently state, and the same class has been stated
  explicitly in each of the three preceding increments.
- **Suggestion:** Record it where those precedents put it — an Out of Scope
  entry saying the progress figure is a coordination signal rather than an
  attestation, that it moves when any member record changes, and that it must
  not be relied on as evidence about who did what. This is a documentation
  requirement, not an acceptance criterion; see Routing Recommendations.
- **Route:** Spec
- **Relates to:** § Out of Scope; AC — "An umbrella's roster can never disagree
  with the records that claim membership in it" (§ The umbrella's own views)

---

*Findings 1–5 are the spec-lens pass and are all dispositioned — 1, 2 and 3
were routed to the spec as acceptance criteria and are answered by the plan's
Design Decisions 3, 1 and 7 respectively; 4 was settled by Design Decision 4;
5 landed as an Out of Scope entry. Findings 6–14 are the plan-lens pass.*

### 6. The write-only-on-change comparison has no defined normal form, and fails on the one field the rule leads with

- **Severity:** Notable
- **Description:** The plan puts one verb-agnostic filter at the change choke
  point and describes it as dropping "every `field<TAB>value` pair whose value
  already matches" the record. The two sides of that comparison are in
  different forms and the plan does not say so anywhere. `apply_verb` emits
  values in **file form** — `claimed-by` carrying literal quotes (`"jrko"`,
  `""`), `status` and `outcome` bare — while `fm_field`, the only current-value
  reader in the file, **strips** quotes. Reproduced: a self-reclaim by the
  current holder yields pair value `"jrko"` against current value `jrko`, and
  a release on an already-unheld record yields `""` against the empty string.
  Both mismatch. The failure is partial and silent: `close`-on-closed and
  `reopen`-on-open correctly no-op, so the rule looks implemented, while
  `claim`, `release` and `start` — the three verbs the plan names by name as
  the ones it fixes — keep writing, keep bumping the stamp, and keep publishing
  a commit for zero semantic change. Reached independently by the reviewer and
  by one adversarial reader.
- **Suggestion:** Specify the comparison against the **composed line** rather
  than the value: `set_fields` writes `field: value`, so the question that
  actually matters is whether `field: value` equals the record's existing
  `^field:` line. That is quote-agnostic, needs no per-field knowledge, and
  cannot drift when a field with a different quoting convention is added. The
  collection's own precedent for a value-domain comparison — the identity
  migration's plan builder — works because it keeps *both* sides unquoted; the
  filter cannot copy it without also re-quoting at emission.
- **Route:** Plan
- **Relates to:** Design Decision 6; tasks 11 and 12

### 7. Two of the seven verbs have no current-value reader at all

- **Severity:** Notable
- **Description:** `fm_field` is anchored at `^<field>:`. `part-of` is never at
  the start of a line — it lives indented under `relations:`. So
  `fm_field "$fm" part-of` returns empty **unconditionally**, whatever the
  record's real membership. Reproduced against a record that genuinely holds a
  membership: `fm_field` answers empty while `relation_targets` answers with
  the umbrella. The plan's Interface Contract asserts the filter covers "all
  seven verbs" and names exactly one mechanism for reading the current value,
  so as written the filter can never recognize a `join` on an umbrella the
  record already belongs to, or a `leave` from one it does not — which are
  precisely the no-op cases the membership half of the feature introduces.
- **Suggestion:** Say in the plan that the filter reads a relation field
  through `relation_targets` and a scalar through `fm_field`, and that the
  membership comparison is set-membership rather than string equality. Note
  that `close --as duplicate` already reads a relation this way, so the
  precedent exists in the same file.
- **Route:** Plan
- **Relates to:** Design Decision 6; Interface Contracts § Write-only-on-change

### 8. Frontmatter membership edges are not deduplicated, so a repeated claim inflates progress and can consume the whole roster cap

- **Severity:** Notable
- **Description:** The plan directs the roster derivation to read `outgoing_fm`
  rather than `outgoing_all` — correct, because a wikilink must not create a
  membership, but the two arrays differ in a second way the plan does not
  account for. `edges_all` is guarded by a `seen_all` key and `edges_fm` is
  appended **unconditionally**; there is no dedup for the frontmatter set
  anywhere in the file. Reproduced: a record carrying
  `part-of: [E, E, E]` renders **one** edge in `## Graph` and produces
  **three** entries in `outgoing_fm` — the existing umbrella-resolves check,
  which is the loop the plan says to sit beside, fires its warning three times
  for one record. A bucketing pass over that set counts the member three times,
  so the progress denominator overstates and the oldest-first cap can be filled
  entirely by one record repeating itself, hiding every genuinely distinct
  member. This contradicts the spec's own criterion that a roster can never
  disagree with the records claiming membership.
- **Suggestion:** Deduplicate by `(member, umbrella)` inside the bucketing pass.
  Do **not** fix it by switching to `outgoing_all` — that reintroduces the
  wikilink problem the plan correctly avoided. The two reasons for preferring
  `outgoing_fm` and for deduplicating are independent and both need stating,
  or the next reader will assume one implies the other.
- **Route:** Plan
- **Relates to:** Design Decisions 1 and 4; task 13

### 9. Making the verb enum interpolate requires unquoting a heredoc whose body contains backticked prose

- **Severity:** Notable
- **Description:** `place.sh`'s `usage()` is a **quoted** heredoc
  (`cat <<'USAGE'`), which is why the backticked words already in its body —
  `` `direct` ``, `` `route` ``, `` `{}` ``, `` `{token}` `` — print literally
  today. Interpolating `${PLACE_VERBS[*]}` requires unquoting the delimiter,
  which simultaneously enables **command substitution** on every one of those
  backtick pairs. Reproduced: the unquoted form emits four
  `command not found` lines on stderr and prints a help body with the four
  words deleted. The strings are fixed and not attacker-influenced, so this is
  not an injection vector — but `route` is a real binary on many systems, and
  where it is on `PATH` every `--help`, no-arg and unknown-subcommand
  invocation would run it and splice its output into the help text. The plan's
  own verify command for this task does not catch it: it redirects stderr into
  stdout and greps for substrings, so it passes against the corrupted output.
  Confirmed by running it.
- **Suggestion:** Name the rewrite rather than the outcome — convert `usage()`
  to the `printf '%s\n'` form its sibling already uses, where only the single
  backtick-free line carrying the vocabulary is double-quoted and every other
  line stays a single-quoted literal. And replace the task's verify with one
  that fails on the failure: assert the help body still contains the literal
  backticked tokens, and that stderr is empty.
- **Route:** Plan
- **Relates to:** Design Decision 9; tasks 2 and 3

### 10. An umbrella reference encoded as a label is silently mangled outside the label charset

- **Severity:** Notable
- **Description:** The plan's Constitution Check settles `--part-of` as "a
  slug-shaped scalar encoded the way `--labels` is". That encoder is a **lossy
  normalizer** for free text — it lower-cases and reduces anything outside
  `[a-z0-9-]` to a hyphen — while the validator the same reference must clear,
  `is_valid_id`, admits `[A-Za-z0-9][A-Za-z0-9._-]*`. The two charsets are not
  the same and the broader one is the one that decides validity. Reproduced:
  `JIM-0042-auth-hardening` passes `is_valid_id` and encodes to
  `jim-0042-auth-hardening`. This is not exotic — `JIM-` is a supported
  `issue_id_prefix` scheme named in `ARCHITECTURE.md`. The written record then
  names an umbrella that does not exist, the index's exact-key resolve check
  warns "names an umbrella not in the collection" permanently, and the roster
  never attributes the member — so a reference that was validated and resolved
  is written as one that resolves to nothing.
- **Suggestion:** Write the **resolved slug**, not an encoding of the operand.
  The value has already cleared `is_valid_id` and already been resolved against
  the collection by the time it is written; a second normalization can only
  disagree with that. State in the plan that a validated id is written
  verbatim, and that the label encoder is for free text only.
- **Route:** Plan
- **Relates to:** Constitution Check row `untrusted-body-never-shell`; task 6

### 11. The umbrella filter gains a refusal without gaining the reference forms the spec requires

- **Severity:** Notable
- **Description:** The spec requires an umbrella be "nameable by the same
  reference forms an issue is nameable by elsewhere in the read views",
  sourcing that to an ordinal, a slug, or a slug prefix. `epic_matches` does
  exact string equality against slugs read out of the graph. Reproduced against
  a fixture holding a real umbrella and one member: the exact slug matches, the
  ordinal matches nothing, the prefix matches nothing — all at status 0. The
  plan adds the refusal without adding the resolution, which makes the outcome
  **worse than today** for two of the three required forms: a silent empty
  result becomes an active refusal of a legitimate reference. Reached
  independently by the reviewer and by one adversarial reader, which also
  noted the capture-time half — `--part-of` has no stated resolution shape
  either, so `--part-of 42` could be refused at capture while
  `join <id> 42` succeeds against the same target.
- **Suggestion:** Resolve an umbrella reference to a slug before matching or
  refusing it, on both the filter and the capture path, using the same
  ordinal → exact → prefix ladder `show` already implements. Make the
  resolution a shared helper rather than a third implementation of the ladder,
  and state that the refusal fires only when resolution fails.
- **Route:** Plan
- **Relates to:** AC — "An umbrella is nameable by the same reference forms an
  issue is" (§ Naming an umbrella that does not exist); Design Decision 10;
  tasks 6 and 24

### 12. A census scoped to containers reports nothing, and the container count the spec draws is not designed

- **Severity:** Notable
- **Description:** The plan's exclusion guard is unconditional: any row of kind
  `epic` skips every work counter. `cmd_stats` prints its headline
  `Open: N · Closed: M` straight from two of those counters. So
  `stats --type epic` — which the plan itself calls "a legal query" and builds
  the guard's placement around — admits only epic rows into scope and then
  skips every one of them before any counter, reporting `Open: 0 · Closed: 0`
  and `_none_` for every cluster however many umbrellas exist. Separately, the
  spec's own mockup shows a container line in the summary
  (`Epics: 2 open · 1 closed`), which is the most direct reading of its
  criterion that the view "reports containers separately". The plan designs the
  `== Epics ==` rollup section but not that summary line, so the criterion is
  served only partly and the degenerate scoped-query output is neither stated
  nor justified.
- **Suggestion:** Add the container count to the summary as a separate line
  computed from its own accumulator — which is what "reports containers
  separately" asks for, and which also gives `stats --type epic` something
  true to say. Then state explicitly what a container-scoped census does with
  the work counters, rather than leaving it as a side effect of where the guard
  sits.
- **Route:** Plan
- **Relates to:** AC — "The statistics view counts units of work and reports
  containers separately" (§ Counting); Design Decision 5; tasks 19 and 21

### 13. The resolution position named for the umbrella refusal cannot be reached

- **Severity:** Advisory
- **Description:** Design Decision 10 says the refusal should follow
  `resolve_person_axes`, "which refuses before any row is read — so a refusal
  writes nothing". That function runs *before* `ensure_index` in both read
  verbs. Deciding whether a slug names an umbrella requires the built index, so
  the refusal cannot literally sit where the plan points. `build_derived_axes`
  is the reachable analogue — it already runs after the index is built and
  before the row loop, which satisfies the property the plan actually wants —
  but it tracks membership only and does not expose `type` today, so it needs a
  second map. Not a wrong design; a position that does not exist.
- **Suggestion:** Name `build_derived_axes` as the integration point, say it
  gains an umbrella set alongside `DERIVED_EPIC`, and keep the
  `resolve_person_axes` citation for the *rule* it established rather than for
  the position.
- **Route:** Plan
- **Relates to:** Design Decision 10; task 24

### 14. The bound quoted for a single umbrella entry is a corpus measurement, not the code's ceiling

- **Severity:** Advisory
- **Description:** Design Decision 4's table gives "worst-case single entry,
  cap 10 | ~890 bytes" among rows that are all measurements over the real
  collection. It is a realistic-title figure, not a bound derived from the caps
  that actually apply — `row_safe` admits 512 bytes per scalar and
  `is_valid_id` 128 per slug, and `status` is checked against **no vocabulary
  at all** in the index writer, unlike `type` and `outcome`. The true ceiling
  for one entry is roughly 2.6 KB, about three times the figure quoted. This
  does not violate the criterion, which requires finiteness rather than a
  number, but the plan's threat model is explicitly a hand-edited record, and
  the one row a hand-edited record would move is the row presented as the
  worst case.
- **Suggestion:** Relabel the row as a realistic-corpus measurement and add the
  derived ceiling beside it. The gap between the two is the honest argument for
  the cap.
- **Route:** Plan
- **Relates to:** Design Decision 4; task 15

## STRIDE Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Spoofing | No | The increment adds no authentication surface and no new identity field. Identity is inherited from specs 012/013 and reviewed there. The plan introduces no identity into the new section or the roster. |
| Tampering | Yes | Finding 1 (structure forgery in the new section — answered by the plan's DD 3, and the underlying newline strip was re-verified by execution). Finding 5 (roster composition by any record). Finding 8 (a repeated membership inflates a derived count). Finding 10 (a validated reference is rewritten into one that resolves to nothing). Finding 9 (the shell rewrites the help body once the heredoc is unquoted — fixed strings, not attacker-influenced, so a defect rather than a vector). |
| Repudiation | No | Every membership change still publishes through the two-phase door under a verb enum. The plan's write-only-on-change rule removes commits only where the record is unchanged, so nothing that happened goes unrecorded — and finding 6 is the inverse problem, commits published for changes that did not occur. |
| Information Disclosure | No | The new section carries slugs, titles, statuses and counts — no identity. `show`'s roster likewise. The identity-concentration trade was named and accepted in spec 014 and is not extended here. |
| Denial of Service | Yes | Finding 2 (non-terminating derivation blocks the single write door — answered structurally by the plan's DD 1, and re-checked against genuine cycles). Finding 4 (unbounded roster in an artifact regenerated on every write). Finding 14 (the entry ceiling is roughly 3× the figure the plan bounds against). |
| Elevation of Privilege | N/A | There is no privilege model to elevate within — membership is edited by whoever runs the verb, with no ownership check, which the spec states as a deliberate exclusion rather than an oversight. Finding 9 executes fixed words from the script's own text, not caller input, so it reaches no privilege boundary. |

## LINDDUN Coverage

| Category | Relevant? | Findings |
| :--- | :--- | :--- |
| Linking | No | The new section carries no identity field, so grouping by umbrella adds no linkage the row identities did not already permit. The concentration trade is recorded in spec 014's Out of Scope. |
| Identifying | No | No anonymized or pseudonymized data is introduced that re-identification could act on; recorded identities are already direct. |
| Non-repudiation | No | Subjects are contributors acting on their own records; nothing here removes an ability to deny an action that they previously had. |
| Detecting | No | Membership reveals that an issue exists in a theme, over a collection that is published in full. Presence is not concealed anywhere in this system. |
| Data Disclosure | No | No data crosses a boundary it did not already cross — the index and the issue files share one destination and one door. |
| Unawareness & Unintervenability | N/A | Data subjects are the project's own contributors, acting directly on their own records, with no third-party processing to be unaware of. |
| Non-compliance | N/A | No privacy policy or regulatory regime is asserted over this collection; spec 013 states explicitly that this is not a privacy feature. |

## Artifact Misalignment

Both artifacts were read together, so spec↔plan inconsistencies are surfaced
separately from routine design flaws. Two, and in both the spec is the source
of truth.

- **Finding 11 — reference forms.** Spec states an umbrella is nameable by an
  ordinal, a slug, or a slug prefix, sourcing that to the `show` verb's own
  documented grammar. The plan's design resolves the transition verbs' operand
  through the full ladder but leaves the filter and the capture flag on exact
  string equality, while adding a refusal on top of it. Route: **Plan** — the
  spec's requirement is right and the plan's design does not yet preserve it.
- **Finding 12 — reporting containers separately.** Spec states the census
  "counts units of work and reports containers separately", and its mockup
  draws that as a summary line (`Epics: 2 open · 1 closed`). The plan designs
  the per-umbrella rollup section but not the summary line, so the second half
  of the criterion is unserved and a container-scoped census reports zeroes.
  Route: **Plan**.

Worth recording what did *not* misalign, because it was the likelier failure:
the plan's answers to findings 1, 2 and 3 were each attacked directly and each
held. The newline strip that makes structure-forgery impossible was confirmed
by execution rather than by reading the function's name; the bucketing shape
was traced against genuine cycles; and the validator ordering the second
operand joins was checked against both existing call sites.

## Routing Recommendations

### Spec amendments

- **Finding 1** — new AC requiring the containment property to hold for the
  index section's own structure, including nesting and member lines, rather
  than by inheritance from the row sanitizer.
- **Finding 2** — new AC requiring the roster and progress derivations to
  terminate over any membership the collection can hold, including one the
  containment rule forbids.
- **Finding 3** — new AC requiring an umbrella reference to clear the same
  validation as an issue reference, in the same order relative to path
  composition.
- **Finding 4** — new AC bounding what one record can contribute to the
  generated section, settled together with Open Question 2.
- **Finding 5** — **not an acceptance criterion**, and applied by hand rather
  than by the auto-router, whose sanctioned target is the Acceptance Criteria
  list. Landed as the Out of Scope entry *"Tamper-evident membership or
  progress"*, recording that an umbrella's progress is a coordination signal
  rather than an attestation, that it moves when any member record changes
  without leaving a trace in the umbrella, and that nothing downstream may read
  it as evidence of how much work was done or who did it. Phrased to restate
  for progress what the schema increment recorded for the holder field, so the
  two read as one policy rather than two coincidences.

### Plan amendments

All nine plan-lens findings route to the plan and were auto-applied under
`auto_security`. Six amend a Design Decision, because in each case the decision
is right and its *mechanism* is under-specified; three amend or add a task.

- **Finding 6** — Design Decision 6 gains the comparison's normal form: the
  filter compares the composed `field: value` line against the record's
  existing line, not value against value.
- **Finding 7** — Design Decision 6 gains the relation-field reader: a scalar
  through `fm_field`, a relation through `relation_targets`, membership
  compared as a set.
- **Finding 8** — Design Decision 1 gains the `(member, umbrella)` dedup and
  the statement that it is a second, independent reason from the wikilink one.
- **Finding 9** — task 2 gains the named rewrite (`printf` form, not an
  unquoted heredoc) and task 3's verify gains an assertion that fails on the
  failure: literal backticks still present, stderr empty.
- **Finding 10** — the Constitution Check row and task 6 gain: a validated,
  resolved id is written verbatim; the label encoder is for free text only.
- **Finding 11** — Design Decision 10 and tasks 6 and 24 gain the shared
  reference-resolution ladder, applied before the refusal.
- **Finding 12** — Design Decision 5 and task 21 gain the container summary
  line and its own accumulator.
- **Finding 13** — Design Decision 10's integration point moves to
  `build_derived_axes`, keeping the `resolve_person_axes` citation for the rule
  rather than the position.
- **Finding 14** — Design Decision 4's table relabels the measured row and adds
  the derived ceiling beside it.

### Candidate issues

None from this run. Every plan-lens finding is in scope for the increment being
planned and routes to the plan; none is a follow-on. Three candidates were
filed during the plan stage itself and are unrelated to these findings.
