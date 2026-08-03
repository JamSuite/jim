#!/usr/bin/env bash
#
# skills/spec/scripts/reconcile.sh — realize pending provisional spec
#   identities into real, coordinated ordinals. One-shot and previewed, in the
#   backfill.sh / migrate.sh family — it never runs automatically; a developer
#   invokes it explicitly, typically once a session that scoped specs offline
#   reaches the coordination point again.
#
# PURPOSE
#   A spec scoped while the coordination point was unreachable is bound to a
#   provisional identity whose ordinal slot carries a reserved prefix, and it
#   wears that identity as its directory name. This script finds those pending
#   directories, asks the allocator what real ordinal each becomes, and reports
#   the mapping.
#
#   Two things must agree before a directory is treated as a pending identity:
#   its basename must be the reserved form the allocator issues, and its own
#   spec.md frontmatter must claim the same identity. Either failing is a
#   warning and a skip, never a fatal stop — one unusable directory must not
#   strand every other pending spec. Directory names and frontmatter are
#   ordinary branch content, writable by anyone who can commit, so every token
#   crosses jimfile.sh's boundary before it reaches the allocator or a path.
#
# CLI SUMMARY
#   bash reconcile.sh [<specs_dir>]
#     PREVIEW (read-only): list pending provisional identities and the real
#     ordinal each would take. Mutates nothing.
#   bash reconcile.sh --apply [<specs_dir>]
#     APPLY: realize through the allocator, then rename each directory onto its
#     ordinal — git mv when tracked (crossing parent groups when the registry
#     answers under a different one), a plain move when not — and rewrite the
#     frontmatter id. Runs from the worktree top only; anywhere else is refused,
#     because every path it resolves is relative to the current directory.
#   bash reconcile.sh -c <config> [...]
#     Forward -c to jimfile.sh / jimconf.sh / jimalloc.sh (used by tests).
#   specs_dir default: jimconf.sh get specs
#
#   The preview keeps the allocator's state column. An identity the registry
#   already holds reads "have" — which is how a resumed run looks, and equally
#   how two specs keying alike look, so it is the developer's tell rather than
#   something to hide.
#
# EXIT CODES
#   0  Success (including the nothing-pending no-op).
#   1  IO failure, or jimalloc.sh reconcile spec halts.
#   2  Malformed invocation (unknown option).
#
# Line-oriented only; never sources or evals a spec file.

set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMFILE="$(cd "$HERE/../../file/scripts" && pwd)/jimfile.sh"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
JIMALLOC="$(dirname "$JIMFILE")/jimalloc.sh"
JIMLEDGER="$(cd "$HERE/../../ledger/scripts" && pwd)/jimledger.sh"

# The reserved prefix a provisional identity's ordinal slot carries. The grammar
# belongs to the allocator; it is named here because a spec bound offline wears
# it as a directory name and this scan has to recognize one.
readonly PROV_PREFIX="P-"

CFG=""   # optional jimconf override path, forwarded to jimfile/jimconf/jimalloc

# jf / jc / ja <args...> — invoke jimfile.sh / jimconf.sh / jimalloc.sh,
# forwarding -c when set.
jf() { if [[ -n "$CFG" ]]; then bash "$JIMFILE" -c "$CFG" "$@"; else bash "$JIMFILE" "$@"; fi; }
jc() { if [[ -n "$CFG" ]]; then bash "$JIMCONF" -c "$CFG" "$@"; else bash "$JIMCONF" "$@"; fi; }
ja() { if [[ -n "$CFG" ]]; then bash "$JIMALLOC" -c "$CFG" "$@"; else bash "$JIMALLOC" "$@"; fi; }

# resolve_specs_dir <arg> — arg if non-empty, else the jimconf default; strip a
# trailing slash.
resolve_specs_dir() {
  local dir="${1:-}"
  [[ -z "$dir" ]] && dir="$(jc get specs 2>/dev/null)"
  dir="${dir%/}"
  if [[ -z "$dir" ]]; then
    echo "error: specs dir is empty" >&2
    return 2
  fi
  printf '%s\n' "$dir"
}

# field_value <file> <field> — the value of <field> inside the file's LEADING
# frontmatter block, quotes stripped; empty when there is no leading block or it
# does not carry the field.
#
# Detection reads the SAME region the rewrite writes. Scanning the whole file
# instead makes a body line that happens to read "id:" decide that a directory
# is pending, and the rewrite then cannot touch it — a rename with no
# frontmatter change behind it. The opening line must be exactly "---": a CRLF
# "---\r" is not a frontmatter open here, so such a file is simply not pending,
# which is the fail-safe direction. Mirrors the issue-side realizer.
field_value() {
  awk -v f="$2" '
    NR == 1 { if ($0 != "---") exit; fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, f ":") == 1 {
      v = substr($0, length(f) + 2)
      sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v)
      sub(/^"/, "", v); sub(/"$/, "", v)
      print v; exit
    }
  ' "$1" 2>/dev/null
}

