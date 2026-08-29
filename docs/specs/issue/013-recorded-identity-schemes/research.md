---
spec: "docs/specs/issue/013-recorded-identity-schemes/spec.md"
status: Active
date: "2026-08-23"
---

# Research: Recorded identity schemes

**Scan coverage.** Phase 0 was performed directly rather than delegated to an
Explore subagent — no agent grant was in force for this run. The anchors below
were read, not sampled, but the sweep is one context's rather than a fan-out's.

## Anchors

- `skills/issue/scripts/identity.sh:1-118` — the whole definition of a
  recordable identity. Two verbs: `validate` (`:63`) and `resolve` (`:87`). The
  accepted character set is `:50`, byte-exact under `LC_ALL=C` (`:43`). The
  header at `:8-10` states the stance this spec reverses ("not normalized,
  truncated, or mapped through a table"); rewriting it is part of the change.
- `skills/issue/scripts/new.sh:204` — the emitter resolves the filer *before*
  the allocator runs, so a refusal costs no ordinal. Any new refusal inherits
  that ordering for free.
- `skills/issue/scripts/transition.sh:228` — the verbs resolve one actor for all
  five transitions, deliberately "a single rule rather than a per-verb matrix".
- `skills/issue/scripts/migrate.sh:415` — the conversion validates a filer
  recovered from history through the same gate as a configured one.
- `skills/issue/scripts/migrate.sh:375-385` — `derive_filer`, the only
  mailmap-aware path today (`%aE`, plus `--diff-filter=A --follow`).
- `skills/issue/scripts/migrate.sh:190-206` — `gate_apply` / `plan_hash`, the
  shared preview-drift guard. Its comment states a second copy is "the one
  duplication worth avoiding outright"; both new rewrites should call this one.
- `skills/conf/scripts/jimconf.sh:50` (key registry), `:87-97` (defaults),
  `:237` (bare-name prefix-arm dispatch) — the three places an `identity_*`
  family must land. Miss `:237` and the key silently resolves as
  `identity_scheme_path`, which is the documented failure mode of a key added
  without an arm.
- `skills/issue/scripts/index.sh:152-161` — `parse_scalar_fields`, whose
  whitelist already carries `filed-by` and `claimed-by`.
- `skills/issue/scripts/index.sh:479-487` — the integrity-warning channel. This
  is the natural home for the configured-form mismatch surface: it already
  emits per-issue schema warnings and is regenerated on every write.
- `skills/issue/scripts/render.sh:578-598` — `show` prints the stored values
  directly, which is what makes "the identity shown is the identity recorded"
  true today rather than something to build.

## Local Patterns

- **Test template — `tests/issues.sh`** (238 cases, the meta-test framework;
  `set -uo pipefail`, no third-party deps). Identity is pinned per-invocation at
  `:62-68` via `GIT_CONFIG_COUNT` / `KEY_0` / `VALUE_0`, which outrank any config
  file and need no repo setup. The genuinely-absent case uses
  `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null` (`:4438`). Conversion
  cases build a real git repo with a known author via `schema_repo` /
  `schema_commit` (`:4447-4470`) — the pattern any mailmap case should extend,
  since a `.mailmap` is just another committed file in that fixture.
- **Migration shape** — preview → `PLAN-HASH` → explicit `--apply --expect`.
  Plans are built whole in memory before any write, and `apply_schema_plan`
  already refuses the *entire* run when one row is unresolvable. The ambiguity
  check the spec requires is a comparison over that existing plan, not new
  machinery.
- **Refusal discipline** — fixed reason strings, never the rejected value.
- **Config discipline** — a failed resolution refuses rather than yielding a
  default the caller cannot distinguish from a configured value.

## Prior Art

- **GitHub no-reply address formats** —
  [Email addresses reference](https://docs.github.com/en/account-and-profile/reference/email-addresses-reference).
  Two forms exist, and this invalidates a spec AC (see Peer Feedback):
  accounts created after **2017-07-18** get `ID+USERNAME@users.noreply.github.com`;
  accounts created before it, with privacy enabled before that date, get
  `USERNAME@users.noreply.github.com` — **no numeric prefix and no `+` at all**.
- **Username changes break attribution** — same source: "If you use your
  `noreply` email address for GitHub to make commits and then change your
  username, those commits will not be associated with your account", and this
  "does not apply if you're using the ID-based `noreply` address". The numeric
  id is the stable half; the handle is not. This is the documented, vendor-
  acknowledged failure mode that justifies the remap tooling.
- **RFC 5321 §2.4** —
  [rfc-editor.org](https://www.rfc-editor.org/rfc/rfc5321#section-2.4): "The
  local-part of a mailbox MUST BE treated as case sensitive." *and* "However,
  exploiting the case sensitivity of mailbox local-parts impedes interoperability
  and is discouraged." Lower-casing is contrary to the letter and aligned with
  the guidance; jim uses the address as an identity key, not to route mail.
- **git mailmap** — verified empirically against the installed git rather than
  from docs: `check-mailmap` accepts a bare `<addr>` with no name, returns
  unmapped addresses unchanged, and matches **case-insensitively**. A name-only
  mapping line (`Proper Name <relay>`) normalizes several display names on one
  address. `%aE` honors it; `%ae` does not.

## Libraries

None. The change stays inside bash + POSIX tooling per `CLAUDE.md`; no
dependency file is touched and nothing here needs `jq`.

## Security & Performance

- **The character set must not widen.** Extraction only ever shortens a value
  that already cleared `IDENTITY_CHARS`, so the fail-closed property holds — but
  only if normalization runs *after* validation, or its output is re-validated.
  An extracted value is still written into a double-quoted YAML scalar.
- **Refusal messages now have two classes.** Naming the two colliding addresses
  is necessary for the ambiguity refusal to be actionable, and safe: both values
  already cleared the gate and are already stored in the collection. The existing
  never-echo rule must stay attached to *validation* failures specifically.
- **No new per-read cost.** Everything resolves at write time; reads keep
  printing stored values. Alias resolution costs one `git` invocation per
  recorded identity — acceptable on a one-shot conversion, and it is the same
  order as `derive_filer`'s existing one-fork-per-file.
- **Mass mutation.** Both rewrites touch every tracked issue file, behind the
  existing preview + drift guard + per-file atomic write.
- **`--follow` can mis-attribute.** Rename detection is content-similarity
  based; two near-identical issue files can link, attributing the later to the
  earlier's author. Observed directly during this research with identical-content
  fixtures. The ambiguity check does not catch it — a mis-attribution is
  plausible, not colliding.

## Alignment

**ARCHITECTURE.md — aligned.** Every change lands in the `issue` group's own
territory, plus the `platform` config registry — the ordinary domain→platform
straddle, not a boundary crossing. The scripting-layer conventions hold
unchanged: bash + POSIX only, `set -uo pipefail`, `BASH_SOURCE`-relative
composition, one resolver with many consumers. The new configuration family
follows the documented bare-name prefix-arm convention rather than inventing a
fourth dispatch shape.

**VISION.md — the divergence spec 012 already recorded, unchanged in kind.**
`VISION.md:67` scopes issue capture as a discovery artifact "not as a
team-coordination primitive", and the organization-local form plus alias merging
lean further into multi-contributor ground. Noted for continuity rather than
re-raised: 012's research surfaced this same line, and the developer has said
they are handling it separately. Nothing here changes its shape — this spec adds
weight to an already-open question, it does not open a new one.

## Recommendations

1. **Normalize after validate, then re-validate.** Cheapest way to keep the
   fail-closed guarantee without reasoning about whether extraction can widen a
   value.
2. **Put the transformation beside `validate`/`resolve`**, not in the callers.
   Three write paths record identities; if only `resolve` learns the scheme, new
   issues and converted ones disagree permanently.
3. **The two `+` rules run in opposite directions — state it once, loudly.**
   Relay extraction discards everything *before* the `+` (an account id); the
   organization-local form discards everything *after* it (a mailbox tag). One
   character, two rules, opposite halves. This is the most likely
   implementation error in the whole change.
4. **Route the mismatch surface through the existing integrity warnings**
   rather than a new command.
5. **Consider recording nothing new for the legacy relay form.** See below.

## Peer Feedback

**For the PM — one AC is invalidated by the GitHub finding.**

The spec currently says *"A relay address that yields no account name is
recorded unchanged, never as an empty identity."* Written against the modern
`ID+USERNAME@` form, that reads as a safety net. Against the **legacy
`USERNAME@users.noreply.github.com`** form it is a live defect: a naive
"take what follows the `+`" rule yields nothing, so a pre-2017 contributor is
recorded as a *full address* while everyone else is recorded as a handle —
inside the default scheme, producing exactly the identity split this spec
exists to close.

The fix is small but it is an AC change, not an implementation detail: relay
extraction must strip the service suffix and then an **optional** leading
`<digits>+`, so both forms yield the same handle. Recommend amending the
Forge relay accounts group before approval.

**Resolved.** The amendment was accepted and applied before approval — the
Forge relay accounts group now carries an acceptance criterion requiring every
relay form the forge issues to record as the same account name. Status moved to
`Active`; the signal is kept above because the reasoning is what makes the
resulting criterion legible.

**Second signal, lower stakes.** GitHub states plainly that handle changes
orphan commits made under a legacy no-reply address. Extracting the handle
therefore discards the one stable identifier the modern form carries. That is a
defensible trade — the handle is what humans read — but it should be an
acknowledged cost in the spec rather than an unexamined one, and it is the
strongest argument for shipping the remap tool in the same increment.
