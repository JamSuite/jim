---
id: 20260825-roadmap-md-has-not-been-refreshed-since-2026-03-16
num: 384
title: "ROADMAP.md has not been refreshed since 2026-03-16"
status: open
priority: low
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [docs, strategy]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T10:51:06Z
updated: 2026-08-25T10:51:06Z
origin: "docs/specs/issue/014-read-view-filter-composition/spec.md"
---

## What

`ROADMAP.md` carries *Last updated: 2026-03-16* and describes a project that no
longer matches the repository.

## The drift

The **Now** bucket is "v2.0-RC1 — prepare jim for its first public release",
with deliverables covering documentation polish, an mkdocs site, making the repo
public, and beginning real-world validation. Its "Linkable Specs" section lists
six `jim`-group specs and asserts "All core SDLC specs are complete".

Since then the project has shipped, among others:

- the whole `blueprint` group — group blueprints, the context map, the contract
  graph, the verification engine, and the partition lifecycle
- the `platform` group's coordination allocator and provisional-identity
  reconciliation
- the `issue` group's centralized placement, schema and state model, and
  recorded identity schemes

None of that appears anywhere in the roadmap, and the **Later** bucket still
lists "Configuration support — custom paths, templates" as uncommitted, which
`jimconf.toml` has provided for some time.

## Why it matters

`ROADMAP.md` sits alongside `VISION.md` as a strategic document that
`/jim:spec` reads for alignment. A roadmap five months stale supplies no
signal — it cannot contradict a proposal, and it cannot support one either, so
the alignment check quietly degrades to reading `VISION.md` alone.

## Fix shape

`/jim:roadmap`. The mechanical part is re-bucketing Now/Next/Later against what
has actually shipped; the judgment part is what the current Now bucket really
is, which is a question for the maintainer rather than for the tool.