# prov_id_boundary <token> — the id boundary as is_prov_token's shared body
# reaches it. Local adapter: this script crosses the boundary through
# jimfile.sh, whose rejection message is noise on what is only a shape probe.
prov_id_boundary() { jf valid-id "$1" >/dev/null 2>&1; }

# is_prov_token <token>
#   Exit 0 iff <token> is the reserved provisional ordinal form the allocator
#   issues: the prefix, then an 8-digit issuance date, then a slug, with the
#   post-prefix body AND the slug alone each carried through the id boundary.
#   The full grammar is checked here, not just the prefix, so a malformed
#   directory is skipped with a warning instead of halting the batch when the
#   allocator rejects it.
#
#   SYNC: the function body below is mirrored verbatim in
#   skills/file/scripts/jimfile.sh and skills/file/scripts/jimalloc.sh. A
#   tests/jimfile.sh case asserts the three copies are byte-identical — keep
#   them in lockstep when editing. Each script supplies its own PROV_PREFIX and
#   prov_id_boundary; the grammar itself lives entirely in the body.
is_prov_token() {
  local token="$1" body date slug
  [[ "$token" == "$PROV_PREFIX"* ]] || return 1
  body="${token#"$PROV_PREFIX"}"
  [[ -n "$body" ]] || return 1
  date="${body%%-*}"; slug="${body#*-}"
  [[ "$date" =~ ^[0-9]{8}$ ]] || return 1
  [[ -n "$slug" && "$slug" != "$body" ]] || return 1
  prov_id_boundary "$body" || return 1
  prov_id_boundary "$slug"
}

# scan_pending <specs_dir> — emit one row per pending provisional spec dir:
# "<group>/<basename>\t<dir>". A directory qualifies only when its basename is
# the reserved form AND its own spec.md frontmatter claims that same identity;
# anything else warns on stderr and is skipped, never fed to the allocator and
# never composed into a path.
scan_pending() {
  local root="$1" gdir group entry base specmd id
  for gdir in "$root"/*/; do
    [[ -d "$gdir" ]] || continue
    group="$(basename "$gdir")"
    if ! jf valid-id "$group" >/dev/null 2>&1; then
      echo "warning: $group — group name failed validation; skipped" >&2
      continue
    fi
    for entry in "$gdir$PROV_PREFIX"*/; do
      [[ -d "$entry" ]] || continue
      base="$(basename "$entry")"
      if ! is_prov_token "$base"; then
        echo "warning: $group/$base — not a provisional identity the allocator issues; skipped" >&2
        continue
      fi
      specmd="${entry%/}/spec.md"
      if [[ ! -f "$specmd" ]]; then
        echo "warning: $group/$base — no spec.md to corroborate the identity; skipped" >&2
        continue
      fi
      id="$(field_value "$specmd" id)"
      if [[ "$id" != "$base" ]]; then
        echo "warning: $group/$base — frontmatter id '$id' disagrees with the directory; skipped" >&2
        continue
      fi
      printf '%s/%s\t%s\n' "$group" "$base" "${entry%/}"
    done
  done
}

# realize_mapping <apply-flag> <pending-rows> — feed the pending identities to
# `jimalloc.sh reconcile spec` (preview or --apply per <apply-flag>) and print
# its mapping verbatim, all three fields. The rows carry identities scan_pending
# already validated; this composes no path from them, only the stdin the
# allocator expects.
realize_mapping() {
  local apply="$1" rows="$2" ids
  [[ -n "$rows" ]] || return 0
  ids="$(printf '%s\n' "$rows" | cut -f1)"
  if (( apply )); then
    printf '%s\n' "$ids" | ja reconcile spec --apply
  else
    printf '%s\n' "$ids" | ja reconcile spec
  fi
}

# is_tracked <path> — exit 0 iff git already tracks <path>. The path is handed
# to git literally, so pathspec magic is never interpreted.
is_tracked() {
  [[ -n "$(git --literal-pathspecs ls-files -- "$1" 2>/dev/null)" ]]
}

# worktree_top — print the worktree's top directory, normalized. rc 1 outside a
# git tree.
#
# One resolver for both callers — the sweep's containment bound and --apply's
# spelling gate — so the two sides of a containment comparison cannot drift into
# different forms.
#
# The `realpath` is belt-and-braces, not a fix: `git rev-parse --show-toplevel`
# already returns a symlink-resolved path, verified across a symlinked cwd, a
# linked worktree reached through a symlink, and GIT_WORK_TREE pointed at one.
# It is kept so the top is in the same form as every candidate this script
# resolves, which is what makes the comparison well-defined rather than
# incidentally true. Falls back to the raw top if realpath fails, since an empty
# top would fail every containment check open rather than closed.
worktree_top() {
  local t
  if ! t="$(git rev-parse --show-toplevel 2>/dev/null)" || [[ -z "$t" ]]; then
    return 1
  fi
  realpath -m -- "$t" 2>/dev/null || printf '%s\n' "$t"
}

