---
title: "Read-view filter composition"
type: feature
group: "issue"
id: "014"
status: approved
origin:
  - "docs/brainstorms/20260817-issue-epics-and-enhanced-filtering.md"
---

# 014 Read-view filter composition

## Overview

Let a developer narrow the issue collection's read views by composing several
filters in one query, and record in the collection's generated index the fields
those filters read.

## Problem Statement

The collection holds 350 issues and the read views accept one filter word. That
word is matched against lifecycle state or priority, and nothing else. There is
no way to ask for the high-priority work in one area, for the issues a
particular contributor is holding, or for the follow-up work a spec generated.

The preceding two increments made this a gap rather than a limitation. One added
identity, kind, outcome, and umbrella membership to every record; the next
settled the form a recorded identity takes and made it consistent across the
collection. **Every one of those fields is write-only.** A developer can claim
an issue and cannot then list what they hold. The collection records who filed
each of 350 issues and no view can group by it. The schema now answers questions
the views cannot ask.

The same gap hides work behind its own provenance. `origin` already records the
artifact each issue was filed from, and one spec — `docs/specs/issue/011-issue-placement` —
accounts for 88 issues on its own. That is a body of follow-up work with a
recorded common cause and no way to ask for it.

Underneath both sits a structural reason the gap cannot be closed in the views
alone: **the read views do not read issue files.** They parse the collection's
generated index, whose per-record rows carry six of the fields a record now
holds. The fields the new filters need are parsed when the index is built — for
its integrity and identity-drift checks — and then discarded rather than
recorded. A filter has nothing to read even though the collection has already
been read.

## User Stories

- As a developer, I can list the work I am holding, so that I know what I am on
  the hook for without opening every file.
- As a developer, I can combine several filters in one query, so that I can ask
  for the high-priority work in one area instead of narrowing by eye.
- As a developer, I can list the issues one spec generated, so that the
  follow-up work a piece of the pipeline surfaced is reachable as a body of
  work.
- As a developer picking up work, I can set aside the issues that are waiting on
  something else, so that what I choose from is work I can actually start.
- As a developer, I can see who filed or holds an issue in a list, so that
  filtering by a person and reading the result are not two different commands.
- As a developer reading the collection's index, I can see each record's kind,
  filer, holder, and outcome there, so that the index describes a record as
  fully as the record itself does.
- As a developer, I can choose which columns a single query shows, so that I can
  see the field I filtered on without changing the project's standing default.
- As a maintainer, I can scope the collection's statistics to a filter, so that a
  rollup answers a question about part of the collection rather than only about
  all of it.
- As a developer, I am told when a filter word is not one the views recognize,
  so that a mistyped query is refused rather than quietly answered with
  something else.
- As a developer filtering by a person, I can name myself rather than an
  address, so that the query does not depend on which of my addresses this
  machine commits under.

## Acceptance Criteria

**Composing a query**

- [ ] A read view accepts several filters in one query, given in any order.
- [ ] Values naming the same axis combine as alternatives: a record matches if
      it satisfies any of them.
- [ ] Filters naming different axes combine as conjunction: a record matches
      only if it satisfies all of them.
- [ ] A filter's two spellings — a bare word and a named flag — feed the same
      axis. Naming one axis through both widens that axis's alternatives, rather
      than refusing the query or discarding either spelling.
- [ ] A query that matches no record reports that it matched nothing and
      succeeds. Matching nothing is an answer, not a failure.

**The recognized vocabulary**

- [ ] A bare word resolves only against the views' own reserved vocabularies —
      lifecycle state, priority, kind, and the derived predicates. It never
      resolves against a label, a slug, an ordinal, or a contributor.
- [ ] A bare word outside those vocabularies is refused, the refusal names the
      words that are recognized, and the query fails without writing anything to
      disk. This preserves an existing guard while widening the vocabulary it
      enforces and lifting the current limit of one filter word.
- [ ] A value that is both a reserved word and a label remains reachable as a
      label through the label filter. The reserved reading of a bare word is not
      overridable, so each of the two meanings has exactly one spelling that
      reaches it.
- [ ] A flag given with no value, or with a value that is another flag, is
      refused rather than treated as absent.

**Filtering by a person**

- [ ] A record is filterable by who filed it and, separately, by who holds it.
- [ ] A developer can name themselves rather than an address, and the view
      resolves that to the environment's identity.
