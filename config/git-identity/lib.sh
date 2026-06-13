# Shared identity logic. Identities loaded from a config file.
# Sourced (no shebang) by starship.sh, git-identity, gitclone, gitinit.

IDENTITIES_FILE="${IDENTITIES_FILE:-$HOME/.config/git-identity/identities}"
PROFILES_FILE="${PROFILES_FILE:-$HOME/.config/git-identity/profiles}"

typeset -gA ALIAS_TO_EMAIL ALIAS_TO_HOST EMAIL_TO_ALIAS HOST_TO_ALIAS ALIAS_TO_GHUSER
typeset -ga ALIASES_ORDERED

# Load the identities table: "<alias> <email> <ssh-host> [gh-user]" per line.
# The 4th column (gh-user) is optional; only gitinit --create needs it.
_load_identities() {
  ALIAS_TO_EMAIL=(); ALIAS_TO_HOST=()
  EMAIL_TO_ALIAS=(); HOST_TO_ALIAS=()
  ALIAS_TO_GHUSER=()
  ALIASES_ORDERED=()
  [[ -f "$IDENTITIES_FILE" ]] || return
  local line
  local -a fields
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%\#*}"
    line="${line##[[:space:]]##}"
    line="${line%%[[:space:]]##}"
    [[ -z "$line" ]] && continue
    fields=( ${=line} )
    local alias="${fields[1]:-}" email="${fields[2]:-}" host="${fields[3]:-}" ghuser="${fields[4]:-}"
    [[ -z "$alias" || -z "$email" || -z "$host" ]] && continue
    ALIAS_TO_EMAIL[$alias]="$email"
    ALIAS_TO_HOST[$alias]="$host"
    EMAIL_TO_ALIAS[$email]="$alias"
    HOST_TO_ALIAS[$host]="$alias"
    [[ -n "$ghuser" ]] && ALIAS_TO_GHUSER[$alias]="$ghuser"
    ALIASES_ORDERED+=("$alias")
  done < "$IDENTITIES_FILE"
}

email_to_alias()  { echo "${EMAIL_TO_ALIAS[$1]-}";  }
host_to_alias()   { echo "${HOST_TO_ALIAS[$1]-}";   }
alias_to_email()  { echo "${ALIAS_TO_EMAIL[$1]-}";  }
alias_to_host()   { echo "${ALIAS_TO_HOST[$1]-}";   }
alias_to_ghuser() { echo "${ALIAS_TO_GHUSER[$1]-}"; }

# Parse SSH host from "git@HOST:owner/repo[.git]". Empty if HTTPS or no URL.
parse_remote_host() {
  if [[ "$1" =~ ^git@([^:]+): ]]; then
    echo "${match[1]}"
  fi
}

# Parse the owner (org/user) from a remote URL. Handles:
#   git@host:owner/repo[.git]            (scp-like SSH)
#   ssh://git@host[:port]/owner/repo     (ssh URL)
#   https://host/owner/repo[.git]        (HTTPS)
# Empty if it can't be determined.
parse_remote_owner() {
  local url="$1"
  if [[ "$url" =~ ^git@[^:]+:([^/]+)/ ]]; then
    echo "${match[1]}"
  elif [[ "$url" =~ ^(ssh|https?|git)://[^/]+/([^/]+)/ ]]; then
    echo "${match[2]}"
  fi
}

# Match a path against the profiles file (first match wins). Sets the globals
# pf_alias / pf_owner (both empty when nothing matches) and pf_pattern (the raw
# matched glob, for callers that want to detect a catch-all). Shared by
# gitclone, gitinit and detect_identity's owner-drift check.
match_profile() {
  pf_alias=""; pf_owner=""; pf_pattern=""
  [[ -f "$PROFILES_FILE" ]] || return
  local check_path="$1" line
  local -a fields
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%\#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    fields=( ${=line} )
    local pat="${fields[1]:-}" ali="${fields[2]:-}" own="${fields[3]:-}"
    local raw="${fields[1]:-}"
    pat="${pat/#\~/$HOME}"
    [[ -z "$pat" || -z "$ali" ]] && continue
    case "$check_path" in
      ${~pat}) pf_alias="$ali"; pf_owner="$own"; pf_pattern="$raw"; return ;;
    esac
  done < "$PROFILES_FILE"
}

# Print the raw pattern (1st field) of the LAST rule in profiles, or empty.
# By convention the catch-all rule is last, so callers compare a match's
# pf_pattern against this to tell "matched only the catch-all."
last_profile_pattern() {
  [[ -f "$PROFILES_FILE" ]] || return
  local line last=""
  local -a fields
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%\#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    fields=( ${=line} )
    [[ -n "${fields[1]:-}" ]] && last="${fields[1]}"
  done < "$PROFILES_FILE"
  print -r -- "$last"
}

# Detect identity for a repo. Optional path arg (default ".").
# Sets: ID_EMAIL, ID_E_ALIAS, ID_REMOTE, ID_HOST, ID_H_ALIAS, ID_STATE
#       ID_OWNER, ID_EXPECTED_OWNER, ID_OWNER_STATE
# ID_STATE in { ok, mismatch, warn-no-email, warn-no-remote, warn-https,
#               warn-unknown-email, warn-unknown-host, warn-unknown-both }
# ID_OWNER_STATE in { ok, drift, unknown } — the org/owner on disk vs the owner
# the profiles file declares for this path. Orthogonal to ID_STATE: a repo can
# be identity-ok yet owner-drift (right key/email, wrong GitHub org). 'ok' also
# means "no expectation" (no matching profile, or its owner column is blank).
detect_identity() {
  local repo_dir="${1:-.}"
  ID_EMAIL=$(git -C "$repo_dir" config user.email 2>/dev/null || true)
  ID_E_ALIAS=$(email_to_alias "$ID_EMAIL")
  ID_REMOTE=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)
  ID_HOST=$(parse_remote_host "$ID_REMOTE")
  ID_H_ALIAS=$(host_to_alias "$ID_HOST")

  if   [[ -z "$ID_EMAIL"  ]]; then ID_STATE=warn-no-email
  elif [[ -z "$ID_REMOTE" ]]; then ID_STATE=warn-no-remote
  elif [[ -z "$ID_HOST"   ]]; then ID_STATE=warn-https
  elif [[ -z "$ID_E_ALIAS" && -z "$ID_H_ALIAS" ]]; then ID_STATE=warn-unknown-both
  elif [[ -z "$ID_E_ALIAS" ]]; then ID_STATE=warn-unknown-email
  elif [[ -z "$ID_H_ALIAS" ]]; then ID_STATE=warn-unknown-host
  elif [[ "$ID_E_ALIAS" == "$ID_H_ALIAS" ]]; then ID_STATE=ok
  else ID_STATE=mismatch
  fi

  # Owner drift: compare the remote's owner against the profile-declared owner
  # for this repo's top-level path.
  ID_OWNER=$(parse_remote_owner "$ID_REMOTE")
  ID_EXPECTED_OWNER=""
  ID_OWNER_STATE=ok
  local top
  top=$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -n "$top" ]]; then
    match_profile "$top"
    ID_EXPECTED_OWNER="$pf_owner"
  fi
  if [[ -n "$ID_EXPECTED_OWNER" && -n "$ID_REMOTE" ]]; then
    if   [[ -z "$ID_OWNER" ]];                     then ID_OWNER_STATE=unknown
    elif [[ "$ID_OWNER" != "$ID_EXPECTED_OWNER" ]]; then ID_OWNER_STATE=drift
    fi
  fi
}

_load_identities
