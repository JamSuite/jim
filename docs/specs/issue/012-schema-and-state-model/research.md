---
spec: "docs/specs/issue/012-schema-and-state-model/spec.md"
status: Needs PM Review
date: "2026-08-17"
---

# Research: Schema and state model

## Anchors

**Schema definition**

- `skills/issue/assets/issue-template.md` — the template the emitter
  materializes; the five new fields are declared here first.

**Frontmatter parsers — there are two, independently maintained**

- `skills/issue/scripts/index.sh:119-153` — `parse_scalar_fields`, a single awk
  pass over a **hard-coded 7-key allowlist** (`status`, `priority`, `title`,
  `origin`, `labels`, `created`, `num`) returning them **positionally, one per
  line**. Adding fields means editing the allowlist, the `END` print order, and
  every caller that reads the lines by position.
- `skills/issue/scripts/render.sh:164-187` — a *separate* inline awk parser over
  a *different* field set, emitting TSV. Same fields must be added twice.

**Emitter**

- `skills/issue/scripts/new.sh:88-101` — the `--flag value` while/case parse
  loop; `--created`/`--updated` already show the optional-scalar pattern that
  `--filed-by` would follow.
- `skills/issue/scripts/new.sh:11-25` — the YAML-encoding contract for untrusted
  scalars, and the fixed-reason-code failure discipline the new refusal joins.

**Integrity reporting**

- `skills/issue/scripts/index.sh:637-638` — the `## Integrity Warnings` section;
  the existing home for all three integrity ACs.
- `skills/issue/scripts/index.sh:259` — `row_safe`, the sanitizer that already
  satisfies "identify offending issues without reproducing body content".
- Existing warning shapes to mirror: `index.sh:392,399,430,459,479,554,581`.

**Migration**

- `skills/issue/scripts/migrate.sh:1-30` — read-only preview → `--apply
  [--expect <hash>]` → exit 3 on drift. **This is the pattern the conversion's
  preview AC needs.**
- `skills/issue/scripts/migrate.sh:163,206-212` — `render_plan` and the
  PLAN-HASH drift guard that refuses a stale plan between preview and apply.
- `skills/issue/scripts/backfill.sh:241` — states outright that its writes have
  **no preview form**. See Recommendations.

**Transitions**

- `skills/issue/scripts/place.sh:103` — `PLACE_VERBS=(file edit close rename
  realize reindex backfill migrate)`. `close` already exists; `claim`, `release`,
  `start`, `reopen` would extend it. The enum is externally visible in published
  commit messages.
- `skills/issue/SKILL.md` § 6a — the `begin` → edit → `commit --verb --id` door
  and the `jimfile.sh now` stamp convention every transition must honor.

**Tests**

- `tests/issues.sh:1-30` — sources `skills/meta-test/scripts/testlib.sh`,
  captures `OUT`/`ERR`/`RC` per invocation, one `SCRIPT_*` constant per
  script-under-test. ~554 assertions; the template for new coverage.
- `tests/place.sh` — the door's own tests, where a verb-enum change lands.

## Local Patterns

**Two parsers, one schema.** The single most consequential structural fact: the
field list is duplicated between `index.sh` and `render.sh` with different
membership and different output encodings. Every new field is two edits in two
styles. Nothing enforces that they agree.

**`backfill` vs `migrate` is a real distinction, and this conversion straddles
it.** `backfill.sh` fills in *missing* data (no preview, idempotent, per-file
atomic tmp+mv). `migrate.sh` *transforms existing* data (preview + `--apply` +
drift hash). This conversion does **both**: `type` / `filed-by` / `claimed-by` /
`part-of` are missing-data fills, while `outcome` is derived from existing
`status`. The spec requires a preview, which only `migrate.sh` provides.

**Placement is currently inert here.** `jimconf.sh:96` fabricates
`issue_placement` default `"branch"` — a sentinel meaning *the branch you are
standing on*, not a branch named "branch". No `jimconf.toml` exists; `place.sh
mode` reports `direct`. The collection is in the working tree. The two-phase
door must still be correct for projects that centralize, but is a no-op here.

**Additive fields are safe outside the group.** `skills/file/scripts/jimalloc.sh:1508`
reads issue frontmatter for `num`/`id`/`created` by key, not positionally, so
new keys do not disturb it. `skills/spec/scripts/reconcile.sh` parses *spec*
frontmatter, not issue frontmatter — not blast radius.

**Test template:** `tests/issues.sh` per-script invoker section (`run_index`,
`run_render`) is the shape to copy; conventions are canonical in
`skills/meta-test/scripts/testlib.sh`'s header. Use `/jim:meta-test scaffold`.

## Prior Art

Verified locally this session (git 2.55.0) rather than from recall:

| Mechanism | Verified behavior | Relevance |
|---|---|---|
| `git log --diff-filter=A --follow -1 --format=%ae -- <file>` | Returns the creating commit's author email; `--follow` survives renames | The filer-recovery mechanism |
| `git check-mailmap` | Available and functional | Identity aliasing, if ever scoped in |
| `git config --get user.email` | Returns this repo's configured address | The `filed-by` source at emit time |