- [ ] A person filter matches a record when the query and the record name the
      same contributor under the project's configured form, so a query does not
      have to be spelled the way the collection happens to have recorded it.
- [ ] A contributor value the configured form cannot judge stays reachable by
      naming it exactly, so the records the re-normalization skips do not become
      unfilterable. *(External Constraint — `issue` group blueprint § Provides:
      `identity.sh`, whose form refuses a value outside its recordable character
      set; `index.sh` already reports these records as holding an identity the
      form cannot judge.)*
- [ ] When the environment's identity cannot be resolved, a query naming the
      developer is refused, names what is missing, and fails without writing
      anything. *(External Constraint — Upstream Spec:
      `docs/specs/issue/012-schema-and-state-model` § Filer identity, "when the
      developer's identity cannot be determined from the environment, filing an
      issue is refused and nothing is written". A query resolves the identity
      through the same definition, so it answers the same way.)*
- [ ] A refusal arising from a value the view resolved rather than the operator
      supplied names the condition and the setting to correct, never the value.
      *(External Constraint — `issue` group blueprint § Provides: `identity.sh`,
      whose refusals are fixed reasons carrying neither the rejected value nor
      issue content.)*
- [ ] There is no single word meaning "mine". Who filed an issue and who holds
      it are separate questions, so each takes its own filter.

**Filtering by originating artifact**

- [ ] A developer can filter to the issues one spec generated, naming the spec
      by its group and directory rather than by a full path.
- [ ] That match covers every artifact within the spec's directory, not only the
      spec document — so work surfaced by a review, plan, or research pass under
      that spec is included.
- [ ] A developer can filter on the recorded origin directly by prefix, reaching
      origins that are not specs.
- [ ] An origin match is a path prefix, so naming a spec's group and ordinal
      reaches it without naming the rest of its directory.

**Derived predicates**

- [ ] Whether an issue is held is filterable without naming a person, in both
      directions.
- [ ] Whether an issue is blocked is filterable in both directions. An issue is
      blocked when it depends on an issue that is not finished.
- [ ] A record can never disagree with either predicate — neither is recorded,
      so both are computed from what the collection already holds and there is
      no second copy to fall out of step.

**Defaults and disclosure**

- [ ] The work-queue view continues to hide finished issues by default, and only
      a filter naming lifecycle state overrides that. Every other filter leaves
      the default in place. *(Preserves existing behavior, including the
      configured toggle that opts finished issues back in.)*
- [ ] A view that hid finished issues while a filter was active says so, so a
      narrowed result is never mistaken for the whole match.
- [ ] The statistics view never hides finished issues. A filter scopes which
      records it counts; a census whose output reports a finished count cannot
      also conceal one.

**Choosing columns**

- [ ] The list view can display a record's kind, filer, holder, and outcome
      alongside the columns it already offers.
- [ ] The displayed columns can be chosen for a single query without changing
      the project's configured default.
- [ ] A column chosen for a single query that names an unrecognized column is
      refused, and the refusal names the recognized columns. The project's
      configured default continues to fall back to the default set instead, so a
      mistyped setting never makes the collection unreadable.

**Statistics**

- [ ] The statistics view accepts the same filters as the list view, under the
      same combining rules.
- [ ] A scoped statistics run discloses what it was scoped to, so a rollup is
      never read as covering the whole collection.

**What the index records**

- [ ] The collection's index describes each record with every field a filter can
      name, so a reader of the index sees the same facts the filters act on.
- [ ] A record's index entry omits a field the record does not carry, so an
      unheld issue and one that has never been finished add nothing to it.
- [ ] A record's own field values can never corrupt the structure of the index
      that carries them. *(External Constraint — `issue` group blueprint
      § Provides: `index.sh`, "line-oriented parse only"; the existing row
      sanitizer strips the separator and control characters and bounds length.)*
- [ ] When a filter names an axis the collection's index does not describe, the
      view says so and fails, rather than reporting that nothing matched. An
      empty result means nothing matched — it never means the view could not
      look.

## UI Mockup

Composing bare words and flags:

```
$ /jim:issue list open high --label auth --claimed-by me

open (2)
  #312   2026-08-14   high       Auth middleware drops the tenant claim
  #287   2026-08-02   high       Session refresh races the token rotation
```

