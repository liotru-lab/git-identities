# Integration: gitinit identity + branch scaffolding + remote URL building.
# No pushing occurs, so remotes need not exist; we assert on local config.
# All identity values are synthetic (see test/lib/fixtures.zsh).

() {
  local h; h=$(make_home)
  export HOME="$h"
  cat > "$h/.config/git-identity/profiles" <<PRO
$h/code/*   acme   acme-org
PRO

  local gi="$REPO/bin/gitinit"

  describe "gitinit: --no-branches stops after init + email"
  local d1; d1=$(_mktemp_dir)
  ( zsh "$gi" --profile acme --no-branches "$d1/proj" >/dev/null 2>&1 )
  assert_eq "email set"        "dev@acme.test" "$(git -C "$d1/proj" config user.email 2>/dev/null)"
  assert_eq "branch is main"   "main"          "$(git -C "$d1/proj" symbolic-ref --short HEAD 2>/dev/null)"
  assert_no_file "no README committed" "$d1/proj/README.md"
  assert_empty "no origin remote" "$(git -C "$d1/proj" remote 2>/dev/null)"

  describe "gitinit: full flow with --remote host-rewrite"
  local d2; d2=$(_mktemp_dir)
  ( zsh "$gi" --profile acme --remote git@ssh-globex:acme-org/proj.git "$d2/proj" >/dev/null 2>&1 )
  assert_file "README created"  "$d2/proj/README.md"
  assert_eq "main branch made"    "main"    "$(git -C "$d2/proj" branch --list main --format='%(refname:short)')"
  assert_eq "test branch made"    "test"    "$(git -C "$d2/proj" branch --list test --format='%(refname:short)')"
  assert_eq "develop branch made" "develop" "$(git -C "$d2/proj" branch --list develop --format='%(refname:short)')"
  assert_eq "checked out develop" "develop" "$(git -C "$d2/proj" symbolic-ref --short HEAD)"
  assert_eq "origin host rewritten to alias" "git@ssh-acme:acme-org/proj.git" \
    "$(git -C "$d2/proj" remote get-url origin)"
  assert_eq "develop tracks origin" "origin" "$(git -C "$d2/proj" config branch.develop.remote)"

  describe "gitinit: remote built from profile owner + alias"
  mkdir -p "$h/code"
  ( cd "$h/code" && zsh "$gi" myrepo >/dev/null 2>&1 )
  assert_eq "URL from profile" "git@ssh-acme:acme-org/myrepo.git" \
    "$(git -C "$h/code/myrepo" remote get-url origin 2>/dev/null)"

  describe "gitinit: error when remote undeterminable"
  local d3; d3=$(_mktemp_dir)
  assert_status "no alias/owner + no --remote/--no-remote → exit 2" 2 \
    zsh "$gi" "$d3/proj"
}
