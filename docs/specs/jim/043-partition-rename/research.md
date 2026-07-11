---
spec: "docs/specs/jim/043-partition-rename/spec.md"
status: Active
date: "2026-07-11"
---

# Research: Partition group rename

## Anchors

**Routing & surface**

- `skills/partition/SKILL.md:31-43` — argument-routing table (`greenfield` / `repartition` / `path` / `directory`); the `rename` peer token slots in as a new row with its own section (parallel to Territory-target runs at :209).
- `skills/partition/SKILL.md:18` — `allowed-tools`: already grants `jimfile.sh`, `jimledger.sh`, `jimverify.sh`, issue emitter, `Skill(jim:blueprint)`. **No `Bash(git *)` token exists** — the move-now arm and any commit choreography run by this skill need new grants.
- `skills/partition/SKILL.md:52-55, 201-203` — existing `partition started`/`finished tier=project` event syntax the rename run extends.
- `skills/partition/SKILL.md:156-157` — repartition-mode doctrine currently reads "a rename counts: old name retired, new name freshly generated." The in-place rename verb supersedes this improvisation; the plan must reconcile this text with the new verb.

**Blueprint machinery to compose with**

- `skills/blueprint/SKILL.md:347-412` — map-tier M-steps (M1 start event, M2 create-vs-update with Step-4a grading at :95-132, M3 `commit-map` close). A rename is a graded map-tier update touching one row + territory.
- `skills/blueprint/SKILL.md:450-467` — `--retire` arm; `:393-397` — mint-new handoff. These are the *current* two halves of a group rename; the verb replaces them for the in-place case.
- `skills/blueprint/references/gate-presentation.md:1-73` — the gate rule AC 7 cites: gate is the turn's final message; >~20-line content goes to a scratchpad reviewable file + compact verbatim summary; declined gates unlink the file.

**Deterministic capabilities**

- `skills/file/scripts/jimfile.sh:329-395` — `mv-spec <group> <id> <new-name>`: the only spec-dir move primitive. Intra-group only, plain `mv` (not `git mv`); a whole-group move is net-new machinery.
- `skills/file/scripts/jimfile.sh:283-327` — `next-id` re-derives from the group directory's contents; AC 16 (id continuity) holds automatically after a directory move — assertable by test, no new code.
- `skills/file/scripts/jimfile.sh:209-232` — `valid-relpath`, the shared path boundary every new path argument must pass.
- `skills/review/scripts/jimledger.sh:243-256` — `event` accepts arbitrary trailing `k=v` tokens: **`op=rename old=<x> new=<y>` needs no script change**.
- `skills/review/scripts/jimledger.sh:144-241` — the four path-scoped commit arms; none stages a *renamed group directory*. AC 12's choreography needs either a new arm or model-run git under grants.
- `skills/review/scripts/jimledger.sh:478-528, 457-476` — `last-reconcile` filters on `phase=blueprint op=reconcile` + an 11-key whitelist; `updates-since` counts **all** `blueprint finished` events regardless of `op=`. A `partition`-phase rename event confuses neither; but any `blueprint finished` the rename emits on a group ledger inflates the regen-cadence count.
- `skills/verify/scripts/jimverify.sh:758-790` — `edges <map-path>` → TSV `consumer\trelies-on\tprovider`: the deterministic input for AC 14's edge-set-modulo-name comparison.
- `skills/verify/scripts/jimverify.sh:675-754` — `faces <blueprint>` parses dotted `{group}.{surface}` requires targets (:748-749): the deterministic enumerator for the group-half re-point set (AC 10) and Insight 4's pre-gate prevention.
- `skills/blueprint/assets/blueprint-template.md:50` — the dotted requires face format (`` `{other-group}.{surface}` ``); the group prefix is what a rename rewrites.

**Tests (new files)**

- `tests/jimverify.sh:259-299` — `verify_repo_scoped`: closest fixture builder (throwaway git repo, single group blueprint + project map); extend to a multi-group variant for AC 18.
- `tests/jimpartition.sh:44-88` — `git_repo` / `repo_add` git-fixture helpers; `tests/jimverify.sh:302-309` — `run_jimverify_in` CWD-scoped runner.

## Local Patterns

