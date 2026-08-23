#!/usr/bin/env bash
#
# skills/issue/scripts/identity.sh — Resolve the contributor identity the
#   environment supplies, or refuse. The emitter records the result as an
#   issue's filer, and the transition verbs record it as an issue's holder, so
#   this is the one place that decides what counts as a recordable identity.
#
#   The form the value takes is the project's decision, not each contributor's:
#   `identity_scheme` selects it, and one collection therefore never holds
#   identities recorded under different rules.
#
# SECURITY MODEL
#   - The configured identity accepts embedded newlines and arbitrary bytes, so
#     an unchecked value can close the frontmatter it is written into and open
#     fields of its own. It is validated against a positively enumerated
#     character set: only that set is accepted, and everything outside it is
#     refused. Stating the set positively is what makes unanticipated input —
#     a Unicode line separator, a stray control byte — fail closed rather than
#     survive a list of characters someone thought to name.
#   - A refused value never appears in the refusal. Reasons are fixed strings,
#     so a terminal log cannot be made to carry the value that was rejected.
#   - The value is compared, never sourced or evaluated.
#
# USAGE
#   bash identity.sh resolve            # read the environment's identity
#   bash identity.sh validate <value>   # judge one already-obtained identity
#   bash identity.sh normalize <value>  # apply the project's form to one value
#
#   A leading `-c <config>` overrides the config the form is read from, the way
#   the migrations do. Production callers do not pass it; tests and a conversion
#   running under an explicit config do, so a run never reads the ambient
#   project's form when it was handed one.
#
#   `validate` exists because the environment is not the only source of a
#   recorded identity: the collection conversion recovers a historical filer
#   out of version-control history, and a value read from there is a recorded
#   identity exactly as a configured one is. Judging both here keeps one
#   definition of recordable rather than a second copy that can drift from it.
#
# EXIT CODES
#   0  resolved or accepted — the identity is on stdout
#   1  none configured, or an empty value to validate — nothing on stdout
#   2  present but not recordable, a usage error, or a configuration that
#      cannot select a form — nothing on stdout

set -uo pipefail

# Byte-exact ranges. Under any other collation the ranges below could admit
# characters beyond ASCII, which is the opposite of failing closed.
export LC_ALL=C

# The accepted set: broad enough for the addresses version control actually
# carries, including forge noreply forms like 1234+name@users.noreply.host, and
# bounded so anything else is refused rather than recorded. It excludes the
# quote and backslash that would otherwise escape the scalar this value is
# written into.
IDENTITY_CHARS='A-Za-z0-9._%+@-'

# Longest address the mail standards admit; a value beyond it is not one.
IDENTITY_MAX=254

# The closed set of forms. Ordered from least to most extracting: each records
# everything the one before it records, plus one further extraction.
IDENTITY_SCHEMES=(email github local)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
CFG=""   # optional jimconf override path, forwarded to jimconf

# jc <args...> — invoke jimconf.sh, forwarding -c when set.
jc() { if [[ -n "$CFG" ]]; then bash "$JIMCONF" -c "$CFG" "$@"; else bash "$JIMCONF" "$@"; fi; }

usage() {
  echo "usage: identity.sh [-c <config>] resolve" >&2
  echo "       identity.sh [-c <config>] validate <value>" >&2
  echo "       identity.sh [-c <config>] normalize <value>" >&2
}

# scheme — print the project's configured form, or refuse.
#   An absent setting takes the documented default, so a project that has
#   configured nothing still records identities. A value outside the closed set
#   is refused rather than treated as the default: a mistyped setting would
#   otherwise record every identity in the collection under a form the project
#   did not choose, on the strength of a message nobody has to read. A
#   resolution that failed rather than being absent is refused for the same
#   reason — a fabricated default is indistinguishable from a chosen one.
#
#   The refusal names the setting and the forms it accepts. It never carries an
#   identity value, and it does not echo the rejected setting either: naming
#   what is accepted is what makes it actionable.
scheme() {
  local value rc s
  value="$(jc get identity_scheme 2>/dev/null)"
  rc=$?
  if (( rc != 0 )); then
    echo "error: identity_scheme could not be resolved from the project config" >&2
    return 2
  fi
  for s in "${IDENTITY_SCHEMES[@]}"; do
    if [[ "$value" == "$s" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done
  echo "error: identity_scheme must be one of: ${IDENTITY_SCHEMES[*]}" >&2
  return 2
}

# validate <value> — print the value when it is recordable, else refuse.
#   Empty is rc 1 (there is no identity here) and unrecordable is rc 2 (there
#   is one, and it cannot be written), matching what `resolve` reports for the
#   same two conditions.
validate() {
  local value="$1"

  if [[ -z "$value" ]]; then
    return 1
  fi

  if (( ${#value} > IDENTITY_MAX )); then
    echo "error: identity is not recordable" >&2
    return 2
  fi

  # Accept only the enumerated set: one character outside it refuses the whole
  # value. Newlines, spaces and multi-byte sequences are all outside it.
  if [[ "$value" == *[!$IDENTITY_CHARS]* ]]; then
    echo "error: identity is not recordable" >&2
    return 2
  fi

  printf '%s\n' "$value"
  return 0
}

# normalize <value> — print the value in the project's configured form.
#   The form is settled first, so a configuration that cannot select one refuses
#   rather than transforming under a form nobody chose.
#
#   The value clears the charset gate before anything transforms it, and the
#   result clears it again afterwards. Case folding only ever rewrites bytes the
#   set already admits, so the second check costs one comparison and removes the
#   need for anyone to re-derive that proof later.
#
#   Every form lower-cases, including the one that extracts nothing: a form is
#   defined by what it extracts, not by whether it transforms, and one path
#   where case survives splits a contributor who typed their own address two
#   ways.
normalize() {
  local value="$1"

  scheme >/dev/null || return 2

  if [[ -z "$value" ]]; then
    return 1
  fi

  validate "$value" >/dev/null || return $?

  # Byte-exact under LC_ALL=C, and the value has already cleared a set holding
  # nothing outside ASCII.
  value="${value,,}"

  validate "$value"
}

# resolve — print the environment's configured identity, or refuse.
#   The form is settled before the environment is read, so a project whose
#   configuration cannot select one refuses rather than recording under a form
#   it did not choose.
resolve() {
  local value rc
  scheme >/dev/null || return 2

  value="$(git config --get user.email 2>/dev/null)" || value=""

  if [[ -z "$value" ]]; then
    echo "error: no identity configured; set user.email" >&2
    return 1
  fi

  validate "$value"
  rc=$?
  return $rc
}

main() {
  if [[ "${1:-}" == "-c" ]]; then
    [[ -n "${2:-}" ]] || { echo "error: -c requires a path argument" >&2; return 2; }
    CFG="$2"; shift 2
  fi
  case "${1:-}" in
    resolve)
      shift
      if [[ $# -ne 0 ]]; then usage; return 2; fi
      resolve
      ;;
    validate)
      shift
      if [[ $# -ne 1 ]]; then usage; return 2; fi
      validate "$1"
      ;;
    normalize)
      shift
      if [[ $# -ne 1 ]]; then usage; return 2; fi
      normalize "$1"
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
exit $?