# rewrite_id <file> <new-id> [<prov-token>] [<new-group>] — print <file> with its
# self-identity sites realized: the id: field inside the leading frontmatter
# block replaced by <new-id>, the group: field replaced by <new-group> when one
# is given (a realization that crosses parent groups moves both), and — when
# <prov-token> is given — the first
# body heading whose leading token is exactly that identity's own
# ("# <prov-token> <title>", the shape the spec template composes) retitled
# onto the ordinal. A body line that happens to read "id:" sits outside the
# frontmatter block and is never matched — the same region field_value reads.
#
# The heading arm stays narrow on purpose: a bare provisional token is
# ambiguous everywhere except the spec's own first heading, so the global
# citation sweep never touches the bare form and this is the one place it is
# rewritten. The token match is whole-word — a sibling identity differing by a
# suffix does not match — and the heading is optional: its absence is not a
# failure.
#
# rc 0 when the id: field was actually replaced, rc 1 when it was not: a
# rewrite that changed nothing, behind a directory this run just renamed, is
# that identity's failure and not a silent success.
rewrite_id() {
  local file="$1" newid="$2" tok="${3:-}" newgroup="${4:-}"
  awk -v n="$newid" -v tok="$tok" -v g="$newgroup" '
    NR == 1 && $0 == "---" { fm = 1; print; next }
    NR == 1                { nofm = 1 }
    !nofm && fm == 1 && $0 == "---" { fm = 2 }
    !nofm && fm == 1 && index($0, "id:") == 1 && !done {
      print "id: \"" n "\""; done = 1; next
    }
    # The group field is rewritten on EVERY realization, not only when the group
    # moved: a spec that keeps claiming the name it was scoped under is drift the
    # moment anything reads the frontmatter instead of the path.
    g != "" && !nofm && fm == 1 && index($0, "group:") == 1 && !gdone {
      print "group: \"" g "\""; gdone = 1; next
    }
    tok != "" && !h1done && (nofm || fm == 2) && index($0, "# " tok) == 1 {
      rest = substr($0, length("# " tok) + 1)
      if (rest == "" || substr(rest, 1, 1) == " ") {
        print "# " n rest; h1done = 1; next
      }
    }
    { print }
    END { exit (done ? 0 : 1) }
  ' "$file"
}

