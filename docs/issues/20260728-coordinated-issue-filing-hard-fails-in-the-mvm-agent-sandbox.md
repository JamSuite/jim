---
id: 20260728-coordinated-issue-filing-hard-fails-in-the-mvm-agent-sandbox
num: 129
title: "Coordinated issue-filing hard-fails in the mvm agent sandbox"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [id-coordination, workflow, sandbox]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-07-28T21:39:15Z
updated: 2026-07-31T06:38:04Z
origin: docs/specs/platform/007-id-coordination-allocator/spec.md
---

## Description

jim's `id_coordination_unreachable` is `fail` and the coordination remote
(`origin`) is only reachable from the host. Inside any mvm agent-profile sandbox
session, `origin` is unreachable, so coordinated `allocate issue` — the path
every surfacing skill's candidate batch and `/jim:issue add` now route through
(`new.sh` → `jimalloc.sh allocate issue`) — **hard-fails**. Effect: the
end-of-phase candidate batch cannot file *any* issue from a sandbox session, and
`seed`/`reconcile` are likewise host-only.

## Decision to make

Should jim's agent profile run `id_coordination_unreachable = provisional`
instead of `fail`? Provisional mode would let a sandbox session file
provisional-ordinal issues locally (`P-<id>`) and reconcile them into real
ordinals on the host — which is exactly the provisional/reconcile machinery
`platform/009` + `issue/010` built. As-is, sandbox sessions silently lose the
ability to file issues. Alternatively, document `fail` as intended and route all
sandbox-discovered issues through a host handoff (as was done for the 2026-07-28
batch).

## Resolution (2026-07-31)

Decided the first way and committed: `id_coordination_unreachable = "provisional"`
in `jimconf.toml`, as `3d49ce9`.

The dependency that held this open is gone. Under `provisional`, `allocate spec`
used to mint a spec identity nothing could realize
([[20260729-allocate-spec-under-provisional-mints-an-unrealizable-identity]]);
`sdlc/017` shipped spec-side realization, so the mode no longer issues anything
that cannot be settled, for either kind.

It was also already in force in the working tree before being recorded, which is
the real argument for closing it rather than deliberating further: two sessions of
issues and one spec were filed against it and realized cleanly on the host — most
recently eighteen provisional ordinals realized in one batch onto 143–160, no gap
and no collision. A config that load-bearing being uncommitted was the worst
available state.

The alternative — document `fail` as intended and route everything through a host
handoff — is what the 2026-07-28 batch actually did, and it is why this issue
exists. It does not scale past a single batch: it makes every sandbox discovery
wait on a human round trip, which is precisely the friction that loses issues.
