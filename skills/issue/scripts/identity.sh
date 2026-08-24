#!/usr/bin/env bash
#
# skills/issue/scripts/identity.sh — Decide what a recordable contributor
#   identity is and what form it takes. The emitter records the result as an
#   issue's filer, the transition verbs record it as an issue's holder, and the
#   collection conversion records a filer recovered from history, so this is the
#   one place all three agree about.
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
#   - The set judges the value as supplied, not only the value the alias mapping
#     hands back. The mapping lookup composes its argument out of the value, so
#     a value gated only afterwards can return as a fragment of itself that is
#     recordable on its own merits — a refusal silently turned into a
#     truncation. Every step that composes the value into something else sits
#     behind the gate, not in front of it.
#   - A refused value never appears in the refusal. Reasons are fixed strings,
#     so a terminal log cannot be made to carry the value that was rejected.
#   - The value is compared, never sourced or evaluated.
#
# USAGE
#   bash identity.sh resolve            # read the environment's identity
#   bash identity.sh validate <value>   # judge one already-obtained identity
#   bash identity.sh normalize <value>  # apply the project's form to one value
#   bash identity.sh map <value>        # resolve one value through the mapping
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

# The accepted set for the organization domain, stated positively for the same
# reason the identity set is: the value reaches a shell pattern match, so a
# character nobody anticipated must fail closed rather than widen the match.
DOMAIN_CHARS='A-Za-z0-9.-'

# The one forge relay service recognized. Matched as an exact tail, so an
# address that merely contains it — as a subdomain, or with a real domain
# appended after it — is not a relay address.
RELAY_SUFFIX='@users.noreply.github.com'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIMCONF="$(cd "$HERE/../../conf/scripts" && pwd)/jimconf.sh"
CFG=""   # optional jimconf override path, forwarded to jimconf

# jc <args...> — invoke jimconf.sh, forwarding -c when set.
jc() { if [[ -n "$CFG" ]]; then bash "$JIMCONF" -c "$CFG" "$@"; else bash "$JIMCONF" "$@"; fi; }

usage() {
  echo "usage: identity.sh [-c <config>] resolve" >&2
  echo "       identity.sh [-c <config>] validate <value>" >&2
  echo "       identity.sh [-c <config>] normalize <value>" >&2
  echo "       identity.sh [-c <config>] map <value>" >&2
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

# map_alias <value> — the address the project's version control maps this one
#   to, or the value unchanged when it maps nothing.
#
#   The mapping is the project's, read wherever version control resolves it
#   from — not from one file at a known path. jim reads it; it does not create
#   one, write to one, or define its format.
#
#   The value crosses into a command here, and the hyphen is a member of the
#   accepted identity set, so an identity that looks like an option is a value
#   this script must still carry: it is passed after an end-of-options separator
#   so it is read as data. Without the separator the value would cross from data
#   into control, and the charset gate would not stop it — the gate admits the
#   hyphen deliberately, because real addresses carry one.
#
#   The value is also composed into the lookup argument, wrapped in angle
#   brackets, so it clears the charset gate before that composition happens. The
#   accepted set admits neither bracket: a value already carrying one builds
#   bracket structure the extraction below — which reads what the final brackets
#   hold — reads as an address, returning a fragment of the value rather than a
#   mapped one. That fragment can be recordable on its own merits, with nothing
#   left to say what it came from was not, which turns a refusal into a
#   truncation. The gate lives here rather than in the callers because the
#   requirement belongs to the composition; a caller reaching the lookup by
#   another route would otherwise reopen the door. It bounds the value's length
#   as well as its content, so the command never receives an unbounded argument.
#
#   A value the set does not admit is therefore refused before the mapping is
#   consulted, exactly as an absent one is. A mapping keyed on such a value
#   cannot fire — the same answer the gate gives everywhere else.
#
#   Anything other than a well-formed answer leaves the value alone: no
#   repository, no mapping, or output this does not recognize all mean nothing
#   was mapped. The result is judged as a recordable identity in its own right
#   afterwards, so the mapping is a source of identities and not a way past the
#   gate.
map_alias() {
  local value="$1" out address
  validate "$value" >/dev/null || return $?
  out="$(git check-mailmap -- "<$value>" 2>/dev/null)" || { printf '%s' "$value"; return 0; }
  case "$out" in
    *"<"*">"*)
      # Either `<address>` or `Name <address>`; take what the final angle
      # brackets hold. Only the address is recorded — a display name is not an
      # identity.
      address="${out##*<}"
      address="${address%>*}"
      if [[ -n "$address" ]]; then
        printf '%s' "$address"
        return 0
      fi
      ;;
  esac
  printf '%s' "$value"
}

# extract_relay <value> — the account name a forge relay address carries, or
#   the value unchanged when it is not one.
#
#   The service issues two forms: one carrying a numeric account id ahead of the
#   name, an older one carrying the name alone with no separator at all. Both
#   are the same person, so the id is optional rather than required — requiring
#   it would record every pre-cutoff contributor as a full address while
#   everyone else got a handle, which is the split this form exists to close.
#
#   Recognition keys on the service, never on the separator. That character is
#   ordinary in real mail, where it marks a tag on a mailbox, so keying on it
#   would rewrite an unrelated address into whatever followed it. Note the
#   deliberate asymmetry with the organization-local form, which discards a
#   trailing tag: within one domain a tagged address is the same mailbox and so
#   the same person, whereas here the same character separates an account id
#   from an account name. Same character, opposite halves.
#
#   An address yielding no account name is returned whole. Recording an empty
#   identity would be worse than recording a long one.
extract_relay() {
  local value="$1" account
  case "$value" in
    *"$RELAY_SUFFIX")
      account="${value%"$RELAY_SUFFIX"}"
      if [[ "$account" =~ ^[0-9]+\+(.*)$ ]]; then
        account="${BASH_REMATCH[1]}"
      fi
      if [[ -n "$account" ]]; then
        printf '%s' "$account"
        return 0
      fi
      ;;
  esac
  printf '%s' "$value"
}