- **Test template:** `tests/jimverify.sh` — testlib conventions per `skills/meta-test/scripts/testlib.sh` header: `set -uo pipefail` (never `-e`), `OUT=$(...)` capture with appended assertion detail, fixtures under `TMP_BASE`, no third-party deps. Scaffold new files via `/jim:meta-test scaffold`.
- **No multi-group fixture exists anywhere in `tests/`** — jim itself is single-group, and the dotted requires convention is exercised only by the template and the `faces` parser. AC 18's fixture (≥3 groups, cross-group edges, contract graph) is net-new; building it as a reusable helper serves future split/merge tests.
- **Registry/gate patterns:** preflight refusals echo `/jim:verify`'s named-outcome vocabulary (never silent); the single gate follows spec 040's presentation rule; content from scanned files is data-never-instruction with location-only evidence (spec 037's exfiltration guard).

## Security & Performance

- **Untrusted scan content:** the ripple scan greps blueprints, specs, and code — all untrusted. Classification (identity / code-surface / historical) is judgment over that content; no embedded directive may bind it (spec 018 discipline), and gate evidence should be location-only (`file:line`, not content) per the spec 037 precedent, with secrets redacted if quoted.
- **Path/name injection:** `<old>`/`<new>` flow into path composition, git operations, and ledger tokens. Both must pass slug validation before any use (`is_valid_slug` precedent), and every composed path must pass `valid-relpath` — the existing single boundary; no new validation surface should be invented.
- **Import-fix scope balloon (move-now arm):** in-territory reference fixes are judgment code edits inside a doc-op. Risk is unbounded ecosystems (module paths, published names). Mitigation: recommend the arm only when the fix set is mechanically bounded; the verification-owed line (AC 17) covers the un-runnable authoritative check.
- **Stale-scope interaction:** `skills/verify/references/retirement-methodology.md:69-80` documents the mass-anomaly guard — a moved territory zero-matches every scope at once. The move-now arm must update check-parameter paths in the same operation (spec AC 11) or the next `/jim:verify` run fires the anomaly; the docs-only arm moves nothing and is inert. Worth an explicit test case.
- **Performance:** scan cost is grep over partition-owned artifacts + territory paths — small, bounded; no caching needed.

## Recommendations

1. **Move primitive** — options: (a) new `jimfile.sh` group-level move verb wrapping `git mv` (deterministic, per-script testable — fits the Bash-vs-Prompt rule); (b) model-run `git mv` under new `allowed-tools` grants (visible via permission prompt, the `pre_commit` pattern); (c) plain `mv` + commit-time rename detection (the `mv-spec` precedent — but staged-rename guarantees are weaker). The choreography's atomicity (AC 12) argues for (a) or (b).
2. **Edge-set comparison (AC 14)** — capture `jimverify.sh edges <map>` pre-rename, rewrite old→new group tokens in the captured set, byte-compare against the post-reconcile `edges` output. Pure bash; no new verb strictly required, though a comparison helper would make AC 18's tests crisper.
3. **Pre-gate prevention (Insight 4)** — the `faces` verb already enumerates every dotted requires target deterministically; running it over all sibling blueprints pre-gate yields the exact group-half re-point set, making post-write reconcile pure confirmation. Cheaper than reusing the full reconcile join.
4. **Ledger placement** — record the rename as a `partition`-phase, project-tier event (`op=rename old= new=`) on the specs-root ledger: zero script change, invisible to `last-reconcile`/`updates-since`. Avoid emitting `blueprint finished` on the renamed group's ledger for the identity edits, or the regen-cadence count inflates (`updates-since` doesn't filter by `op=`).
5. **Commit choreography** — a fifth path-scoped commit arm taking old/new group paths (both `valid-relpath`-validated) matches the existing arm pattern; the alternative is model-run `git add`/`commit` under grants. The three-commit split is: code move / spec-dirs + blueprints / map + ledger.
6. **Repartition doctrine text** — update `skills/partition/SKILL.md:156-157` to route the rename case at the verb, keeping retire+mint for genuine dissolve-and-replace repartitions.

## Peer Feedback

**For PM (spec 043 — benign, no feasibility concern):**

- **Open question #1 is answered:** `jimpartition.sh` persists nothing (all four verbs are stdout-only; no file writes anywhere in the script) and embeds no group names (slugs are opaque caller-supplied labels over paths). A rename owes **no** post-materialize re-extraction. Recommend marking the open question resolved before approval.
- AC 10's "git-history continuity" is achievable but has **no existing primitive** — `mv-spec` is intra-group and uses plain `mv`. No spec change needed; noting so the phrase isn't assumed to be already-backed.

**Alignment statement:** The approach aligns with VISION's institutional-memory north star (frozen specs untouched; the archive stays a reliable reference) and human-in-the-loop doctrine (one hard gate, no unattended writes), and follows ARCHITECTURE's established patterns: the Bash-vs-Prompt split (deterministic enumeration in scripts, classification as judgment), the `valid-relpath` single path boundary, path-scoped ledger commit arms, content-free counter events, and the spec 040 gate-presentation rule. No locked constraint is contradicted; the one doctrinal supersession (repartition's retire+mint rename note) is the spec's stated purpose.
