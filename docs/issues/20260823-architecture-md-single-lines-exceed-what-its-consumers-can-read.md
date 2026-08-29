---
id: 20260823-architecture-md-single-lines-exceed-what-its-consumers-can-read
num: 355
title: "ARCHITECTURE.md single lines exceed what its consumers can read"
status: closed
priority: high
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [arch, sdlc, readability]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T19:47:45Z
updated: 2026-08-25T07:53:58Z
origin: "ARCHITECTURE.md"
---

## Description

## Context
`ARCHITECTURE.md` is a locked constraint: `/jim:plan`, `/jim:sec`,
`/jim:research`, `/jim:blueprint` and `/jim:build` all read it before reasoning,
and several treat its contents as non-negotiable. It is also generated and
maintained by `/jim:arch`, which writes each architectural note as a single
unwrapped markdown bullet.

Those bullets have grown past the point where the document can be read in
pieces.

## Measurements

Whole file: 597 lines, 204,350 characters (roughly 51k tokens).

| metric | value |
| :--- | :--- |
| longest single line | **23,052 chars** (line 399) |
| lines over 5,000 chars | 7 |
| lines over 1,000 chars | 38 |
| lines over 200 chars | 94 |

It is a dramatic outlier among jim's own generated documents:

| document | longest line |
| :--- | :--- |
| `ARCHITECTURE.md` | 23,052 |
| `VISION.md` | 966 |
| `BLUEPRINT.md` | 678 |
| `docs/specs/issue/000-blueprint/spec.md` | 444 |
| `ROADMAP.md` | 119 |

The practical consequence: reading **four lines** (398–401) costs 65,454
characters, roughly 16,400 tokens. A read of the whole file is about 51k tokens
and is refused outright. Line-based windowing — the only granularity a file read
offers — does not help, because the unit of oversize *is* the line.

## Why it matters

The failure is silent rather than loud. A skill that cannot read the section it
needs still proceeds, and its artifact still says architecture was checked. The
constraint degrades without anything reporting that it degraded, which is the
same shape as an unnoticed stale index: the record claims a check that did not
happen.

It also compounds. `/jim:arch` appends to these bullets rather than restructuring
them, so each refresh makes the document harder for the next consumer to read.

The clearest illustration is line 400 (23,013 chars), the issue-collection
bullet. It currently says "Seven deterministic scripts" where there are now
nine — a known drift. The line's length is exactly why correcting it is
unpleasant, so the two problems reinforce each other.

## The sharpest instance: a security review that cannot reach the security model

`/jim:sec` Step 2 instructs a review to read this document and note the existing
trust boundaries, so that findings are grounded against them rather than
contradicting or duplicating them. For the ID-coordination allocator — whose
bullet is the longest line in the file at 23,052 characters — that instruction
cannot currently be followed.

That single bullet runs 3,477 words across 45 sentences and cites ten specs. It
is not padding: it is the whole subsystem, from the verb surface through the
compare-and-swap record mechanics to the registry's threat model. The security
material sits at the end, beginning around **character 20,000** of the line:

- the coordination branch is writable by anyone who can push it, so every id,
  slug and group token read back is revalidated before reaching a git command
- a per-clone erosion guard hard-fails on a truncated or rewritten history
  rather than reissuing a consumed id
- a write-containment guard refuses a symlink-escaping local write target
- the `lift` verb crosses a trust boundary, and requiring the registry to
  corroborate a destination independently is what makes the ledger a witness
  rather than an instruction

Two security reviews were run against this repository on 2026-08-23. Neither
reached that text. Nothing reported that it had been missed, because nothing
could tell that it had.

## Not pipeline-owned

Running `/jim:arch` does not fix this. The refresh regenerates the same
unwrapped shape, so the document comes back equally unreadable. What needs to
change is the authoring convention the skill follows, which is why this is a
tracked issue rather than a refresh someone should remember to run.

## Direction, not prescription

Every other generated document in the project already wraps. Bringing this one
in line with them — wrapping generated prose, and probably splitting the few
bullets that have accumulated several distinct claims — would make the file
readable in sections again without changing anything it asserts.

Worth deciding at the same time whether `/jim:arch` should wrap on every
refresh, so the property holds going forward rather than being restored once.

## Resolution (2026-08-25)

The convention first, then the file aligned to it — `be1ac8a` and `fb9844c`.

**`/jim:arch` wraps what it writes.** A new § 5a instructs hard-wrapping every
paragraph and list item at 80 columns, and names what is never wrapped: table
rows, fenced blocks including the Mermaid diagram, headings, link definitions,
and a URL longer than the budget. It binds a differential update as much as a
fresh generate, so a refresh converges the document rather than reflowing lines
it had no reason to visit. The validation checklist carries the matching item.

**The step that could not be followed now can be.** Step 3 instructed reading
the existing document *fully*, which is exactly what this document had outgrown.
It reads by section now, with the `##` headings as the boundaries — a change
worth making only because wrapping is what makes a bounded read cost what was
asked for rather than what the surrounding paragraph weighs.

**The rewrap is whitespace-only, and was verified as such** rather than
asserted. Both versions collapse to identical text under whitespace
normalization, and every block-structure count matches across them: fences,
headings, bullets, quotes, table rows and blank lines. 134 lines gained breaks;
every line already within budget is byte-identical.

**One hazard was real and is worth recording.** Breaking a line before a word
that opens a markdown block turns prose into a heading, a list item, or — in a
document that discusses fenced code — a fence. The first attempt did exactly
that: a paragraph naming ``` produced a line starting with it, which flipped
fence parity for every line after it and silently reclassified hundreds. The
reflow carries such a word onto the previous line instead. Eight lines sit
82–85 characters wide as a result, which is the right trade.

## What it bought

A 40-line window at the worst paragraph went from **94,325 bytes to 3,187** — a
bounded read now costs what was asked for. The longest line outside a fence is a
table row.

## What it did not buy

Wrapping does not shrink a document. `## Plugin Conventions` is still roughly
124 KB of a 214 KB file, so section-by-section reading works for six of the
seven top-level sections and that one needs subsection ranges. That is a
different problem in kind and is filed as
[[20260825-plugin-conventions-is-half-the-architecture-document]].