# domain — print the project's configured organization domain, folded to lower
#   case so every comparison against it ignores case by construction.
#
#   Reached only by the form that uses it. The gates below are what stop a
#   setting from widening the extraction it drives:
#
#   - Absent. The form cannot be applied at all, so every operation that would
#     record an identity is refused rather than warned about. A project told
#     only in a message goes on recording under a form it cannot apply.
#   - Several domains. Extraction across a union nobody has checked for
#     uniqueness is exactly where one person's account becomes another's, so a
#     value naming more than one is refused rather than partially honored.
#   - Outside the enumerated set. The value reaches a shell pattern match, and
#     stating the accepted set positively is what makes an unanticipated
#     character fail closed rather than survive a list someone thought to name.
#
#   Every refusal names the setting and none carries its value.
domain() {
  local value
  value="$(jc get identity_domain 2>/dev/null)" || {
    echo "error: identity_domain could not be resolved from the project config" >&2
    return 2
  }
  value="${value,,}"

  if [[ -z "$value" ]]; then
    echo "error: identity_scheme is 'local' but identity_domain is not set;" \
         "set identity_domain to the organization's domain" >&2
    return 2
  fi

  if [[ "$value" == *[[:space:],\;]* ]]; then
    echo "error: identity_domain names exactly one domain" >&2
    return 2
  fi

  if [[ "$value" == *[!$DOMAIN_CHARS]* ]]; then
    echo "error: identity_domain is not a domain" >&2
    return 2
  fi

  printf '%s' "$value"
}

# extract_local <value> <domain> — the account part of an address inside
#   <domain>, printed on stdout.
#
#   Returns 0 when the address is inside the domain and 1 when it is not, so the
#   caller can fall through to the form below rather than inspecting the result.
#   Membership is the deciding fact, not whether anything was extracted.
#
#   The domain is matched exactly: a subdomain of the configured one is a
#   different domain, and treating it as the same would collapse accounts across
#   a set nobody has checked for uniqueness.
#
#   A trailing tag is discarded, because within one organization's domain a
#   tagged address is the same mailbox and therefore the same person. An address
#   yielding no account part is returned whole, as the relay rule does.
extract_local() {
  local value="$1" org="$2" account
  case "$value" in
    *"@$org")
      account="${value%"@$org"}"
      account="${account%%+*}"
      if [[ -n "$account" ]]; then
        printf '%s' "$account"
      else
        printf '%s' "$value"
      fi
      return 0
      ;;
  esac
  printf '%s' "$value"
  return 1
}

# map <value> — print the address the project's mapping resolves this one to,
#   with no form applied.
#
#   The pipeline's own prefix, exposed on its own: the length bound, the
#   mapping, and the gate the result must clear. It stops before the form
#   because its question is the one a normalized value cannot answer — whether
#   two addresses are one contributor. A normalized value has lost which of the
#   two steps moved it, so a caller comparing them either gets this answer here
#   or grows a second copy of the lookup, and a second copy is how the
#   end-of-options discipline ends up in one place and not the other.
map() {
  local value="$1"

  if [[ -z "$value" ]]; then
    return 1
  fi

  value="$(map_alias "$value")" || return $?

  validate "$value"
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
  local value="$1" form

  form="$(scheme)" || return 2

  if [[ -z "$value" ]]; then
    return 1
  fi

  # Alias resolution precedes extraction. A mapping is keyed on addresses, so
  # extracting first would leave it nothing to match and the contributor it
  # exists to merge would stay split. It does not precede the charset gate: the
  # lookup gates its own argument, so a value outside the accepted set is
  # refused before the mapping is consulted.
  value="$(map_alias "$value")" || return $?

  validate "$value" >/dev/null || return $?

  # Case folds before anything is compared, so every comparison below is
  # case-insensitive by construction rather than by remembering to be. Byte-exact
  # under LC_ALL=C, and the value has already cleared a set holding nothing
  # outside ASCII.
  value="${value,,}"

  # The forms are nested: each applies its own extraction and otherwise falls
  # through to the one below it, so a contributor who commits several ways
  # still records as one identity.
  local org extracted
  case "$form" in
    local)
      org="$(domain)" || return 2
      if extracted="$(extract_local "$value" "$org")"; then
        value="$extracted"
      else
        value="$(extract_relay "$value")"
      fi
      ;;
    github)
      value="$(extract_relay "$value")"
      ;;
  esac

  validate "$value"
}

# resolve — print the environment's configured identity, or refuse.
#   The environment is one source of an identity among several, so it goes
#   through the same definition as a value supplied from anywhere else. That is
#   what stops a newly filed issue and a converted one from disagreeing about
#   who someone is.
#
#   An absent identity is reported as absent whatever form is configured: there
#   is nothing to record either way, and "set user.email" is the answer the
#   caller can act on.
resolve() {
  local value rc
  value="$(git config --get user.email 2>/dev/null)" || value=""

  if [[ -z "$value" ]]; then
    echo "error: no identity configured; set user.email" >&2
    return 1
  fi

  normalize "$value"
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
    map)
      shift
      if [[ $# -ne 1 ]]; then usage; return 2; fi
      map "$1"
      ;;
    *)
      usage
      return 2
      ;;
  esac
}

main "$@"
exit $?