Filtering to one spec's follow-up work. No filter here names lifecycle state,
so finished issues stay hidden and the view says so:

```
$ /jim:issue list --spec issue/011-issue-placement --priority high,critical

open (3)
  #204   2026-07-19   critical   Placement door leaks a handle on abort
  #198   2026-07-18   high       Materialization skips a nested tree entry
  #191   2026-07-17   high       Read handle survives a failed index rebuild

  (closed hidden — add `closed` to include them)
```

Choosing columns for one query, without disturbing the configured default:

```
$ /jim:issue list unclaimed blocked --cols num,priority,filed-by,title

open (2)
  #341   high       sam@example.com    Reconcile drops a realized redirect
  #333   medium     you@example.com    Split leaves a stale territory entry
```

An unrecognized bare word is refused, and nothing is written:

```
$ /jim:issue list 17
error: unrecognized filter token: 17
       bare words are one of:
         open active closed · critical high medium low · issue epic
         claimed unclaimed · blocked unblocked
       to open an issue by id: /jim:issue show 17
```

A query naming the developer, when the environment has no identity to resolve:

```
$ /jim:issue list --claimed-by me
error: cannot resolve 'me': no contributor identity is configured
       set one with: git config user.email <address>
```

Statistics scoped to a filter, disclosing the scope:

```
$ /jim:issue stats --spec issue/011-issue-placement

== Summary ==

  scope: spec=issue/011-issue-placement
  Open: 12 · Closed: 76
```

## Out of Scope

- **Negating a filter.** Excluding a label or a person was deferred in the
  brainstorm's own design and stays deferred. Every filter here is an inclusion,
  and the combining rules are stated for inclusions only.
- **Epics themselves.** This spec makes kind and umbrella membership filterable.
  It does not create an epic, provide a way to join or leave one, derive an
  epic's roster or its progress, or add an epic section to the index. Those
  belong to the epic increment. The two filters are inert until it lands, which
  is the point: that increment then builds views rather than a second parse
  surface.
- **Completion-rate metrics.** Recording outcome in the index is what makes an
  honest completion rate possible. Reporting one — completion as done over
  finished, with the non-done outcomes as signals in their own right — is a
  separate increment.
- **Filtering by a relation.** Blocked-ness is derived from one relation, but no
  filter names a relation directly; there is no way to ask for the issues
  blocking a given one. The index already renders the relation graph.
- **Issues that relate to a spec without originating there.** An origin filter
  reports provenance, not association. An issue filed from a conversation that
  discusses a spec stays invisible to that spec's filter. Carried forward from
  the brainstorm, which established this as accepted rather than open.
- **Sorting and grouping by the new fields.** The views gain filters and
  columns; the existing sort and grouping settings are unchanged, including the
  grouping option that currently degrades to a flat list.
- **Changing how a configured column default fails.** A mistyped standing
  setting continues to fall back to the default column set. Only a selection
  made for a single query refuses.
- **Saved, named, or aliased queries.** No stored filter sets and no shorthand
  beyond the reserved vocabulary.
- **Searching issue bodies.** Every filter reads a recorded frontmatter field. A
  whole-file match would reach body content, which is the failure the
  collection's parsers are already built to avoid.
- **Filtering what the insights persona reads.** The read-only synthesis
  subagent's input is unchanged.
- **Concentration of contributor identities in the index.** Recording the filer
  and holder on every index row puts the collection's full contributor roster in
  one generated file. This is not a new disclosure — the index is published to
  the same destination as the issue files, by the same door, and every value it
  carries is already in a file beside it — but it is a new convenience for
  anyone who wants the roster in one read. The alternative that would avoid it
  was weighed and rejected on cost. Named here so the trade is recorded rather
  than discovered. One distinction the argument does not cover evenly: a filer
  is also recoverable from the file's creating commit, and a holder is not —
  a claim leaves no trace in history, so the file is its only record. The
  conclusion is unchanged; the "already available elsewhere" half of it applies
  to one field and not both.
- **Verifying that a recorded identity belongs to the person named.** A person
  filter reports what was recorded, never what was verified. Version control
  does not check the address a contributor configures, so neither does jim, and
  an extracted account name reads like something an identity provider issued
  while being textually indistinguishable from a self-asserted one. Established
  in spec 013 and repeated here rather than left one artifact away, because a
  filter is where a maintainer will actually lean on it. It is not an
  attribution control.

