# Shared identity logic. Identities loaded from a config file.
# Sourced (no shebang) by starship.sh, git-identity, gitclone, gitinit.

IDENTITIES_FILE="${IDENTITIES_FILE:-$HOME/.config/git-identity/identities}"

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

# Detect identity for a repo. Optional path arg (default ".").
# Sets: ID_EMAIL, ID_E_ALIAS, ID_REMOTE, ID_HOST, ID_H_ALIAS, ID_STATE
# ID_STATE in { ok, mismatch, warn-no-email, warn-no-remote, warn-https,
#               warn-unknown-email, warn-unknown-host, warn-unknown-both }
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
}

_load_identities
