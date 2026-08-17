---
spec: "spec.md"
status: Active
date: "2026-05-12"
---

<!-- Budget: <1500 words total. Never paste >20 lines of code — use file:line-range + 1-sentence summary. -->

# Research: Post-build ARCHITECTURE.md feedback loop

## Anchors

**Resolver / dispatch (config surface)**
- `skills/conf/scripts/jimconf.sh:42` — `KEYS=(...)` array. Append `auto_arch_feedback` after `require_pre_completion`.
- `skills/conf/scripts/jimconf.sh:48–62` — `default_for()` switch. Add `auto_arch_feedback) echo "false" ;;`.
- `skills/conf/scripts/jimconf.sh:89–106` — `resolve()`. Widen the existing `require_*` prefix branch (line 92) to also match `auto_*` so flag-shaped keys skip the `_path` suffix.
- `skills/conf/scripts/jimconf.sh:76–84` — `parse_value()`. Untouched; key-agnostic parser.
- `skills/file/scripts/jimfile.sh:79–86` — `jimconf_get()`. Untouched; pure pass-through to `jimconf.sh get <key>`, so `bash jimfile.sh get auto_arch_feedback` works the moment the resolver knows the key.

**Build skill (consumer of the new flag-shaped path)**
- `skills/build/SKILL.md:10` — `allowed-tools` already permits `jimfile.sh`; the new `SET arch_doc = …` slot is covered by the existing prefix. The `Skill`-tool permission the spec adds is novel in the codebase (see Peer Feedback).
- `skills/build/SKILL.md:100–116` — Step 5 completion gate. Insert the arch-feedback step between substep 1 (pre-completion gate) and substep 2 ("report results / mark complete?").
- `skills/build/SKILL.md:73–81` — existing pre-commit gate. Live exemplar of the directive shape the new step mirrors, without the `require_*` halt branch.

**Arch skill (consumer of the new flag value)**
- `skills/arch/SKILL.md:11` — `allowed-tools` already permits `jimfile.sh`; the new `get auto_arch_feedback` call is covered (no frontmatter change needed — worth a one-line note in the plan).
- `skills/arch/SKILL.md:76–82` — Step 6 "Present and stop". New `SET auto_arch_feedback` binding + auto-apply / confirm branch lives here.
- `skills/arch/SKILL.md:41–47` — Step 3 *(addressed by spec 011 extension on 2026-05-12)*. Originally used the retired BASIC `IF (X) EXISTS THEN … END IF` shape; spec 011 added Task 24 to migrate this slot to `SET arch_doc = …` + lean paren-free `IF arch_doc EXISTS THEN … ELSE … ENDIF`. The form is now post-011 lean, matching the `vision_doc` / `roadmap_doc` / build-skill `arch_doc` symmetry. No further action needed in spec 013.

**Tests (deterministic surface)**
- `tests/jimconf.sh:39–58` — `case_no_config_returns_defaults`. Extend the pair list with `auto_arch_feedback:false`.
- `tests/jimconf.sh:62–84` — `case_full_config_returns_overrides`. Extend the fixture and assertions.
- `tests/jimconf.sh:106–124` — `case_list_outputs_all_keys`. Bump line count `"10"` → `"11"`; add the `auto_arch_feedback` `assert_match`.
- `tests/jimconf.sh:127–133` — `case_keys_outputs_valid_keys`. Extend the expected list.
- `tests/jimconf.sh:154–170` — `case_malformed_lines_are_ignored`. Hardcoded `"10"` at `:169`; bump to `"11"`. (Five enumeration cases total, not four.)
- `tests/jimconf.sh:237–249` — `case_require_pre_commit_default / _overridden`. Direct template for `case_auto_arch_feedback_default` and `case_auto_arch_feedback_overridden`.

**Docs / examples**
- `jimconf.toml.example` — add `auto_arch_feedback = "false"` after `require_pre_completion`. Follow the `require_*` block's 2–4-line comment + key style (lines 35–40 set the precedent).
- `ARCHITECTURE.md:261` — Scripting Layer "Config file" bullet. Currently says "ten configurable keys... eight paths... and two enforcement flags (`require_pre_commit`, `require_pre_completion`)" and "(CLI keys starting with `require_`) map directly". Widen the prefix description to `require_` or `auto_`, bump the count, and name the new key family.
- `ARCHITECTURE.md` Core Components — add one short paragraph to the build-skill / arch-skill component sections covering the post-build feedback loop, the flag, and the existence-conditioned trigger.

