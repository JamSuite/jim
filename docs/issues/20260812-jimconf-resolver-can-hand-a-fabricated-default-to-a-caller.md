---
id: 20260812-jimconf-resolver-can-hand-a-fabricated-default-to-a-caller
num: 311
title: "jimconf resolver can hand a fabricated default to a caller"
status: closed
priority: medium
type: issue
filed-by: "jrko"
claimed-by: ""
outcome: done
labels: [conf, correctness]
relations:
  blocks: []
  depends-on: []
  related-to: []
  duplicates: []
  part-of: []
created: 2026-08-12T03:42:09Z
updated: 2026-08-12T19:28:27Z
origin: docs/specs/issue/011-issue-placement/review.md
---

## Description

## Description

`jimconf`'s resolver collapses several read *failures* into a key's default at
rc 0, so a caller that correctly refuses on a failed resolve can still be handed
a fabricated value it cannot distinguish from a real one.

## Mechanism

`skills/conf/scripts/jimconf.sh:143-148` (`parse_value`) returns early on
`[[ ! -f "$file" ]]` and otherwise greps with stderr suppressed; `resolve`
(`:212-224`) ignores its status and falls through to `default_for` whenever the
output is empty. All of the following therefore yield the default at rc 0, with
no message:

- `jimconf.toml` present but **not readable** (grep exits 2, output empty)
- `jimconf.toml` that is not a regular file (directory, dangling symlink)
- a value written **single-quoted or bare** — the grammar matches only `= "…"`
- an **empty or whitespace-only** value (deliberate, but indistinguishable)
- a **typo'd key** — there is no strict mode
- **CWD is not the project root** — jimconf reads `./jimconf.toml` with no
  walk-up, so a run started from a subdirectory sees no config at all

For `issue_placement` the fabricated default is `branch`, i.e. "do not
centralize", so a project with a configured destination silently writes to the
working branch. `place.sh` was deliberately hardened to refuse a failed resolve
and cannot detect this class, because the failure never reaches it.

## Why file it here

This is jimconf's shared read path, not the issue group's — it affects every key
uniformly. It surfaced while judging the placement gate's "never silently falls
back" guarantee, which the gate honors and the resolver undercuts.

## Proposed action

Distinguish "file absent" from "file unreadable / unparseable" and exit non-zero
on the latter; consider a strict mode that refuses an unknown key, and decide
whether a walk-up to the project root is wanted.

## Origin

Post-build review of `issue/011`, AC 10.

## Progress (2026-08-12)

**The unreadable/unparseable half is fixed** in `39661e1` — the half the issue
states unconditionally. A config that is genuinely absent still resolves to the
documented default at rc 0, which is the zero-config path; a path that exists but
is a directory, a dangling symlink, or unreadable now reports a resolver failure
instead of an unset key, and `resolve` forwards it rather than flattening it into
"no override". A key simply not present in the file is still no override — grep's
"no match" must not read as a failure, or every unset key would refuse.

Pinned by `case_jimconf_unreadable_config_refuses` and
`case_jimconf_non_regular_config_refuses`, with
`case_jimconf_absent_config_still_defaults` holding the zero-config path in
place. The first is proven to go red with the readability check removed.

**Three parts remain open, and each is a decision rather than a fix** — the
issue's own proposed action says "consider" and "decide" for two of them:

1. **Single-quoted and bare values.** The grammar matches only `= "…"`, so
   `key = 'v'` or `key = 3` silently become the default. Supporting them widens
   a parser that is deliberately grep-and-sed.
2. **A strict mode for unknown keys in the file.** A typo'd key is silently
   ignored. Refusing one would break every project carrying an extra or
   commented key.
3. **Walk-up to the project root.** `./jimconf.toml` with no walk-up means a run
   started from a subdirectory sees no config at all — arguably the highest-value
   of the three, and the largest change in resolution semantics.

## Resolution (2026-08-12)

All three parts are now settled. Two shipped; one is declined with its reasoning.

### 1. Single-quoted and bare values — **refused, not supported** (`1a30a0f`)

The proposed action offered supporting them. The inverse is better on this
codebase's terms: a key written `key = 'v'` or `key = 3` now **refuses** rather
than resolving to the documented default, in ~10 lines and with zero parser
growth. Widening the grammar would let a bare `true` resolve to a value every
consumer compares against the *string* `"true"` — trading a silent default for a
silent type mismatch. The remedy is to add quotes, and the message says so.

