---
id: 20260825-plugin-conventions-is-half-the-architecture-document
num: P-20260825-plugin-conventions-is-half-the-architecture-document
title: "Plugin Conventions is half the architecture document"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [docs, arch]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-25T07:53:40Z
updated: 2026-08-25T07:53:40Z
origin: "ARCHITECTURE.md"
---

## Description

Wrapping `ARCHITECTURE.md` fixed what a line costs to read. It did not change
what the document weighs, and one section is now the obstacle the line lengths
used to be.

## The shape

The file is 214 KB. `## Plugin Conventions` is roughly 124 KB of that — more
than half the document in one section — and its `### Scripting Layer` subsection
is the largest single run of prose in the tree. A whole-file read is refused for
size; so is a read of that section.

`/jim:arch`'s differential-update step now reads by heading boundary, which
works for six of the seven top-level sections. For this one the boundaries have
to be `###` subsections or plain line ranges, and even then the largest
subsection is near the limit.

## Why it matters

The skill summarizes which sections it will change and which it will preserve.
Preserving a section it never read is a claim it cannot support, and the section
it is most likely to skip is the one carrying the plugin's own conventions —
the scripting layer, the permission grants, the substitution rules. That is the
part a contributor is most likely to be working against.

It is also the part most likely to be *edited* by a refresh, since it is where
new scripts and new conventions land.

## Why it is not a line-length problem

The rewrap took a 40-line window at the worst paragraph from 94 KB to 3 KB, so
bounded reads are now worth taking. What remains is different in kind: the
document has accumulated the detail of a reference manual in the section that
describes how the plugin is built, and no formatting rule shrinks it.

## Direction

Two options, and they are not equivalent.

Split the reference material out — a `docs/features/` page for the scripting
layer and the plugin conventions, with `ARCHITECTURE.md` keeping the shape and
linking to it. That matches how the project already documents features, and it
leaves the architecture document doing what its own template says it does.

Or leave the content where it is and accept that the section is read in ranges,
recording that in the skill so a refresh does not quietly claim to have
preserved what it did not read.

The first is the smaller document and the larger move; the second is honest
about the current one. Surfaced while closing
[[20260823-architecture-md-single-lines-exceed-what-its-consumers-can-read]].
