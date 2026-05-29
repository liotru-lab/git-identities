# Fixture helpers: build an isolated fake $HOME with the toolkit installed,
# plus tiny git repos in known identity states. No network is ever touched.
#
# IMPORTANT: every value here is synthetic. Aliases/emails/hosts use made-up
# company names and the reserved .test TLD so no real identity data lives in the
# repo. Do not substitute real emails/hosts into fixtures.
#
# The integration tests run the real bin/ scripts with HOME pointed at a temp
# dir, so they pick up our lib.sh + identities/profiles instead of the user's.

: ${REPO:?REPO must be set by run.zsh}

# Track temp dirs so the runner can clean them up.
typeset -ga _TMPDIRS

_mktemp_dir() {
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/git-identity-test.XXXXXX")
  _TMPDIRS+=("$d")
  print -r -- "$d"
}

cleanup_fixtures() {
  local d
  for d in "${_TMPDIRS[@]}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
  _TMPDIRS=()
}

# make_home → prints path to a fresh fake HOME with the toolkit config in place.
# Identities table (all synthetic): acme, globex.
make_home() {
  local h; h=$(_mktemp_dir)
  mkdir -p "$h/.config/git-identity"
  cp "$REPO/config/git-identity/lib.sh" "$h/.config/git-identity/lib.sh"

  cat > "$h/.config/git-identity/identities" <<'IDS'
# alias   email                ssh-host
acme      dev@acme.test        ssh-acme
globex    dev@globex.test      ssh-globex
IDS

  # Isolated git config: a name so commits work, no global user.email so repos
  # without an explicit email read as truly empty.
  cat > "$h/.gitconfig" <<'CFG'
[user]
	name = Test User
[init]
	defaultBranch = main
[protocol "file"]
	allow = always
[safe]
	directory = *
CFG

  print -r -- "$h"
}

# Rewrite our two aliased SSH hosts to local bare-repo paths, so a clone of a
# "git@ssh-acme:owner/repo.git" URL actually clones from disk.
# Usage: add_local_remotes <home> <remotes-root>
add_local_remotes() {
  local h="$1" root="$2"
  cat >> "$h/.gitconfig" <<CFG
[url "$root/acme/"]
	insteadOf = git@ssh-acme:
[url "$root/globex/"]
	insteadOf = git@ssh-globex:
CFG
}

# make_bare <remotes-root> <host-dir> <owner/repo.git>
# Creates a bare repo with one commit that a clone can pull from.
make_bare() {
  local root="$1" hostdir="$2" repo_path="$3"
  local bare="$root/$hostdir/$repo_path"
  local seed; seed=$(_mktemp_dir)
  git init -q "$seed"
  git -C "$seed" config user.email seed@seed.test
  git -C "$seed" config user.name Seed
  print -r -- "seed" > "$seed/file"
  git -C "$seed" add file
  git -C "$seed" commit -qm seed
  git clone -q --bare "$seed" "$bare"
  print -r -- "$bare"
}

# mkrepo <dir> <email> <remote-url>
# Creates a non-bare repo with the given user.email and origin (either may be "").
mkrepo() {
  local dir="$1" email="$2" remote="$3"
  git init -q "$dir"
  [[ -n "$email" ]]  && git -C "$dir" config user.email "$email"
  [[ -n "$remote" ]] && git -C "$dir" remote add origin "$remote"
}