The refusal is judged on the first line naming the key, which is the one
first-match-wins would have taken. A commented-out key is not a key, which
matters because `jimconf.toml.example` ships dozens.

Pinned by `case_jimconf_unsupported_value_form_refuses`, proven red against the
pre-fix code (`branch` fabricated for a single-quoted `jim/issues`, `0` for a
bare `3`), with `case_jimconf_unsupported_value_form_spares_the_valid_ones` and
`case_jimconf_commented_key_is_not_a_value_form` holding the two shapes that
must not refuse — without them the refusal is satisfiable by refusing
everything.

### 2. A strict mode for unknown keys — **declined**

Lowest value per unit of risk of the three, and unlike the others it has no safe
inverse. Opt-in means the projects that would benefit never enable it;
on-by-default breaks any project pinning a key from a newer jim, or keeping a
forward-compatible one. It also needs an authoritative key inventory, which is
implicit today — an unknown key falls through to `<key>_path` — and the review
already recorded (AC 2) that every new key forces `tests/jimconf.sh` edits.
Making the inventory load-bearing tightens that coupling rather than loosening
it. Recorded here so it is not re-opened as an oversight.

### 3. Resolution from a subdirectory — **detected and refused, never read**
(`1bef1f2`)

Not the walk-up this issue proposed, and the reason is one neither this issue
nor the review named: **this file's own implementation note 4 already recorded
the no-walk-up decision and its cause** — Claude Code's "trust this folder"
sandbox boundary. That conflict is sharper than reading. `pre_commit` and
`pre_completion` name scripts jim runs, and the `deps_command_*` /
`verify_command_*` families are command strings `/jim:partition` and
`/jim:verify` execute verbatim. Honouring a config from above the folder the
session was started in therefore **runs a command from outside that boundary**,
which is a materially worse trade than the silent default it fixes.

What is not tolerable is doing it silently. `get` and `list` now **locate** a
`jimconf.toml` above PWD within the same repository and refuse, naming the file
and the remedy. The file is never opened, so no value from outside the boundary
is ever honoured. The repository is the bound — the walk stops at the directory
holding `.git` and reports nothing when it finds none, so an unrelated config in
a home directory is never named — and the whole probe is pure path arithmetic
and stats, reached only when `./jimconf.toml` is absent.

Three shapes deliberately do **not** refuse: no config anywhere still resolves to
documented defaults at rc 0 (the zero-config path this whole distinction exists
to preserve), a subdirectory carrying its own config is a project root by jim's
definition, and outside a repository nothing is named. `-c` is untouched — it
named a file explicitly. `path` is untouched too: it answers "is there an active
config here" and callers test it with `[ -z "$(jimconf.sh path)" ]`, so it has to
stay able to say no.

Pinned by `case_jimconf_config_above_cwd_refuses_rather_than_defaulting`, proven
red with the locator neutered, and asserting additionally that the parent's
value surfaces in neither stdout nor stderr — the falsifiable statement of
"locate, never read", which is what separates this from the rejected walk-up.
`case_jimconf_config_above_cwd_spares_the_valid_ones` holds all three negatives.

### Effect on `#18`'s trigger 2 — measured, not assumed

`#18`'s trigger 2 is a direct `index.sh` run from a non-root CWD resolving the
relative `./docs/issues` against the wrong place and `mkdir -p`ing a stray nested
tree. Part 3 was expected to leave it untouched, since only the walk-up's *other*
half — anchoring relative values to a discovered root — addresses it, and that
half was declined. Running it shows a split result:

- **A project with a `jimconf.toml` at its root: trigger 2 is closed**, as a
  composition rather than a fix. `index.sh` from `docs/issues/` now refuses at
  rc 2 and creates nothing — the config refusal propagates into `place.sh`'s
  placement gate, which was hardened to refuse an unresolvable setting rather
  than read it as an unset one. Two guards written for different reasons meet
  here.
- **A zero-config project: trigger 2 survives, unchanged.** With no
  `jimconf.toml` anywhere there is nothing to refuse, `issues` resolves to its
  relative default, and `docs/issues/docs/issues/INDEX.md` is still created at
  rc 0.

So `#18` stays open on the case its own notes argue is the root — `index.sh`
must not create its target directory on a regeneration — and both of its
candidate fixes still stand. The message a configured project now gets is also
poorer than it should be: `resolve_dir` discards jimconf's stderr, so the caller
sees the placement gate's refusal rather than "you are not at the project root".