## Research & Architecture Handoff

*Implementation insights surfaced during scoping. These are context for the
architect — not requirements, not exclusions. Treat each as a starting point to
evaluate, not a directive.*

### Insight 1: The index row is the substrate, and widening it is the whole substrate change

- **Relates to AC:** *"Every field a filter can name is recorded in the
  collection's generated index."*
- **Surfaced as:** filtering by user, by spec, and by label.
- **Levelled-up requirement (already in the ACs):** the views answer from one
  representation of the collection.
- **Deflection reason:** Delegation.
- **Architect note:** `index.sh` already parses every field these filters need
  into its metadata arrays, for the integrity checks and the identity-drift
  surface — it simply never renders them into a row. `render.sh`'s row reader
  iterates separator-delimited `key: value` parts and ignores keys it does not
  know, so the new fields are additional match arms rather than a new parser.
  The row sanitizer already deletes the separator character and control
  characters and bounds length, so field safety is inherited rather than rebuilt.
  Measured cost on the current collection: **+16.5 KB on a 140 KB index
  (+11.8%)**, because the row emitter already omits empty fields — every record
  gains a kind and a filer, finished ones gain an outcome, and holder and
  umbrella appear only where set.

  Two alternatives were weighed and rejected. A second machine-readable
  representation roughly doubles the index and adds a second atomicity question
  and a second staleness question to invariants written around there being one
  index. Re-reading frontmatter per query plants a third frontmatter parser that
  would have to independently reproduce the timestamp degradation and the
  frontmatter-bounded discipline — the duplication this project already pays for
  once in the validator triplicate.
- **Routing hint:** Architect to decide.

### Insight 2: A person filter has two sides to normalize, and one of them can refuse

- **Relates to AC:** *"the query and the record name the same contributor under
  the project's configured form"* and *"a value the configured form cannot judge
  stays reachable by naming it exactly."*
- **Surfaced as:** filtering by user.
- **Levelled-up requirement (already in the ACs):** a query does not have to be
  spelled the way the collection recorded it.
- **Deflection reason:** Delegation.
- **Architect note:** `identity.sh` already separates resolving the
  environment's identity from normalizing a value already obtained, which is
  exactly the seam this wants — a query goes through the same definition the
  write paths use, so a filter and a capture cannot disagree about who someone
  is. The asymmetry to close: normalization refuses a value outside its
  recordable character set, and the collection can legitimately hold such
  values — the index already reports them as an identity the form cannot judge.
  A filter that refuses on that class makes exactly those records unfilterable,
  which is the opposite of what the drift warning is asking an operator to go
  fix. Comparing the normalized form where both sides normalize, and the literal
  value where either does not, reaches every record.
- **Routing hint:** Architect to decide.

### Insight 3: `origin` is already read and then discarded

- **Relates to AC:** *"A developer can filter to the issues one spec
  generated."*
- **Surfaced as:** the observation that filtering by spec is mostly already
  there.
- **Levelled-up requirement (already in the ACs):** follow-up work is reachable
  as a body of work.
- **Deflection reason:** Razor.
- **Architect note:** the row reader already parses `origin` as a field of the
  row it emits; the list view reads that field and then drops it when packing
  its rows, which is why the grouping option that groups by origin silently
  degrades to a flat list. The origin filter needs the value carried one step
  further rather than obtained. Resolving a group-and-directory spec reference
  to a path prefix needs the configured specs root, which this group already
  reads through the config CLI. One caution: the ordinal in a spec path is not
  stable — the spec group's rename and split verbs renumber directories and
  sweep the citations — so the filter must match whatever `origin` currently
  records, never a resolution cached anywhere.
- **Routing hint:** Architect to decide.

### Insight 4: The staleness gate can serve an index written before the fields existed

- **Relates to AC:** *"the views answer from one representation of the
  collection."*
