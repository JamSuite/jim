---
id: 20260807-c-config-override-bypasses-placement-resolution
num: P-20260807-c-config-override-bypasses-placement-resolution
title: "-c config override bypasses placement resolution"
status: open
priority: low
labels: [issue, config, placement]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-07T10:59:36Z
updated: 2026-08-07T10:59:36Z
origin: docs/specs/issue/011-issue-placement/plan.md
---

## Description

## Description

`reconcile.sh` and `migrate.sh` accept `-c <config>` and forward it to
`jimfile.sh` / `jimconf.sh` / `jimalloc.sh`. `place.sh` has no `-c`: it resolves
`issue_placement` from `$PWD` through `jimconf.sh`, per the project-root-as-CWD
invariant.

So when one of those two scripts is invoked with `-c` pointing at a config that
sets `issue_placement`, the two disagree — the script's own resolution follows
`-c`, while the placement decision follows the config in the current directory.
Whichever is wrong, they are answering the same question differently.

This is latent rather than live. The documented convention is that production
skills never pass `-c` (`jimfile.sh` header: "The flag exists for tests and
ad-hoc inspection"), and no skill body passes it. Every current `-c` caller is a
test whose CWD config carries no placement key, so the two resolutions agree by
accident of the fixtures rather than by construction.

## Proposed action

Pick one and make it explicit:

1. Give `place.sh` a `-c <config>` flag and have the two scripts forward it, so
   the seam is closed and `-c` means the same thing everywhere; or
2. Have the routing path refuse — or at least disclose — when `-c` is present
   and the CWD config names a placement, so the disagreement cannot be silent; or
3. Document in both script headers that `-c` does not carry placement, making
   the limit of the flag part of its contract.

(3) is the cheapest and may be the honest answer: `-c` is a test seam, and
growing it a placement dimension gives it a second job.

## Notes

Surfaced while adding placement routing to the migration scripts. Not folded in
because closing the seam properly touches the flag's meaning across four
scripts, which is a larger change than the routing it came up in.
