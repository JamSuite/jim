---
id: 20260807-placement-bookmark-produces-false-rewrite-alarms
num: 271
title: "Placement bookmark produces false rewrite alarms"
status: closed
priority: medium
labels: [issue, placement, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T11:43:54Z
updated: 2026-08-11T08:55:48Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

Two paths corrupt the last-seen bookmark, and the same defect both manufactures
a tamper alarm where none exists and creates a false negative for the attack the
detector exists to catch.

**Advanced before the push.** `place_direct_publish` calls
`place_advance_bookmark` before attempting the push and does not roll back on
rejection. The bookmark then names a commit that exists only in this clone, and
the next plumbing-path read reports "destination branch was rewritten" on a repo
where nothing was.

**Rewound by a degraded read.** `place_check_rewrite` runs on the local tier
too, where no fetch happened, comparing against `refs/heads/<dest>` — which an
online read never advances (only a successful publish does). So the ordinary
sequence read-online, then work-offline produces:

1. publish -> local ref C1, bookmark C1
2. teammate pushes C2 (plain fast-forward)
3. online read -> tip C2, ancestor, silent, bookmark advances to **C2**; the
   local ref is still C1
4. offline -> tip is the local ref **C1**; C2 is not an ancestor of C1 ->
   **"destination branch was rewritten"**, naming two SHAs, on a routine path
5. the bookmark is **rewound to C1**
6. an attacker force-pushes C3 built on C1 -> C1 *is* an ancestor of C3 ->
   **silent**

The suite's own comment says the disclosure "has to stay rare enough to mean
something."

## Proposed action

Advance the bookmark only after a successful publish, and only compare/advance
after an actual fetch — the local tier learned nothing new, so it should do
neither. The rule DD 5 states is scoped to "after any fetch"; the code applies
it after a non-fetch.

Separately: `merge-base --is-ancestor` exits 128 on a missing object, which the
code reads as "not an ancestor" and reports as a rewrite. Distinguishing it is
one `rc=$?; (( rc == 1 ))` away.

## Resolution (2026-08-11)

Fixed in `c4e1c89`. A run that reached nobody now neither compares against the
bookmark nor advances it — one early return rather than a guard on each advance,
since the scattered form is what let the comparison keep running after the
recording stopped. Direct mode advances after the push it succeeded at rather
than before the attempt. An ancestry check that could not run (a missing object,
exit 128) is distinguished from one that answered no.

The rewind half was already closed before this change, so only the false alarm
was live; the guard is now structural, and a case goes silent if the rewind is
reintroduced.
