#!/usr/bin/env bash
#
# jim-deps-refs.sh — dependency-edge extractor for jim's own reference
# channels, feeding `jimpartition.sh ingest`.
#
# Jim is a markdown + bash plugin: its dependency graph lives in skill/agent
# cross-references, not imports, so the native import scan cannot see it.
# This adapter emits that graph on the ingest line contract —
#
#   <from-relpath> \t <to-relpath> \t <channel>
#
# one edge per line, endpoints repo-relative tracked files — over five
# deterministic channels:
#
#   skill-script    SKILL.md → a script it injects/runs
#                   (${CLAUDE_PLUGIN_ROOT}/skills/<s>/scripts/*.sh cross-skill
#                   refs and ${CLAUDE_SKILL_DIR}/scripts/*.sh own-skill refs)
#   bash-source     script → sibling script it composes with
#                   (BASH_SOURCE-relative ../<skill>/scripts resolution lines)
#   skill-invoke    SKILL.md / agent → a skill it invokes or preloads
#                   (Skill(jim:<name>) tokens and agent `skills:` frontmatter)
#   agent-dispatch  SKILL.md / agent → an agent it may spawn
#                   (structural Agent(...) tokens only; prose @jim:<name>
#                   persona mentions are deliberately not modeled)
#   test-ref        test file → the scripts it runs or sources
#                   (skills/*/scripts/*.sh path tokens in tests/*.sh)
#   doc-ref         SKILL.md / agent / test → a skill's references/ or assets/
#                   doc it cites (canonical-rule and template coupling)
#
# Targets that do not exist as files (e.g. built-in agents like Explore) are
# dropped here rather than left for ingest's untracked gate, so HYGIENE
# counts stay meaningful for real contract violations.
set -uo pipefail
export LC_ALL=C

# emit <from> <to> <channel> — one contract line; existing-file targets only,
# never a self-edge.
emit() {
  [[ -f "$2" && "$1" != "$2" ]] || return 0
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
}

skill_md_edges() {
  local f skill t name
  while IFS= read -r f; do
    skill="${f#skills/}"; skill="${skill%%/*}"
    while IFS= read -r t; do
      [[ -n "$t" ]] && emit "$f" "$t" skill-script
    done < <(grep -Eo 'CLAUDE_PLUGIN_ROOT./skills/[a-z-]+/scripts/[a-z_.-]+[.]sh' "$f" 2>/dev/null \
               | sed 's|^CLAUDE_PLUGIN_ROOT./||' | sort -u)
    while IFS= read -r name; do
      [[ -n "$name" ]] && emit "$f" "skills/$skill/scripts/$name" skill-script
    done < <(grep -Eo 'CLAUDE_SKILL_DIR./scripts/[a-z_.-]+[.]sh' "$f" 2>/dev/null \
               | sed 's|.*/||' | sort -u)
  done < <(git ls-files -- 'skills/*/SKILL.md')
}

script_edges() {
  local f line skill name
  while IFS= read -r f; do
    # Both composition idioms resolve relative to the script's own directory:
    # inline dirname-of-BASH_SOURCE, and a two-statement HERE= anchor whose
    # later lines carry only the ../<skill>/scripts hop — so the ../ hop plus
    # a script-name tail on one line is the signal, BASH_SOURCE need not be.
    while IFS= read -r line; do
      skill="$(printf '%s' "$line" | grep -Eo '\.\./[a-z-]+/scripts' | head -1 \
                 | sed 's|^\.\./||;s|/scripts$||')"
      name="$(printf '%s' "$line" | grep -Eo '(pwd\)"?|scripts)/[a-z_.-]+[.]sh' | head -1 \
                | sed 's|.*/||')"
      [[ -n "$skill" && -n "$name" ]] && emit "$f" "skills/$skill/scripts/$name" bash-source
    done < <(grep -E '\.\./[a-z-]+/scripts' "$f" 2>/dev/null)
  done < <(git ls-files -- 'skills/*/scripts/*.sh' 'tests/*.sh')
}

invoke_edges() {
  local f name
  while IFS= read -r f; do
    while IFS= read -r name; do
      [[ -n "$name" ]] && emit "$f" "skills/$name/SKILL.md" skill-invoke
    done < <(grep -Eo 'Skill\(jim:[a-z-]+' "$f" 2>/dev/null | sed 's/.*jim://' | sort -u)
  done < <(git ls-files -- 'skills/*/SKILL.md' 'agents/*.md')
  # Agent frontmatter `skills:` preloads full skill content at agent startup.
  while IFS= read -r f; do
    while IFS= read -r name; do
      [[ "$name" =~ ^[a-z][a-z-]*$ ]] && emit "$f" "skills/$name/SKILL.md" skill-invoke
    done < <(grep -E '^skills:' "$f" 2>/dev/null | sed 's/^skills:[[:space:]]*\[//;s/\].*//' \
               | tr ',' '\n' | tr -d '[:space:]')
  done < <(git ls-files -- 'agents/*.md')
}

dispatch_edges() {
  local f name
  while IFS= read -r f; do
    while IFS= read -r name; do
      name="${name#jim:}"
      [[ "$name" =~ ^[a-z][a-z-]*$ ]] && emit "$f" "agents/$name.md" agent-dispatch
    done < <(grep -Eo 'Agent\([^)]*\)' "$f" 2>/dev/null | sed 's/^Agent(//;s/)$//' \
               | tr ',' '\n' | tr -d ' ' | sort -u)
  done < <(git ls-files -- 'skills/*/SKILL.md' 'agents/*.md')
}

test_edges() {
  local f t
  while IFS= read -r f; do
    while IFS= read -r t; do
      [[ -n "$t" ]] && emit "$f" "$t" test-ref
    done < <(grep -Eo 'skills/[a-z-]+/scripts/[a-z_.-]+[.]sh' "$f" 2>/dev/null | sort -u)
  done < <(git ls-files -- 'tests/*.sh')
}

doc_ref_edges() {
  local f t
  while IFS= read -r f; do
    while IFS= read -r t; do
      [[ -n "$t" ]] && emit "$f" "$t" doc-ref
    done < <(grep -Eo 'skills/[a-z-]+/(references|assets)/[A-Za-z0-9._-]+[.]md' "$f" 2>/dev/null | sort -u)
  done < <(git ls-files -- 'skills/*/SKILL.md' 'agents/*.md' 'tests/*.sh')
}

main() {
  local repo
  repo="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "jim-deps-refs: not a git work tree" >&2; return 2
  }
  cd "$repo" || return 2
  { skill_md_edges; script_edges; invoke_edges; dispatch_edges; test_edges; doc_ref_edges; } | sort -u
}

main "$@"