# apply_pending <specs_dir> <pending-rows> <mapping>
#   Rename each realized identity's directory onto its ordinal and rewrite the
#   spec's frontmatter id and group. A tracked directory moves history-continuously
#   through a ledger git primitive — the sibling-constrained one within a group,
#   the cross-parent one when the registry answers under a different group — and
#   an untracked directory within its own group moves plainly, so realization
#   never asks the developer to change when they commit.
#
#   An identity halts — loudly, with nothing applied for it, and the whole run
#   ending non-zero — when the allocator refused it as `blocked` (a registry
#   claiming its key twice), when the realized ordinal is not one a spec
#   directory can carry, when that ordinal is already held by a directory in
#   the group, when the answered group name is not one this system can use, or
#   when the answered group differs and the directory is untracked (no history
#   to carry, and the cross-parent primitive is tracked-only by construction —
#   the remedy is named, and it is the one halt whose remedy is to commit and
#   re-run). The ordinal comes from a push-writable coordination point, so
#   it is revalidated before it becomes a path, a glob, a git argument, or
#   frontmatter. The latter two are registry-vs-tree drift, and a spec ordinal is
#   path identity: there is no silent suffixing and no overwrite, and repairing
#   the drift is not this script's business. Other identities in the batch are
#   unaffected — their ordinals are already durable.
#
#   Prints one "REALIZED <identity> <dir>" line per directory renamed.
apply_pending() {
  local root="$1" rows="$2" mapping="$3"
  local pend dir real group newgroup base body slug ord target held held_rc spec tmp
  local failed=0
  while IFS=$'\t' read -r pend dir; do
    [[ -n "$pend" ]] || continue
    real="$(awk -F'\t' -v k="$pend" '$1==k{print $2; exit}' <<<"$mapping")"
    [[ -n "$real" ]] || continue
    # A blocked row carries no ordinal: the registry claims this identity's
    # (group, slug, date) key twice, and the allocator refused to pick a winner.
    # Loud, per-identity, nothing applied — the neighbours still land.
    if [[ "$(awk -F'\t' -v k="$pend" '$1==k{print $3; exit}' <<<"$mapping")" == blocked ]]; then
      echo "error: $pend — realization blocked: the registry claims this identity's key twice (see the allocator's report); nothing applied for this identity" >&2
      failed=1; continue
    fi
    group="${pend%/*}"; base="${pend##*/}"
    # The registry may answer under a DIFFERENT group than the identity was
    # issued under — the group was renamed while this spec sat pending offline.
    # That is a cross-parent move, not a refusal: the identity belongs where the
    # registry says it does, and asking the developer to hand-move it is the
    # manual surgery realization exists to avoid.
    newgroup="${real%/*}"
    if ! jf valid-id "$newgroup" >/dev/null 2>&1; then
      echo "error: $pend — the registry answers under group '$newgroup', which is not a usable group name; nothing applied for this identity" >&2
      failed=1; continue
    fi
    ord="${real##*/}"
    # The realized ordinal is registry-derived, and the coordination branch is
    # push-writable — so it crosses the id boundary like every other untrusted
    # token, BEFORE it becomes a path component, a glob, a git argument, or
    # frontmatter. A non-conforming ordinal halts this identity and writes
    # nothing for it.
    if [[ ! "$ord" =~ ^[0-9]{3,15}$ ]]; then
      echo "error: $pend — the registry answers with ordinal '$ord', which is not an ordinal a spec directory can carry; nothing applied for this identity" >&2
      failed=1; continue
    fi
    body="${base#"$PROV_PREFIX"}"
    slug="${body#*-}"
    target="$root/$newgroup/$ord-$slug"
    # Occupancy through the same predicate the rename verbs enforce, so the
    # realize path and the creation path cannot disagree about what an ordinal
    # is. The tracked branch needs it here in its own right: rename-tracked
    # gates the new basename's shape, not the ordinal's occupancy.
    #
    # --root makes the gate read the tree it is about to write into rather than
    # the configured specs dir. The two cannot diverge today — the apply gate
    # refuses a <specs_dir> argument that does not resolve to the configured one
    # — so this is defense in depth, not a live fix. It is here because the gate
    # should not silently depend on a refusal held elsewhere for its own
    # reasons, and because the sibling caller in jimledger.sh already passes it.
    held="$(jf spec-ordinal-holder "$newgroup" "$ord" --root "$root")"; held_rc=$?
    if (( held_rc == 0 )); then
      echo "error: $pend — realized ordinal $real is already held by '$held' (registry-vs-tree drift); nothing applied for this identity" >&2
      failed=1; continue
    fi
    if (( held_rc != 1 )); then
      echo "error: $pend — could not decide whether ordinal $real is free; nothing applied for this identity" >&2
      failed=1; continue
    fi
    if is_tracked "$dir"; then
      if [[ "$newgroup" == "$group" ]]; then
        if ! bash "$JIMLEDGER" rename-tracked "$dir" "$target"; then
          echo "error: $pend — tracked rename to '$target' failed" >&2
          failed=1; continue
        fi
      elif ! bash "$JIMLEDGER" move-spec-dir "$root" "$group" "$base" "$newgroup" "$ord-$slug"; then
        echo "error: $pend — cross-group move to '$target' failed" >&2
        failed=1; continue
      fi
    elif [[ "$newgroup" != "$group" ]]; then
      # An untracked directory has no history to carry across parents, and the
      # cross-parent primitive is tracked-only by construction. Naming the
      # remedy beats a plain move that loses the continuity the tracked case
      # gets for free.
      echo "error: $pend — the registry answers under group '$newgroup', but the directory is untracked; commit the directory first, then re-run" >&2
      failed=1; continue
    else
      if ! jf mv-spec-id "$group" "$base" "$ord" "$slug" >/dev/null; then
        echo "error: $pend — rename to '$target' failed" >&2
        failed=1; continue
      fi
    fi
    # Past this point the directory HAS moved, so the REALIZED line is emitted
    # whatever the frontmatter rewrite does. That line is what puts this identity
    # into the remap, and the remap is what sweeps the citations the move just
    # made dead and records the mapping on the ledger. Dropping it on a rewrite
    # failure leaves a moved directory that nothing points at and nothing
    # recorded. The run still fails, and the message names what to repair.
    spec="$target/spec.md"
    if [[ -f "$spec" ]]; then
      if ! tmp="$(mktemp "$target/.reconcile.tmp.XXXXXX")"; then
        echo "error: cannot create tmp file in '$target'" >&2
        failed=1
      elif rewrite_id "$spec" "$ord" "$base" "$newgroup" > "$tmp" && mv "$tmp" "$spec"; then
        :
      else
        rm -f "$tmp"
        echo "error: $pend — frontmatter rewrite failed for '$spec'; the directory is renamed and its id still reads provisional" >&2
        failed=1
      fi
    fi
    printf 'REALIZED %s %s\n' "$pend" "$target"
  done <<<"$rows"
  return "$failed"
}

# build_remap <applied-lines> <mapping>
#   Turn the identities apply_pending actually renamed into the sweep's
#   whitelist, one row per identity:
#     "<old-group>/P-<token>\t<new-group>/<NNN>\t<new-group>/<NNN>-<slug>"
#   the second field being how the identity is written as a typed reference and
#   the third how it is written inside a path. The source group is the one the
#   identity was issued under and the destination group the one the registry
#   answered with; they differ on a realization that crossed parents. An
#   identity that halted is
#   absent, so the sweep cannot rewrite a citation of a spec that did not move.
build_remap() {
  local applied="$1" mapping="$2"
  local pend real ord slug body
  [[ -n "$applied" ]] || return 0
  while read -r _ pend _; do
    [[ -n "$pend" ]] || continue
    real="$(awk -F'\t' -v k="$pend" '$1==k{print $2; exit}' <<<"$mapping")"
    [[ -n "$real" ]] || continue
    ord="${real##*/}"
    body="${pend##*/}"; body="${body#"$PROV_PREFIX"}"
    slug="${body#*-}"
    printf '%s\t%s\t%s-%s\n' "$pend" "$real" "$real" "$slug"
  done <<<"$applied"
}

