---
id: 20260805-gate-metatest-run-s-pwd-relative-source-path-and-give-it-a-non-e
num: 239
title: "Gate metatest run's PWD-relative source path and give it a non-empty corpus floor"
status: open
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: ""
labels: [meta-test, security, scripts]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-05T22:20:34Z
updated: 2026-08-06T08:05:57Z
origin: "20260805-b-double-prime-review.md (retired; see 5e712bf)"
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

## Partial (2026-08-06) — the corpus floor landed, the source gate did not

**Stays open.** Only the second of this issue's two reproductions is closed.

Landed as `67fceb3`: `run.sh` refuses a working directory with no `tests/`
subdirectory at rc 2 — the code `testlib.sh` already reserves for a setup error —
naming the cause on stderr. The `cd skills/demo && metatest.sh run` vacuous green
in the Description no longer occurs.

The floor keys on **directory presence, not case count**, and that distinction is
load-bearing rather than incidental. An empty `tests/` is legitimate: it is the
shape this runner's own sandbox self-test depends on, and a project may simply
have no tests yet. Keying on case count would have forced
`tests/metatest.sh:199-204` to be un-taught — and that assertion turns out to be
protecting the legitimate empty-corpus case, not the defect. Pinned by
`case_metatest_run_refuses_a_dir_without_tests`, mutation-tested: with the floor
removed it fails, and the empty-`tests/` sandbox case keeps passing.

**The primary subject of this issue — the ungated `source` — is untouched, and
the floor does not even narrow it.** The Description's payload reproduction was
re-run at `67fceb3` and fires exactly as written, because it creates
`untrusted-repo/tests/` before invoking: the directory exists, so the floor
passes and `run.sh:75` sources the payload.

```
cd untrusted-repo && bash skills/meta-test/scripts/run.sh
  -> *** code execution: uid=1000 cwd=.../untrusted-repo ***
     Ran 0 tests: 0 passed, 0 failed
  -> PWNED created
```

None of the Proposed action's three options has been taken: the cwd requirement
is still unstated in `SKILL.md` (still zero occurrences of "project root" — only
`run.sh`'s new error message says it), `run` still does not refuse a cwd that is
not the expected checkout, and nothing verifies the discovered corpus belongs to
this checkout before sourcing. The trust boundary this issue asks to have decided
remains undecided.

Rediscovered independently before this note was written: a `/jim:verify platform`
judge, reading only code, reached the same vacuous-green finding from
`run.sh:73-76` + `testlib.sh:207-213` with no knowledge of this issue. That is
corroboration the finding is real and reachable, and also the reason a duplicate
was briefly filed and deleted — the collection was not consulted first.
