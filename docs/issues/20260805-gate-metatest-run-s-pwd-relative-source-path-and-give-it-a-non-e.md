---
id: 20260805-gate-metatest-run-s-pwd-relative-source-path-and-give-it-a-non-e
num: P-20260805-gate-metatest-run-s-pwd-relative-source-path-and-give-it-a-non-e
title: "Gate metatest run's PWD-relative source path and give it a non-empty corpus floor"
status: open
priority: medium
labels: [meta-test, security, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
created: 2026-08-05T22:20:34Z
updated: 2026-08-05T22:20:34Z
origin: docs/notes/20260805-b-double-prime-review.md
---

## Description

## Description

`metatest.sh run` sources PWD-relative test files under the skill's own tool
grant, and unlike the two write verbs it calls no guard at all.

`skills/meta-test/scripts/run.sh:75` does `source "$tf"` over a PWD-relative
`tests/*.sh` glob:

```
mkdir -p untrusted-repo/tests
cat > untrusted-repo/tests/aaa_payload.sh <<'PAYLOAD'
echo "*** code execution: uid=$(id -u) cwd=$PWD ***"; touch "$PWD/PWNED"
PAYLOAD
cd untrusted-repo && bash skills/meta-test/scripts/run.sh
  -> *** code execution: uid=1000 cwd=.../untrusted-repo ***
     Ran 0 tests: 0 passed, 0 failed
```

`CLAUDE.md` names this as a security boundary: "Never `source` or `eval`
user-supplied data. Sourcing executes the file as bash." The path is reachable
through the skill's own `allowed-tools` grant via `run_action`, which — unlike
`scaffold_action` and `add_action` — has no `refuse_discovery_root` and no other
gate.

The in-source reasoning for the PWD-relative glob is sound and is not what this
issue disputes: anchoring it at `REPO_ROOT` was tried, wrote into the production
`tests/` directory, and recursed to 31 processes. The gap is that the reasoning
addresses *placement* and leaves the *trust boundary* — the invoking cwd — unnamed
and ungated.

Related, same verb: `run` from the wrong directory is a vacuous green.

```
cd skills/demo && bash ../../skills/meta-test/scripts/metatest.sh run
  -> Ran 0 tests: 0 passed, 0 failed    rc=0
```

There is no non-empty-corpus floor, though `tests/scripthygiene.sh:28-30` states
the opposite principle for its own sweeps ("an empty sweep fails loudly instead of
vacuously passing"). And the second half of the stray-test issue's proposed action
— "state the cwd requirement where the skill tells an operator to invoke them" —
was not done: `skills/meta-test/SKILL.md` contains no occurrence of "project
root".

## Proposed action

Decide the trust boundary for `run` and state it. Options, in increasing strength:
name the cwd requirement in `SKILL.md`; refuse to run when the cwd is not the
repository root the harness expects; or verify the discovered corpus belongs to
this checkout before sourcing.

Add a non-empty-corpus floor so `run` over zero discovered files exits non-zero
rather than reporting a pass.
