---
id: 20260823-architecture-md-single-lines-exceed-what-its-consumers-can-read
num: P-20260823-architecture-md-single-lines-exceed-what-its-consumers-can-read
title: "ARCHITECTURE.md single lines exceed what its consumers can read"
status: open
priority: high
type: issue
filed-by: "31940806+jrko@users.noreply.github.com"
claimed-by: ""
outcome: ""
labels: [arch, sdlc, readability]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-23T19:47:45Z
updated: 2026-08-23T19:47:45Z
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