# sweep_citations <remap-rows> [<realized-dirs>]
#   Rewrite in-tree citations of each realized identity across the four roots a
#   citation can live in — specs, issues, brainstorms, debug — over the tracked
#   and untracked-but-not-ignored markdown in each, plus the realized
#   directories' own markdown. The remap IS the whitelist: only an identity
#   that actually moved is ever rewritten, so a reference to an unrelated spec
#   cannot be touched by construction.
#
#   The match is whole-token: the character before the identity is not
#   [a-z0-9-] and the character after is not [a-z0-9-] either. Excluding the
#   trailing dash matters here in a way it does not for a real ordinal — two
#   specs scoped the same day under the same title differ only by a "-2" suffix,
#   and the shorter identity must not match inside the longer one.
#
#   How an identity is written decides what replaces it: with a slash on EITHER
#   side it is part of a path and takes the realized directory name, slug
#   included; anywhere else it is a typed reference and takes the bare ordinal.
#   Both sides matter — the source token consumes the whole slug, so a path whose
#   group is the first segment has a slash only after it, and taking the bare
#   ordinal there would leave a dead link. Fenced blocks are skipped — a citation
#   quoted inside one is verbatim material, not a live reference.
#
#   Guards run over EVERY target before ANY edit: each path clears the relpath
#   boundary and resolves inside the worktree. Output is location-only — file,
#   line, and which form matched — never the content of the line. The issue
#   index is regenerated once, and only when an issue file actually changed; a
#   regeneration that fails is reported and fails the sweep, since the citations
#   are already rewritten and INDEX.md no longer describes them.
sweep_citations() {
  local remap="$1" own_dirs="${2:-}"
  [[ -n "$remap" ]] || return 0
  # Declared here, not at the rewrite loop below: the root-resolution pass drops
  # roots and must be able to fail the sweep, and a later `local … =0` would
  # reset whatever it recorded.
  local sweep_failed=0
  local top
  if ! top="$(worktree_top)"; then
    echo "error: citation sweep — not in a git repo" >&2
    return 1
  fi
  # `git ls-files` emits repo-relative paths whatever spelling the pathspec
  # carries, so a root consumed in its raw configured form can never prefix-match
  # its own output — which is how an absolute issues root rewrote citations and
  # then never regenerated the index. A root outside the worktree is worse than
  # useless: git rejects the whole pathspec set over it, not just that one entry.
  # Normalize every root to its worktree-relative form once, here, and drop one
  # that does not resolve inside the worktree rather than sweeping nothing at all.
  local -a roots=() files=()
  local key root rp issues_root=""
  for key in specs issues brainstorms debug; do
    root="$(jc get "$key" 2>/dev/null)"; root="${root%/}"; root="${root#./}"
    [[ -n "$root" ]] || continue
    # A dropped root means some citations are rewritten and others are not, and
    # the issue index is never regenerated for the dropped one. That is a partial
    # sweep, so it fails the run — the caller cannot see it any other way.
    if ! rp="$(realpath -m -- "$root" 2>/dev/null)" || [[ -z "$rp" ]]; then
      echo "warning: citation sweep — cannot resolve the configured '$key' root ('$root'); not swept" >&2
      sweep_failed=1
      continue
    fi
    if [[ "$rp" == "$top" ]]; then
      root="."
    elif [[ "$rp" == "$top"/* ]]; then
      root="${rp#"$top"/}"
    else
      echo "warning: citation sweep — the configured '$key' root ('$root') resolves outside the worktree; not swept" >&2
      sweep_failed=1
      continue
    fi
    roots+=("$root")
    [[ "$key" == issues ]] && issues_root="$root"
  done
  # Every root dropped: nothing was swept, and the drops already recorded why.
  # Defensive — the specs root has to resolve for --apply to reach this at all,
  # so no CLI path leaves this set empty. It carries the failure out regardless,
  # rather than making the early return a second way to report a clean sweep.
  (( ${#roots[@]} )) || return "$sweep_failed"
  mapfile -t files < <(git --literal-pathspecs ls-files -- "${roots[@]}" 2>/dev/null | grep -E '\.md$')

  # Untracked-but-not-ignored files are part of the content set too: artifacts
  # created while the coordination point was unreachable are exactly the files
  # most likely to be uncommitted when realize runs, and a tracked-only sweep
  # leaves their citations stale — then the index regeneration below rebuilds
  # from the unrewritten source and resurrects a citation this run just
  # retired. Same symlink discipline as the realized-directory enumeration:
  # untracked content is shapeable in ways tracked content is not, a symlink is
  # never a citation's home, and one that escapes the worktree is refused
  # before any temp state exists.
  local u u_rp
  while IFS= read -r u; do
    [[ -n "$u" ]] || continue
    if [[ -L "$u" ]]; then
      if ! u_rp="$(realpath -m -- "$u" 2>/dev/null)" || [[ -z "$u_rp" ]] \
         || { [[ "$u_rp" != "$top" && "$u_rp" != "$top"/* ]]; }; then
        echo "error: citation sweep — path escapes worktree: $u" >&2; return 1
      fi
      continue
    fi
    [[ -f "$u" ]] || continue
    files+=("$u")
  done < <(git --literal-pathspecs ls-files --others --exclude-standard -- "${roots[@]}" 2>/dev/null | grep -E '\.md$')

  # A directory realized while still uncommitted is invisible to git, so its own
  # body would keep citing the identity it just left. Enumerate the realized
  # directories' own markdown — those directories only, never a whole-tree
  # untracked scan — and merge it in. Every path added here goes through the same
  # relpath boundary and worktree containment as the tracked targets below,
  # before any edit: an untracked directory is shapeable in ways tracked content
  # is not, so it must not be able to direct a rewrite out of the worktree.
  local d entry ent_rp
  if [[ -n "$own_dirs" ]]; then
    while IFS= read -r d; do
      [[ -n "$d" && -d "$d" ]] || continue
      for entry in "$d"/*.md; do
        # This enumeration drops the tracked-ness guard by necessity — the
        # directory is untracked, which is why it is here at all. A symlink is
        # then the one way a write can leave the four content roots, since `>`
        # follows it to its target, and containment alone does not object to an
        # in-worktree one. A symlink is never a spec's own body, so it is not
        # swept. One that leaves the worktree entirely is not merely out of
        # scope, it is anomalous — refuse, before any temp state exists.
        if [[ -L "$entry" ]]; then
          if ! ent_rp="$(realpath -m -- "$entry" 2>/dev/null)" || [[ -z "$ent_rp" ]] \
             || { [[ "$ent_rp" != "$top" && "$ent_rp" != "$top"/* ]]; }; then
            echo "error: citation sweep — path escapes worktree: $entry" >&2; return 1
          fi
          continue
        fi
        [[ -f "$entry" ]] || continue
        files+=("$entry")
      done
    done <<<"$own_dirs"
  fi
  (( ${#files[@]} )) || return 0

  local f resolved
  local -A seen_file=()
  local -a unique=()
  for f in "${files[@]}"; do
    [[ -n "${seen_file[$f]:-}" ]] && continue
    seen_file["$f"]=1
    unique+=("$f")
  done
  files=("${unique[@]}")

  for f in "${files[@]}"; do
    if ! jf valid-relpath "$f" >/dev/null 2>&1; then
      echo "error: citation sweep — unsafe path rejected: $f" >&2; return 1
    fi
    if ! resolved="$(realpath -m -- "$f" 2>/dev/null)" || [[ "$resolved" != "$top"/* ]]; then
      echo "error: citation sweep — path escapes worktree: $f" >&2; return 1
    fi
  done

  local swtmp parsed tmp_out rec awk_rc issue_touched=0
  if ! swtmp="$(mktemp -d 2>/dev/null)"; then
    echo "error: citation sweep — cannot create temp dir" >&2; return 1
  fi
  parsed="$swtmp/remap"; tmp_out="$swtmp/out"; rec="$swtmp/rec"
  printf '%s\n' "$remap" > "$parsed"
  for f in "${files[@]}"; do
    : > "$rec"
    awk -F'\t' -v file="$f" -v recfile="$rec" '
      BEGIN { rf = ARGV[1] }
      FILENAME == rf { SRC[FNR] = $1; TYPED[FNR] = $2; PATHED[FNR] = $3; nmap = FNR; next }
      {
        line = $0
        # Fence tracking records the OPENING marker and closes only on a run of
        # the same character at least as long, with nothing but whitespace after
        # it. A boolean toggle instead lets an inner 3-backtick fence close a
        # 4-backtick block (rewriting quoted material) and lets a tilde line
        # close a backtick block — after which every later marker is mis-paired
        # and the rest of the file is skipped. Same semantics as the scanner in
        # the issue index.
        probe = line
        sub(/^[[:space:]]*/, "", probe)
        if (!in_fence) {
          first = substr(probe, 1, 1)
          if (first == "`" || first == "~") {
            n = 0
            while (substr(probe, n + 1, 1) == first) n++
            if (n >= 3) {
              in_fence = 1; fence_char = first; fence_len = n
              print; next
            }
          }
        } else {
          n = 0
          while (substr(probe, n + 1, 1) == fence_char) n++
          if (n >= fence_len) {
            rest = substr(probe, n + 1)
            sub(/[[:space:]]*$/, "", rest)
            if (rest == "") { in_fence = 0 }
          }
          print; next
        }
        out = ""; i = 1; L = length(line)
        while (i <= L) {
          matched = 0
          for (m = 1; m <= nmap; m++) {
            s = SRC[m]; sl = length(s)
            if (substr(line, i, sl) == s) {
              before = (i > 1) ? substr(line, i - 1, 1) : ""
              ap = i + sl; after = (ap <= L) ? substr(line, ap, 1) : ""
              if (before !~ /[a-z0-9-]/ && after !~ /[a-z0-9-]/) {
                if (before == "/" || after == "/") {
                  out = out PATHED[m]
                  print "REWROTE\t" file "\t" FNR "\tpath" > recfile
                } else {
                  out = out TYPED[m]
                  print "REWROTE\t" file "\t" FNR "\ttyped-ref" > recfile
                }
                i += sl; matched = 1; break
              }
            }
          }
          if (!matched) { out = out substr(line, i, 1); i++ }
        }
        print out
      }' "$parsed" "$f" > "$tmp_out"
    # A rewrite that died partway through has already written whatever records it
    # got to, so a non-empty record file is NOT evidence the output is whole.
    # Install only on a clean exit; other files still sweep, and the run fails.
    awk_rc=$?
    if (( awk_rc != 0 )); then
      echo "error: citation sweep — the rewrite failed partway through '$f'; nothing installed for it" >&2
      sweep_failed=1
      continue
    fi
    if [[ -s "$rec" ]]; then
      # The awk guard above covers the producer; this covers the consumer. A
      # read-only target or a full disk fails here, and reporting REWROTE for a
      # rewrite that did not land — or worse, for one that landed truncated — is
      # the same lie one step later in the pipeline.
      if ! cat -- "$tmp_out" > "$f"; then
        echo "error: citation sweep — could not install the rewrite of '$f'; it may be partially written" >&2
        sweep_failed=1
        continue
      fi
      cat -- "$rec"
      if [[ -n "$issues_root" ]] \
         && { [[ "$issues_root" == "." ]] || [[ "$f" == "$issues_root"/* ]]; }; then
        issue_touched=1
      fi
    fi
  done
  rm -rf -- "$swtmp"

  if (( issue_touched )); then
    if ! bash "$HERE/../../issue/scripts/index.sh" "$issues_root" >/dev/null 2>&1; then
      echo "error: citation sweep — the issue index failed to regenerate for '$issues_root'; the rewritten citations are on disk and INDEX.md no longer describes them" >&2
      return 1
    fi
  fi
  return "$sweep_failed"
}

# record_realized <specs_dir> <remap-rows>
#   Append one `spec realized` event to the SPECS-ROOT ledger carrying the
#   provisional→real mapping in the same moved= grammar the partition operations
#   use. Recording it durably is what lets a citation frozen while the spec was
#   provisional stay traceable, and lets the rename-emitting follow-on lift the
#   mapping into registry redirect records without re-deriving anything.
#
#   Every element is charset-gated immediately before it is appended. The ledger
#   append writes whatever it is handed, so composing the value out of tokens
#   re-checked at this boundary is what keeps a crafted directory name from
#   reaching the record. The mapping is chunked at element boundaries rather
#   than truncated, so a large batch stays wholly recorded.
#
#   This grammar is NARROWER than the scan's id boundary, so a row can arrive
#   here already renamed and still be unrecordable. That row is dropped from the
#   record — but loudly, naming the mapping and failing the run: the durable
#   record is what keeps a citation frozen while the spec was provisional
#   traceable, so losing one silently at exit 0 is the wrong failure mode. Other
#   rows in the batch record normally.
#
#   The phase token sits outside the measured stage set on purpose — realization
#   is not a stage. It raises no group's high-water either: the registry records
#   a realization under its own verb rather than as a rename, so the fold that
#   counts consumed ordinals never sees it. A provisional never held a real
#   ordinal, so it vacates nothing.
record_realized() {
  local root="$1" remap="$2"
  [[ -n "$remap" ]] || return 0
  local pend real elem cand cur="" failed=0
  local -a tokens=()
  while IFS=$'\t' read -r pend real _; do
    [[ -n "$pend" && -n "$real" ]] || continue
    if [[ ! "$pend" =~ ^[a-z0-9][a-z0-9-]*/P-[0-9]{8}-[a-z0-9][a-z0-9-]*$ ]] \
       || [[ ! "$real" =~ ^[a-z0-9][a-z0-9-]*/[0-9]{3,15}$ ]]; then
      echo "warning: $pend → $real — the mapping does not clear the record boundary; this realization is NOT in the durable record" >&2
      failed=1; continue
    fi
    elem="$pend:$real"
    if [[ -z "$cur" ]]; then cand="moved=$elem"; else cand="$cur,$elem"; fi
    if (( ${#cand} > 256 )) && [[ -n "$cur" ]]; then
      tokens+=("$cur")
      cur="moved=$elem"
    else
      cur="$cand"
    fi
  done <<<"$remap"
  [[ -n "$cur" ]] && tokens+=("$cur")
  (( ${#tokens[@]} )) || return "$failed"
  bash "$JIMLEDGER" event "$root" spec realized "${tokens[@]}" || failed=1
  return "$failed"
}

cmd_reconcile() {
  local dir="" apply=0
  while (( $# )); do
    case "$1" in
      --apply) apply=1; shift ;;
      -*) echo "error: unknown option '$1'" >&2; return 2 ;;
      *)  dir="$1"; shift ;;
    esac
  done
  dir="$(resolve_specs_dir "$dir")" || return $?

  # The uncommitted-case rename composes its target from the CONFIGURED specs
  # dir, so applying into a tree other than the one just scanned would move a
  # directory nobody asked about. Refuse rather than guess — and settle on ONE
  # spelling before anything is scanned, because the tracked branch takes
  # worktree-relative paths and the untracked branch composes from config: an
  # absolute configured spelling would otherwise make one branch work and the
  # other refuse, within a single run.
  if (( apply )); then
    local cfg_dir top here rp_cfg rp_dir
    if ! top="$(worktree_top)"; then
      echo "error: --apply must run inside a git repo" >&2
      return 1
    fi
    # Every path this step resolves — the configured specs dir, the tracked
    # rename's arguments, the sweep's targets — is relative to the CURRENT
    # directory, and jimconf reads ./jimconf.toml from there with no walk-up. The
    # worktree top is the only directory where the configured spelling and its
    # consumers agree; the relative form derived below is worktree-relative and
    # means something else anywhere but there. Refuse, rather than resolve a
    # directory that does not exist and report nothing to realize at exit 0 —
    # from a subdirectory an absolute configured spelling still previews the
    # pending work this step would then silently discard.
    here="$(realpath -m -- . 2>/dev/null)"
    if [[ -z "$top" || -z "$here" || "$here" != "$top" ]]; then
      echo "error: --apply must run from the worktree top ('${top:-unresolved}')," \
           "not '${here:-unresolved}'" >&2
      return 1
    fi
    cfg_dir="$(jc get specs 2>/dev/null)"; cfg_dir="${cfg_dir%/}"
    rp_cfg="$(realpath -m -- "$cfg_dir" 2>/dev/null)"
    rp_dir="$(realpath -m -- "$dir" 2>/dev/null)"
    if [[ -z "$rp_cfg" || "$rp_cfg" != "$rp_dir" ]]; then
      echo "error: --apply operates on the configured specs dir ('$cfg_dir'), not '$dir'" >&2
      return 1
    fi
    if [[ "$rp_cfg" != "$top" && "$rp_cfg" != "$top"/* ]]; then
      echo "error: the configured specs dir ('$cfg_dir') resolves outside the worktree" >&2
      return 1
    fi
    dir="${rp_cfg#"$top"/}"
    [[ "$dir" == "$rp_cfg" ]] && dir="."
  fi

  if [[ ! -d "$dir" ]]; then
    printf 'reconcile: no pending provisional specs — nothing to realize.\n'
    return 0
  fi

  local rows
  rows="$(scan_pending "$dir")"
  if [[ -z "$rows" ]]; then
    printf 'reconcile: no pending provisional specs — nothing to realize.\n'
    return 0
  fi

  local mapping rc
  mapping="$(realize_mapping "$apply" "$rows")"; rc=$?
  (( rc == 0 )) || return "$rc"

  if [[ -z "$mapping" ]]; then
    printf 'reconcile: still offline — nothing changed.\n'
    return 0
  fi

  if (( apply )); then
    printf 'reconcile — %s\n\n' "$dir"
    printf '%s\n' "$mapping" | sed 's/^/  /'
    printf '\n'
    local applied arc remap own_dirs
    applied="$(apply_pending "$dir" "$rows" "$mapping")"; arc=$?
    [[ -n "$applied" ]] && printf '%s\n' "$applied"
    remap="$(build_remap "$applied" "$mapping")"
    own_dirs="$(printf '%s\n' "$applied" | awk '$1=="REALIZED"{print $3}')"
    sweep_citations "$remap" "$own_dirs" || arc=1
    record_realized "$dir" "$remap" || arc=1
    return "$arc"
  fi

  printf 'reconcile preview — %s\n\n' "$dir"
  printf '%s\n' "$mapping" | sed 's/^/  /'
  printf '\n%d pending.\n' "$(printf '%s\n' "$rows" | grep -c .)"
}

usage() {
  printf '%s\n' \
    'reconcile.sh — realize pending provisional spec identities into real ordinals.' \
    '' \
    '  bash reconcile.sh [<specs_dir>]' \
    '      Preview (read-only): list pending provisional identities and the real' \
    '      ordinal each would take. Mutates nothing.' \
    '' \
    '  bash reconcile.sh --apply [<specs_dir>]' \
    '      Apply: realize through the allocator, rename each directory onto its' \
    '      ordinal, and rewrite the frontmatter id. Worktree top only.' \
    '' \
    '  specs_dir default: jimconf.sh get specs'
}

main() {
  if [[ "${1:-}" == "-c" ]]; then
    [[ -n "${2:-}" ]] || { echo "error: -c requires a path argument" >&2; return 2; }
    CFG="$2"; shift 2
  fi
  case "${1:-}" in
    -h|--help|help) usage ;;
    *) cmd_reconcile "$@" ;;
  esac
}

main "$@"