**Derivation dry-run over the real collection — the load-bearing result:**

```
total=350   underivable=0
  342  <contributor A>
    8  <contributor B>
```

*(Real output; the two addresses are anonymized here. A per-person tally in a
published artifact is exactly the aggregation this spec's security review flags
— see `security.md` Finding 6.)*

Every one of the 350 issues yields a creating commit. **The spec's
refuse-loudly criterion carries zero practical risk on this collection** — it
is a guardrail, not a blocker. (Note this differs from a naive `git log -- docs/issues/`
count of 286/10, which measures commits *touching* the directory rather than
*creating* each file. 342/8 is the correct per-file attribution.)

## Security & Performance

- **Contributor emails become durable repo content.** `filed-by` writes real
  addresses into 350 tracked files. They are already in commit metadata, so this
  publishes nothing new — but it moves them into greppable file bodies, and
  under a centralized `issue_placement` they'd land on a shared branch. Worth a
  conscious decision, not a silent one.
- **`--force` claim-stealing has no authorization model.** Nothing prevents any
  contributor from taking any issue. Given jim's trusted-developer model this is
  probably correct, but the spec should say so rather than leave it unstated.
- **The identity value is unvalidated input to YAML.** `filed-by` derives from
  `git config user.email`, which is attacker-controllable in a hostile clone.
  It must go through `new.sh`'s existing scalar-encoding path
  (`new.sh:14-17`), not be interpolated.
- **Git archaeology cost:** the derivation above is one `git log` fork per file
  — 350 forks, a few seconds. Acceptable for a one-shot; unacceptable if ever
  placed in a read path.
- **Parser divergence is the standing risk**, not a performance one: a field
  added to one parser and not the other fails silently in exactly one view.

## Alignment

**ARCHITECTURE.md — aligned.** Every change lands inside the `issue` group's
declared territory (`skills/issue`, `tests/issues.sh`, `tests/place.sh`) and
composes through existing seams: the single emitter, the placement door, the
index. No new cross-group contract edge is introduced, and the group blueprint's
load-bearing invariants (`single-emitter`, `untrusted-body-never-shell`,
`atomic-index-write`, `id-gate-before-path`) are all preserved rather than
amended. The five transition verbs are the one nuance: they would make edits
script-mediated for the first time, which *strengthens* `single-emitter`'s
spirit rather than conflicting with it.

**No new dependencies.** `CLAUDE.md` → Bash scripts mandates Bash + POSIX only,
no third-party tools. Everything this spec needs — `git log`, `awk`, `sed`,
`grep` — is already in use inside `skills/issue/scripts/`. No dependency file
is touched and no sprawl is introduced.

**VISION.md — one live divergence**, recorded under Peer Feedback below.

## Recommendations

Options for the architect — not decisions.

1. **Where the conversion lives.** Three shapes: (a) a new `migrate.sh`
   subcommand, inheriting preview + `--apply` + drift-hash for free and matching
   the "transforms existing data" half; (b) a preview form added to
   `backfill.sh`, contradicting its stated design at `:241`; (c) a standalone
   script. **(a) is the least new machinery** and the only one that satisfies
   the preview AC without new invention — at the cost of filing a
   mostly-missing-data migration under the transform tool.

2. **Collapse the two parsers, or accept the duplication deliberately.** Adding
   five fields to two hand-maintained allowlists doubles a divergence risk that
   already exists. Unifying them is out of this spec's scope but is the moment
   the cost becomes concrete — worth a conscious call either way.

3. **Positional return is the fragile part of `parse_scalar_fields`.** Twelve
   positionally-read lines is materially worse than seven. A keyed return would
   contain the blast radius of every future field.

4. **`part-of` cardinality** (spec Open Question) — the derivation dry-run
   suggests nothing about this; it is a pure design call. Note that storing
   membership only on the member (Handoff Insight 1) makes a list free either
   way.

5. **Verb-enum extension is externally visible.** New `PLACE_VERBS` entries
   appear in published commit messages on centralized collections. Reusing
   `edit` for all transitions keeps history uniform but loses the signal;
   distinct verbs make history self-describing. Cheap now, expensive later.

## Peer Feedback

**For the PM — VISION.md now genuinely contradicts what is being built.**
`VISION.md:67` states issue capture is in scope "only as a *discovery artifact*
... **not as a team-coordination primitive**". `claimed-by`, claim-stealing with
`--force`, and per-holder views are coordination primitives by any reading. The
decision to build anyway was explicit and is not being re-litigated — but the
non-goal should be amended rather than left standing in contradiction, or the
next spec that touches it will re-open the same argument. `/jim:vision` is the
surface for that edit.

**For the PM — one spec AC is looser than the research supports.** "The
conversion previews what it will change before changing anything" is satisfiable
today only by `migrate.sh`'s pattern; `backfill.sh` has no preview by design.
The AC is achievable, but it silently selects the migration surface. Worth
knowing that the AC constrains the architecture more than its wording suggests.
