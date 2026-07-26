---
id: 20260726-retry-the-unreachable-detection-path-and-generalize-the-exhausti
num: 119
title: "Retry the unreachable-detection path and generalize the exhaustion message"
status: open
priority: low
labels: [id-coordination, alloc]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-07-26T22:39:35Z
updated: 2026-07-26T22:39:35Z
origin: docs/specs/platform/007-id-coordination-allocator/review.md
---

## Description

Finding 3 from the platform/007 review (advisory).

In the origin tier, a `git ls-remote` / `git fetch` failure in `alloc_origin_tip`
hard-fails on the first attempt with zero retries; only a push rejection
re-enters the bounded retry loop. The spec's unreachable behavior ("performs
bounded retries and then hard-fails") suggests the reachability-detection path
should also retry — a transient network blip currently fails immediately rather
than retrying.

The security-critical property is intact: an unreachable remote never silently
falls back to an unpublished local allocation, and "bounded" is trivially
satisfied (0 ≤ 5).

Separately, the retries-exhausted message always attributes failure to
"contention on <branch>", which would misdescribe a repeated push-policy denial.

Action: retry the reachability-detection path with the same jittered backoff for
transient blips, and generalize the exhaustion message beyond "contention".
Low priority — behavior is safe as-is.

Location: skills/file/scripts/jimalloc.sh (alloc_origin_tip; the
alloc_cas_append retries-exhausted message).
