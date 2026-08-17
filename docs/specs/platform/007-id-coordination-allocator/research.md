---
spec: "docs/specs/platform/007-id-coordination-allocator/spec.md"
status: Needs PM Review
date: "2026-07-26"
---

# Research: ID coordination allocator (foundation)

## Anchors

- **`skills/file/scripts/jimfile.sh:317-361` (`cmd_next_id`, spec path)** — the derivation the allocator supersedes: computes `group/NNN` by *listing the local group directory* for the max 3-digit prefix, then `max+1`, capped at 999. Per-branch by construction — this local scan is the spec-ordinal collision source.
- **`skills/file/scripts/jimfile.sh:344-354` (vacated-id floor)** — `cmd_next_id` already consults a durable ledger side-channel (`jimledger.sh vacated-max`) to floor the next id so a split/merge-vacated id is never re-minted. **The nearest existing pattern to "allocate against a registry."** Its degradation discipline is the template: absent script / non-zero rc / empty output → floor unset, and the floor only ever *raises* max, never lowers (older checkouts degrade to directory-only).
- **`skills/file/scripts/jimfile.sh:437-467` (`issue_next_num` / `cmd_next_num`)** — issue ordinal = `max(num:)+1` scanned across the collection. The header comment (`:434-436`) is decisive: *"The display ordinal is decentralized — duplicates across branches are accepted as non-fatal."* The ordinal is already *stored* in frontmatter (not render-derived); it is the uncoordinated *assignment* that collides.
- **`skills/file/scripts/jimfile.sh:191-210` (`is_valid_id`)** — the single id security boundary (`^[A-Za-z0-9][A-Za-z0-9._-]*$`, no `..`, ≤128). Every re-derived id already routes through `valid-id` (`:217-219`); the allocator validates its computed ids here too (no fourth copy — AC 13).
- **`skills/file/scripts/jimfile.sh:129-161` (`normalize_slug`, `now_utc_iso8601`)** — the slug pipeline and the deterministic UTC timestamp helper the registry records reuse verbatim.
- **`skills/ledger/scripts/jimledger.sh:160-260, 555-620` (commit + `git mv` verbs)** — jim's operational-git precedent and the security template for the allocator's writes (see Security).
- **`skills/conf/scripts/jimconf.sh:132-210` (`parse_value` / `resolve`)** — the grep+sed, never-sourced config reader; the bare-name `resolve()` arm (`:175`) is exactly where the allocator's `mechanism` / `coordination_branch` / `on_unreachable` keys attach (with defaults in `default_for`).
- **New files to create** — a deterministic allocator CLI (e.g. `skills/file/scripts/jim<alloc>.sh` or an extension of `jimfile.sh` — Insight 1), its test file `tests/<name>.sh`, and the new config keys' entries in `jimconf.sh` + `ARCHITECTURE.md` § Scripting Layer.

## Local Patterns

- **Bash-vs-Prompt rule (`ARCHITECTURE.md:395-406`).** The allocator is deterministic (same registry + kind → same next id, verifiable by exit code / string compare) → it lives in a **bash script**; the `/jim:spec` interview and `/jim:issue` confirm-moment that *consume* it stay in prompts. Textbook split-within-a-feature, like `jimverify.sh`.
- **Script conventions (`ARCHITECTURE.md:379-394`; `testlib.sh:1-40`).** `set -uo pipefail` (never `set -e` — it fights the `OUT=$(...)` capture), `export LC_ALL=C`, Bash + POSIX only, zero third-party deps, no `source`/`eval` of untrusted content, `BASH_SOURCE`-relative sibling composition (`jimfile.sh:75,81` chains to `jimconf.sh` / `jimledger.sh` this way).
- **Test template — `tests/jimledger.sh`** is the closest model (a script that reads/writes git): source `testlib.sh` via the `BASH_SOURCE`-relative path, a per-file `run` invoker capturing `OUT`/`ERR`/`RC`, `case_*` functions auto-discovered, temp dirs via `fixture`/`empty_dir` (never production paths). The allocator's compare-and-swap (CAS) race and forward-replay cases fixture a throwaway git repo and assert on exit codes + registry content.
- **Existing degradation idiom** — best-effort side-channel reads (`jimfile.sh:344-354`) never hard-fail the caller; the allocator inverts this deliberately for the *publish* step (a silent local fallback is the collision being solved — AC 9), but keeps the same discipline for *reads*.

## Prior Art