## Local Patterns

**Flag-prefix dispatcher.** `require_*` at `skills/conf/scripts/jimconf.sh:92–96` is the only existing flag-shape branch in `resolve()`. The spec extends by one prefix, not a generalization — cleanest change is widening the existing branch's condition to `require_* || auto_*` rather than adding a separate arm. Doc lock-in at `ARCHITECTURE.md:261`.

**Directive vocabulary (post-011).** `ARCHITECTURE.md:279–344`. The new steps need:
- `SET … = !` + paren-free `IF … EXISTS THEN … ENDIF` for the build step (no `ELSE` — absent-skip is implicit fall-through).
- `SET … = !` + paren-free `IF … == "true" THEN … ELSE … ENDIF` for the arch step (string-literal branch).

Live exemplars: `skills/build/SKILL.md:73–81` and `:106–114`.

**Permission narrowing (post-012).** Both skills' `allowed-tools` already declare `Bash(bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh *)`; the new `get` calls fall under the existing prefix. Only frontmatter delta is the `Skill`-tool permission on `/jim:build` (novel — see Peer Feedback).

**Test framework.** Template: `tests/jimconf.sh` (anchors above). Framework: `skills/meta-test/scripts/testlib.sh`, sourced via `BASH_SOURCE`-relative path (`tests/jimconf.sh:16–17`). Assertions `assert_eq`/`assert_match`/`assert_exit`/`assert_nonempty`; heredoc `fixture <name> <content>` in `$TMP_BASE` sandbox; per-case dispatch by `case_*` function name. New cases mirror `case_require_pre_commit_*` verbatim, swapping the key name.

## Security & Performance

- **No new resolver attack surface.** Parser is unchanged (`parse_value()` is key-agnostic, never `source`s the file). Adding a key to `KEYS` + a `default_for()` arm extends the validity check, not the parse path.
- **Load-time injection cost.** Two new `!`-bash slots — one in `/jim:build` (`SET arch_doc`), one in `/jim:arch` (`SET auto_arch_feedback`). One bash exec each, same cost class as existing `pre_*` slots.
- **Post-build full-codebase scan.** Each `/jim:build` completion triggers a full Glob/Grep sweep through `/jim:arch` step 4. Acceptable per spec; delta-only mode is deferred in Out-of-Scope. Worth a follow-up if friction surfaces.
- **Auto-apply trust boundary.** `auto_arch_feedback="true"` removes the human confirmation between a code change and the locked-constraint document downstream skills enforce. Mitigation lives in the spec — opt-in default, existence gate, no `require_*` counterpart. Risk bounded by user's explicit toggle.
- **Skill-tool reach.** `/jim:arch` invoked from `/jim:build` runs inline in the main thread (no fork per `ARCHITECTURE.md` Skill Invocation), so `allowed-tools` from `/jim:build` cover the nested body.

## Recommendations

1. **Single-branch widening in `resolve()`.** Prefer `if [[ "$cli_key" == require_* || "$cli_key" == auto_* ]]; then` over a separate `auto_*` arm. One condition stays the dispatch contract; ARCHITECTURE.md:261's "(CLI keys starting with `require_` or `auto_`)" reads as one prefix family.