- **Surfaced as:** existing behavior, re-examined while settling the substrate.
- **Levelled-up requirement (already in the ACs):** one representation, not two.
- **Deflection reason:** Constraint-Sourcing.
- **Architect note:** the read views rebuild the index only when it is older than
  the collection's files. An index written by the previous emitter can therefore
  be newer than every issue file and be served as current — in which case every
  new filter matches nothing, and the view reports that honestly and wrongly.

  The security review declined to let that stand silently: the spec refuses a
  query loudly when the environment's identity will not resolve, on the grounds
  that an empty result is indistinguishable from genuinely holding nothing, and
  this path reaches the same indistinguishable emptiness by another route. The
  AC now requires the view to say so and fail.

  **This is still not a reason to build a version marker or an embedded schema
  stamp.** The condition is detectable from the data: `type` is non-empty on
  every record after the 012 conversion, so *rows exist but none carries `type`*
  identifies a pre-widening index with no stamp and no transition code. The
  repair remains one regeneration; what changed is that the view names the
  condition instead of answering around it.
- **Routing hint:** Architect to decide.

### Insight 5: Two derived predicates, two different costs

- **Relates to AC:** *"Whether an issue is held is filterable … Whether an issue
  is blocked is filterable."*
- **Surfaced as:** a flat list of derived words alongside the stored ones.
- **Levelled-up requirement (already in the ACs):** neither predicate is stored,
  so no record can be inconsistent about them.
- **Deflection reason:** Delegation.
- **Architect note:** held-ness is an emptiness test on a field already loaded
  with the row. Blocked-ness needs each dependency target's lifecycle state,
  which means a second pass keyed by slug — but the index already renders the
  edge set, and the statistics view already parses that section for its blocking
  rollup, so both the data and the parse exist. Worth noting the closure question
  the derivation raises and the AC settles: blocked is one hop, not transitive.
  An issue depending on a blocked issue is already blocked by that dependency's
  own unfinished state, so one hop and the transitive closure agree — but only
  because the predicate keys on *not finished* rather than on *blocked*. Keying
  it on blocked-ness instead would make the two diverge and require a traversal.
- **Routing hint:** Architect to decide.

### Insight 6: The refusal has to fire before the collection positional binds

- **Relates to AC:** *"A bare word outside those vocabularies is refused … and
  the view writes nothing."*
- **Surfaced as:** the brainstorm's expectation that strict bare words would
  incidentally fix a read verb that created a directory from a mistyped filter.
- **Levelled-up requirement (already in the ACs):** a mistyped query is refused
  rather than answered with something else.
- **Deflection reason:** Constraint-Sourcing.
- **Architect note:** that guard already exists and already holds — an
  unrecognized argument is refused with a non-zero status and no directory is
  created. The brainstorm predates the fix. What matters for this increment is
  the property the existing guard depends on, which the widened parse surface
  must preserve: the refusal fires *before* the trailing collection-directory
  positional binds. The ordering is the fix, not the vocabulary. The statistics
  view carries the same positional and gains the same parse surface, so it needs
  the same ordering. The existing refusal also distinguishes "you mistyped a
  filter" from "there is no such collection" depending on whether a directory was
  already given; a widened vocabulary should keep that distinction rather than
  collapse both into one message.
- **Routing hint:** Architect to decide.

## Open Questions

- [x] ~Where should the new filter axes read their values from — a widened index
      row, a second machine-readable representation, or a direct read of issue
      frontmatter?~ → The widened row. It adds no parser (the fields are already
      parsed and discarded), inherits the existing row sanitizer, keeps one
      atomicity and one staleness question, and costs +11.8% on the index
      against roughly +100% for a second representation. It is also the option
      that leaves the two following increments building views rather than
      substrate.
- [x] ~Under composition, when should the work-queue view stop hiding finished
      issues?~ → Only a filter naming lifecycle state overrides the default,
      exactly as today. The alternative — treating any explicit filter as intent
      to see everything — was rejected as a silent change to a default that
      users already rely on; the disclosure line covers the confusion it would
      have prevented.
- [x] ~What does a query mean when a bare word and a flag name the same axis?~ →
      They union. Both spellings feed one per-axis set, which is the mechanical
      extension of the rule already stated for values within a flag, and it
      avoids a special case that would make the two spellings subtly different
      things rather than two ways of writing one.
- [x] ~What happens when a query names the developer and the environment has no
      identity to resolve?~ → Refuse with a non-zero status. Returning an empty
      result would be indistinguishable from genuinely holding nothing, which is
      the stale-view-reported-as-current failure this group's invariants exist to
      prevent.
- [x] ~Should a general origin filter ship alongside the spec filter, given
      `origin` also records brainstorms, debug documents, and conversations?~ →
      Yes. It is the same prefix comparison without the specs-root resolution,
      and without it every non-spec origin stays unreachable.