Git-native compare-and-swap is well-established; the two primitives the whole mechanism rests on, confirmed against the official docs (link, don't paste):

- **`git update-ref <ref> <new> <old>`** — atomic CAS: *"stores the new-oid in the ref … after verifying that the current value matches old-oid"*; *"an empty string as old-oid to make sure that the ref you are creating does not exist"*; `--stdin` performs all updates in one transaction (*"if all refs can be locked with matching old-oids simultaneously, all modifications are performed. Otherwise, no modifications"*). → the **local tier** CAS and the batch-atomicity guarantee (git-scm.com/docs/git-update-ref).
- **`git push`** — default rejects non-fast-forward with status `!` (*"not a fast-forward and you did not force the update"*) — that rejection *is* the **origin-tier** CAS when appending a registry commit to the coordination branch; `--force-with-lease=<ref>:<expect>` is per-ref CAS, and *"if expect is the empty string, the named ref must not already exist"* (the create-only claim-ref variant) (git-scm.com/docs/git-push).

Pattern lineage: optimistic-concurrency / DB-sequence semantics (monotonic, gaps allowed, never reused) — the brainstorm's own model. No in-repo prior art for `push`/`update-ref`/`fetch`/plumbing exists (see Security) — this is net-new git surface.

## Security & Performance

- **Net-new git capability class.** A repo-wide grep shows jim scripts today use only *local* git — `ls-files`, `status`, `rev-parse`, `add`/`commit`, `mv`, `diff`. **No `push`, `fetch`, `update-ref`, `hash-object`, `mktree`, or `commit-tree` exists anywhere.** The allocator introduces jim's first *network* and *shared-ref-write* git surface. Consequence for the architect: new permission scope (a narrowly-scoped allocator command grant, mirroring the `jimledger.sh` model), non-interactive git (`GIT_TERMINAL_PROMPT=0`) so a mid-interview auth prompt can't hang, and allocate-late so a publish failure doesn't waste the interview (spec Insight 2 / Open Question).
- **The registry is untrusted, branch-writable input.** The coordination branch is *less* protected than main (anyone running jim can push it), so registry content is untrusted data. Follow `jimledger.sh`'s exact discipline (`:160-260`): parse with grep/sed — never `source`; every id/SHA through `is_valid_id`/`valid-id` before it reaches a git command (forecloses option-injection); literal paths with a `--` guard; never `git add -A`. This is spec AC 13 made concrete, and the reason IDs must never be authorization or integrity anchors.
- **Erosion (AC 10 / G3).** The append-only log's integrity depends on force-push/deletion being denied on the coordination branch (an unusual "direct push allowed, force-push denied" middle protection profile — a team-setup doc item, already filed). The byte-prefix growth guard is the cheap in-band detector.
- **Performance.** Allocation cost is dominated by one `fetch` + one `push` round-trip on contention, not by the log scan (per-kind forward replay is trivial at jim scale). Contention retries race *all* pushes to the coordination branch, not just allocations — which is why a dedicated `jim/registry` branch (not busy `main`) is the likely shipped default (Open Question).

## Recommendations

1. **Extend, don't reinvent, the side-channel-floor pattern.** `cmd_next_id`'s ledger floor (`:344-354`) already proves "consult a durable external record before minting an id." The allocator generalizes it from *floor* to *authority*; the architect should weigh whether the coordinated path replaces or wraps `next-id`/`next-num` (Insight 1) — consumers migrate in the follow-on specs, so the foundation can ship the CLI beside the existing verbs without breaking them.
2. **Model the registry record as the brainstorm's greppable grammar** (`spec allocate … / rename … / group rename …`), file-order authoritative. Forward-replay-from-allocate is what makes reused group names unambiguous (AC 5/7) — implement and test it now even though only `allocate` is emitted (the chosen scope).
3. **Reuse `git update-ref --stdin` for batch atomicity** so the follow-on split/merge (N allocations + N redirects = one transaction) needs no format change — validate the transaction shape here.
4. Keep `mechanism=service` a *reserved, unimplemented* enum value in `default_for` so the config surface is forward-stable without shipping the backend.

**Alignment.** The files-on-branch registry (over hidden custom refs / notes) is the choice VISION's *"not a black box"* non-goal demands — greppable, clonable, repairable with ordinary git — and the multiuser coordination directly serves VISION's stated team context (small teams on tightly-coupled codebases where developers own functional areas). The design *extends* existing `ARCHITECTURE.md` § Scripting Layer patterns (Bash-vs-Prompt placement, the `jimconf.sh` `resolve()` bare-name arm, the `jimledger.sh` operational-git discipline) rather than adding a parallel architectural surface. No locked-constraint divergence — the one genuinely new element is the network/shared-write git *capability*, flagged for the architect above.

## Peer Feedback

**For the PM (spec accuracy — the reason for `Needs PM Review`):** The spec's Problem Statement says issue ordinals are *"derived at index-generation time."* Grounding shows this is imprecise: the ordinal is **assigned at filing time** by an uncoordinated `max(num:)+1` scan and **stored in frontmatter**; `INDEX.md` only *reads* it, and `jimfile.sh:434-436` explicitly documents that cross-branch duplicates are *tolerated as non-fatal*. The collision is real, but its mechanism is filing-time assignment, not render-time derivation. Recommend tightening that one sentence (the fix strengthens the motivation; it does not change scope or any AC). The same precision should carry into the issue-ordinal consumer spec (issue #111).

**For the architect (non-blocking):** The net-new network/shared-write git surface (Security §1) is the single largest new-capability decision in this foundation — worth an explicit permission-scope and failure-mode design pass in `/jim:plan`, since nothing in the codebase exercises these primitives yet.
