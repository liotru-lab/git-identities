# Integration: gitclone alias resolution, URL host-rewrite and HTTPS→SSH
# conversion, and post-clone user.email setting. Aliased SSH hosts are rewritten
# (via git insteadOf) to local bare repos, so nothing hits the network.
# All identity values are synthetic (see test/lib/fixtures.zsh).

() {
  local h; h=$(make_home)
  export HOME="$h"

  local remotes; remotes=$(_mktemp_dir)
  add_local_remotes "$h" "$remotes"
  make_bare "$remotes" acme   owner/repo.git >/dev/null
  make_bare "$remotes" globex me/proj.git    >/dev/null

  local gc="$REPO/bin/gitclone"
  local work; work=$(_mktemp_dir)

  describe "gitclone: --profile forces alias + HTTPS→SSH + email"
  ( cd "$work" && zsh "$gc" --profile acme https://github.com/owner/repo.git dest1 >/dev/null 2>&1 )
  assert_file "clone created" "$work/dest1/file"
  assert_eq "email set to acme canonical" "dev@acme.test" \
    "$(git -C "$work/dest1" config user.email 2>/dev/null)"

  describe "gitclone: alias derived from URL host"
  ( cd "$work" && zsh "$gc" git@ssh-acme:owner/repo.git dest2 >/dev/null 2>&1 )
  assert_file "clone created" "$work/dest2/file"
  assert_eq "email from URL-host alias" "dev@acme.test" \
    "$(git -C "$work/dest2" config user.email 2>/dev/null)"

  describe "gitclone: alias derived from profiles + \$PWD"
  # `/**` matches dirs *below* the profile root (the documented "everything
  # below" semantics), so the clone runs from a subdir, as in real usage.
  cat > "$h/.config/git-identity/profiles" <<PRO
$work/garea/**   globex   me
PRO
  mkdir -p "$work/garea/sub"
  ( cd "$work/garea/sub" && zsh "$gc" https://github.com/me/proj.git dest3 >/dev/null 2>&1 )
  assert_file "clone created" "$work/garea/sub/dest3/file"
  assert_eq "email from profile alias" "dev@globex.test" \
    "$(git -C "$work/garea/sub/dest3" config user.email 2>/dev/null)"

  describe "gitclone: error handling"
  assert_status "unknown --profile → exit 2" 2 zsh "$gc" --profile ghost https://github.com/o/r.git
  assert_status "no URL → exit 2"            2 zsh "$gc" --profile acme
  # --profile as the last arg must not crash on `shift 2`.
  assert_status "--profile with no value → exit 2" 2 zsh "$gc" --profile
  assert_not_contains "no zsh shift crash" "$(zsh "$gc" --profile 2>&1)" "shift count must be"

  describe "gitclone: warns when identity comes only from the catch-all profile"
  cat > "$h/.config/git-identity/profiles" <<PRO
$work/specific/**   globex   g-org
$work/**            acme     a-org
PRO
  make_bare "$remotes" acme me/cat.git >/dev/null   # so the rewritten clone succeeds
  mkdir -p "$work/here"
  local cco; cco=$( cd "$work/here" && zsh "$gc" https://github.com/me/cat.git catdest 2>&1 )
  assert_contains "catch-all warned"     "$cco" "only the catch-all"
  assert_contains "suggests add-profile" "$cco" "git-identity --add-profile"
  # ...but not when the URL host already determines the alias (no profile needed):
  local hostc; hostc=$( cd "$work/here" && zsh "$gc" git@ssh-acme:owner/repo.git d2 2>&1 )
  assert_not_contains "no warning when alias from URL host" "$hostc" "only the catch-all"
}