2. **Build step shape (no `ELSE`).** Implicit silent skip when `arch_doc` is absent — matches the directive vocabulary's "implicit fall-through" rule:

       SET arch_doc = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get architecture`

       IF arch_doc EXISTS THEN
         Invoke /jim:arch via the Skill tool to refresh ARCHITECTURE.md against the just-built code.
       ENDIF

3. **Arch step 6 shape (`==` branch, explicit `ELSE`).** Two branches — one silently skip is wrong here; the existing user-confirmation flow must fire on the false branch:

       SET auto_arch_feedback = !`bash ${CLAUDE_PLUGIN_ROOT}/skills/file/scripts/jimfile.sh get auto_arch_feedback`

       IF auto_arch_feedback == "true" THEN
         Write the proposed update directly to the configured architecture path. Summarize which sections were added, changed, or preserved.
       ELSE
         Present the diff and ask: "Does this look accurate? Any sections to refine?" Wait for confirmation.
       ENDIF

4. ~~**Bundle the spec-011 hygiene fix into the same plan.**~~ *Resolved 2026-05-12:* spec 011 was extended (Task 24) to migrate `skills/arch/SKILL.md:41–47` to the lean form (`SET arch_doc = …` + paren-free `IF arch_doc EXISTS THEN … ELSE … ENDIF`). No piggyback needed in spec 013.

## Peer Feedback

**For PM — spec feasibility signals**

1. **`Skill` tool in `allowed-tools` — syntax resolved; convention novel in jim.** Per `docs/research/20260512-001-meta-skill-invocation-freshness.md:53` and current Claude Code docs, permission rules use `Skill(name)` syntax — so the right token is `Skill(jim:arch)`. Fork prior art (commit `9039461`) used English-prose body instructions telling the LLM to invoke `/jim:arch` via the Skill tool, which maps onto the upstream mechanism. Signal that remains for PM: no existing jim skill calls another via Skill, so this sets a first instance — worth a one-line Plugin Convention note in `ARCHITECTURE.md` under Skill Invocation as a precedent for future skill-to-skill calls.

2. **"Existing tests pass without modification" vs. the enumeration cases.** Five `tests/jimconf.sh` cases enumerate every key — `case_no_config_returns_defaults` (`:39–58`), `case_full_config_returns_overrides` (`:62–84`), `case_list_outputs_all_keys` (`:106–124`, line-count `"10"`), `case_keys_outputs_valid_keys` (`:127–133`), `case_malformed_lines_are_ignored` (`:154–170`, line-count `"10"` at `:169`). All five will fail the moment `auto_arch_feedback` enters `KEYS` unless extended. Both ACs apply ("existing tests pass without modification" and the new-key extensions). Suggest clarifying: enumeration cases are *extended* (same shape, more rows), not *modified* in semantics. Otherwise the two ACs read contradictorily.

3. **"Dispatcher contract" AC may be redundant.** Spec asks for a test where "a sample `auto_*` key resolves through the flag-prefix path… parallel to the existing `require_*` cases." Since `auto_arch_feedback` is the only `auto_*` key, the per-key `case_auto_arch_feedback_*` tests already exercise the dispatch branch end-to-end. Suggest collapsing: either treat the per-key tests as the dispatcher contract, or call out that an additional synthetic `auto_*` fixture key isn't desired (pollutes production `KEYS`).

**For Architect — plan invalidation signals**

- No existing `plan.md` to invalidate. N/A on that front.
- ~~Piggyback note~~: *Resolved 2026-05-12.* Spec 011 was reopened (Task 24) to migrate `skills/arch/SKILL.md:41–47` to the lean form. Spec 013's plan does not need to fold this in.

## Alignment

- **VISION.md:** Aligned. The arch-feedback loop serves Phase 1/2 (Core SDLC + Research and Refinement) by closing the silent-drift gap between code changes and the architecture document downstream skills enforce as a locked constraint. Reinforces the "spec/research/plan archive becomes a go-to reference" success signal.
- **ARCHITECTURE.md:** Aligned. Extends two existing conventions (flag-prefix dispatcher, post-011 directive vocabulary) without inventing new ones. Out-of-Scope explicitly forecloses a third prefix family. Honors the Bash-vs-Prompt decision rule — the value lookup is deterministic bash; the gate semantics live in the prompt where the human-in-the-loop trade-off is decidable.
- **Progressive Disclosure budget.** Build grows ~10 lines, arch ~5; both stay under the 500-line cap (current: 133 / 95).
- **Soft domain boundary.** `@coder` now invokes `/jim:arch` (architect's skill) from `/jim:build`. `ARCHITECTURE.md:239` already states `agent:` is documentation, not runtime routing — non-blocking, but worth one line in the plan's Constitution Check.
- No locked-constraint violations.
