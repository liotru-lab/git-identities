# Integration: gitinit identity + branch scaffolding + remote URL building, plus
# the default GitHub repo creation + push (stubbed gh, no network).
# All identity values are synthetic (see test/lib/fixtures.zsh).
#
# NOTE: gitinit creates + pushes by DEFAULT. The local-only tests below pass
# --no-create so they never invoke gh / touch the network.

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

  describe "gitinit: --no-create full local flow with --remote host-rewrite"
  local d2; d2=$(_mktemp_dir)
  ( zsh "$gi" --profile acme --no-create --remote git@ssh-globex:acme-org/proj.git "$d2/proj" >/dev/null 2>&1 )
  assert_file "README created"  "$d2/proj/README.md"
  assert_eq "main branch made"    "main"    "$(git -C "$d2/proj" branch --list main --format='%(refname:short)')"
  assert_eq "test branch made"    "test"    "$(git -C "$d2/proj" branch --list test --format='%(refname:short)')"
  assert_eq "develop branch made" "develop" "$(git -C "$d2/proj" branch --list develop --format='%(refname:short)')"
  assert_eq "checked out develop" "develop" "$(git -C "$d2/proj" symbolic-ref --short HEAD)"
  assert_eq "origin host rewritten to alias" "git@ssh-acme:acme-org/proj.git" \
    "$(git -C "$d2/proj" remote get-url origin)"
  assert_eq "develop tracks origin" "origin" "$(git -C "$d2/proj" config branch.develop.remote)"

  describe "gitinit: --no-create remote built from profile owner + alias"
  mkdir -p "$h/code"
  ( cd "$h/code" && zsh "$gi" --no-create myrepo >/dev/null 2>&1 )
  assert_eq "URL from profile" "git@ssh-acme:acme-org/myrepo.git" \
    "$(git -C "$h/code/myrepo" remote get-url origin 2>/dev/null)"

  describe "gitinit: error when remote undeterminable"
  local d3; d3=$(_mktemp_dir)
  assert_status "no alias/owner + no --remote/--no-remote → exit 2" 2 \
    zsh "$gi" --no-create "$d3/proj"

  describe "gitinit: value-flag as last arg doesn't crash"
  # --profile / --remote with no value must exit 2 cleanly, not crash on shift 2.
  assert_status "--profile with no value → exit 2" 2 zsh "$gi" --profile
  assert_status "--remote with no value → exit 2"  2 zsh "$gi" --remote
  assert_not_contains "no zsh shift crash" "$(zsh "$gi" --remote 2>&1)" "shift count must be"

  # --- Default behavior: create the GitHub repo + push, with a stubbed gh and a
  #     local bare repo standing in for the remote (no network). ---
  local remotes; remotes=$(_mktemp_dir)
  add_local_remotes "$h" "$remotes"
  local stub; stub=$(_mktemp_dir)/bin
  make_gh_stub "$stub"            # gh-acme + gh-globex are "authenticated"

  describe "gitinit: --public requires creation (errors with --no-create)"
  assert_status "--public + --no-create → exit 2" 2 \
    env PATH="$stub:$PATH" zsh "$gi" --profile acme --public --no-create "$(_mktemp_dir)/p"
  assert_status "--public + --no-remote → exit 2" 2 \
    env PATH="$stub:$PATH" zsh "$gi" --profile acme --public --no-remote "$(_mktemp_dir)/p"

  describe "gitinit: missing gh-user for alias → exit 2"
  # Identities without a 4th column: default create can't resolve a gh account.
  cat > "$h/.config/git-identity/identities" <<IDS
acme   dev@acme.test   ssh-acme
IDS
  assert_status "no gh-user column → exit 2" 2 \
    env PATH="$stub:$PATH" zsh "$gi" --profile acme "$(_mktemp_dir)/p"
  # ...but --no-create still works fine without a gh-user
  local nc; nc=$(_mktemp_dir)
  ( env PATH="$stub:$PATH" zsh "$gi" --profile acme --no-create --remote git@ssh-acme:acme-org/nc.git "$nc/nc" >/dev/null 2>&1 )
  assert_file "--no-create succeeds without gh-user" "$nc/nc/README.md"
  # restore the standard 4-column fixture
  cat > "$h/.config/git-identity/identities" <<IDS
acme     dev@acme.test     ssh-acme     gh-acme
globex   dev@globex.test   ssh-globex   gh-globex
IDS

  describe "gitinit: unauthenticated gh account → exit 2"
  local stub_none; stub_none=$(_mktemp_dir)/bin
  make_gh_stub "$stub_none" ""    # nobody authenticated
  assert_status "gh not authed → exit 2" 2 \
    env PATH="$stub_none:$PATH" zsh "$gi" --profile acme "$(_mktemp_dir)/p"

  describe "gitinit: default creates repo (private) + pushes, owner from profile"
  make_bare "$remotes" acme acme-org/created.git >/dev/null
  ( env PATH="$stub:$PATH" zsh "$gi" --profile acme "$h/code/created" >/dev/null 2>&1 )
  assert_eq "gh repo create called with profile owner + --private" \
    "gh repo create acme-org/created --private" \
    "$(cat "$stub/gh-calls.log" 2>/dev/null)"
  assert_eq "develop pushed to remote" "develop" \
    "$(git -C "$remotes/acme/acme-org/created.git" branch --list develop --format='%(refname:short)' 2>/dev/null)"
  assert_eq "main pushed to remote" "main" \
    "$(git -C "$remotes/acme/acme-org/created.git" branch --list main --format='%(refname:short)' 2>/dev/null)"
  assert_eq "test pushed to remote" "test" \
    "$(git -C "$remotes/acme/acme-org/created.git" branch --list test --format='%(refname:short)' 2>/dev/null)"

  describe "gitinit: owner falls back to gh-user when no profile owner"
  local stub_fb; stub_fb=$(_mktemp_dir)/bin
  make_gh_stub "$stub_fb"
  make_bare "$remotes" acme gh-acme/solo.git >/dev/null
  local fb; fb=$(_mktemp_dir)
  ( cd "$fb" && env PATH="$stub_fb:$PATH" zsh "$gi" --profile acme --remote git@ssh-acme:gh-acme/solo.git solo >/dev/null 2>&1 )
  assert_eq "gh repo create called under gh-user namespace" \
    "gh repo create gh-acme/solo --private" \
    "$(cat "$stub_fb/gh-calls.log" 2>/dev/null)"

  describe "gitinit --public: passes --public to gh"
  local stub2; stub2=$(_mktemp_dir)/bin
  make_gh_stub "$stub2"
  make_bare "$remotes" acme acme-org/pub.git >/dev/null
  ( env PATH="$stub2:$PATH" zsh "$gi" --profile acme --public "$h/code/pub" >/dev/null 2>&1 )
  assert_eq "gh repo create called with --public" \
    "gh repo create acme-org/pub --public" \
    "$(cat "$stub2/gh-calls.log" 2>/dev/null)"

  describe "gitinit: --no-create does NOT call gh"
  local stub3; stub3=$(_mktemp_dir)/bin
  make_gh_stub "$stub3"
  ( env PATH="$stub3:$PATH" zsh "$gi" --profile acme --no-create --remote git@ssh-acme:acme-org/quiet.git "$(_mktemp_dir)/quiet" >/dev/null 2>&1 )
  assert_no_file "no gh repo create call logged" "$stub3/gh-calls.log"

  describe "gitinit -s: main only, no test/develop, tracks origin/main"
  local s1; s1=$(_mktemp_dir)
  ( zsh "$gi" --profile acme -s --no-create --remote git@ssh-acme:acme-org/s.git "$s1/proj" >/dev/null 2>&1 )
  assert_file "README created"      "$s1/proj/README.md"
  assert_eq "main branch made"      "main" "$(git -C "$s1/proj" branch --list main --format='%(refname:short)')"
  assert_empty "no test branch"     "$(git -C "$s1/proj" branch --list test --format='%(refname:short)')"
  assert_empty "no develop branch"  "$(git -C "$s1/proj" branch --list develop --format='%(refname:short)')"
  assert_eq "stays on main"         "main"   "$(git -C "$s1/proj" symbolic-ref --short HEAD)"
  assert_eq "main tracks origin"    "origin" "$(git -C "$s1/proj" config branch.main.remote)"
  assert_eq "main merge ref"        "refs/heads/main" "$(git -C "$s1/proj" config branch.main.merge)"

  describe "gitinit --simple: creates repo + pushes main only"
  local stub4; stub4=$(_mktemp_dir)/bin
  make_gh_stub "$stub4"
  make_bare "$remotes" acme acme-org/simple.git >/dev/null
  ( env PATH="$stub4:$PATH" zsh "$gi" --profile acme --simple "$h/code/simple" >/dev/null 2>&1 )
  assert_eq "main pushed to remote" "main" \
    "$(git -C "$remotes/acme/acme-org/simple.git" branch --list main --format='%(refname:short)' 2>/dev/null)"
  assert_empty "develop NOT pushed" \
    "$(git -C "$remotes/acme/acme-org/simple.git" branch --list develop --format='%(refname:short)' 2>/dev/null)"
  assert_empty "test NOT pushed" \
    "$(git -C "$remotes/acme/acme-org/simple.git" branch --list test --format='%(refname:short)' 2>/dev/null)"

  # --- Owner resolution: --owner > profile owner > gh-user fallback ---
  # NB: read the RAW stored URL via `git config` — `git remote get-url` would
  # apply the fixture's insteadOf rewrites once add_local_remotes has run above.
  describe "gitinit: owner defaults to the alias's gh-user (no profile, no --owner)"
  local o1; o1=$(_mktemp_dir)   # outside $h/code, so no profile matches
  ( zsh "$gi" --profile acme --no-create "$o1/proj" >/dev/null 2>&1 )
  assert_eq "URL owner falls back to gh-user" "git@ssh-acme:gh-acme/proj.git" \
    "$(git -C "$o1/proj" config remote.origin.url 2>/dev/null)"

  describe "gitinit --owner: overrides, builds URL under that owner"
  local o2; o2=$(_mktemp_dir)
  ( zsh "$gi" --profile acme --owner some-org --no-create "$o2/proj" >/dev/null 2>&1 )
  assert_eq "URL owner is --owner value" "git@ssh-acme:some-org/proj.git" \
    "$(git -C "$o2/proj" config remote.origin.url 2>/dev/null)"

  describe "gitinit --owner: wins over a matching profile owner"
  ( zsh "$gi" --owner override-org --no-create "$h/code/ov" >/dev/null 2>&1 )  # profile says acme-org
  assert_eq "--owner beats profile owner" "git@ssh-acme:override-org/ov.git" \
    "$(git -C "$h/code/ov" config remote.origin.url 2>/dev/null)"

  describe "gitinit --owner: creates the GitHub repo under that owner"
  local stub5; stub5=$(_mktemp_dir)/bin
  make_gh_stub "$stub5"
  make_bare "$remotes" acme some-org/created2.git >/dev/null
  ( env PATH="$stub5:$PATH" zsh "$gi" --profile acme --owner some-org "$(_mktemp_dir)/created2" >/dev/null 2>&1 )
  assert_eq "gh repo create uses --owner" "gh repo create some-org/created2 --private" \
    "$(cat "$stub5/gh-calls.log" 2>/dev/null)"

  describe "gitinit --remote: its URL owner becomes the create target"
  # Owner in the --remote URL (other-org) differs from the gh-user (gh-acme);
  # the repo must be created under other-org, not the gh-user namespace.
  local stub6; stub6=$(_mktemp_dir)/bin
  make_gh_stub "$stub6"
  make_bare "$remotes" acme other-org/remoted.git >/dev/null
  ( env PATH="$stub6:$PATH" zsh "$gi" --profile acme \
      --remote git@ssh-acme:other-org/remoted.git "$(_mktemp_dir)/remoted" >/dev/null 2>&1 )
  assert_eq "gh repo create uses the --remote URL's owner" \
    "gh repo create other-org/remoted --private" \
    "$(cat "$stub6/gh-calls.log" 2>/dev/null)"

  describe "gitinit --owner needs a value → exit 2"
  assert_status "--owner with no value" 2 zsh "$gi" --owner

  # --- resolve line + catch-all warning ---
  describe "gitinit: warns when only the catch-all profile matches"
  cat > "$h/.config/git-identity/profiles" <<PRO
$h/proj/**   acme   acme-org
$h/**        acme   fallback-owner
PRO
  local cao; cao=$( zsh "$gi" --no-create "$h/random/thing" 2>&1 )   # matches $h/** (last)
  assert_contains "resolve line shown"   "$cao" "identity <acme>, owner fallback-owner"
  assert_contains "catch-all warned"     "$cao" "only the catch-all"
  assert_contains "suggests add-profile" "$cao" "git-identity --add-profile"
  local spec; spec=$( zsh "$gi" --no-create "$h/proj/thing" 2>&1 )   # matches $h/proj/** (specific)
  assert_not_contains "no warning for a specific rule" "$spec" "only the catch-all"

  # --- existing-folder support ---
  describe "gitinit: existing folder WITH a .gitignore commits its files"
  local ex1; ex1=$(_mktemp_dir)
  mkdir -p "$ex1/proj/src"; print code > "$ex1/proj/src/a.txt"; print node_modules > "$ex1/proj/.gitignore"
  ( zsh "$gi" --profile acme --no-remote "$ex1/proj" >/dev/null 2>&1 )
  assert_contains "tracks src/a.txt"  "$(git -C "$ex1/proj" ls-files)" "src/a.txt"
  assert_contains "tracks .gitignore" "$(git -C "$ex1/proj" ls-files)" ".gitignore"

  describe "gitinit: existing folder with NO .gitignore → README only + warning"
  local ex2; ex2=$(_mktemp_dir)
  mkdir -p "$ex2/proj/src"; print code > "$ex2/proj/src/b.txt"
  local w2; w2=$( zsh "$gi" --profile acme --no-remote "$ex2/proj" 2>&1 )
  assert_eq "only README committed" "README.md" "$(git -C "$ex2/proj" ls-files)"
  assert_not_contains "code left untracked" "$(git -C "$ex2/proj" ls-files)" "src/b.txt"
  assert_contains "warns about missing .gitignore" "$w2" "no .gitignore"

  describe "gitinit: empty/new folder unchanged (README only, no prompt)"
  local em; em=$(_mktemp_dir)
  ( zsh "$gi" --profile acme --no-remote "$em/fresh" </dev/null >/dev/null 2>&1 )
  assert_eq "README-only commit" "README.md" "$(git -C "$em/fresh" ls-files)"

  describe "gitinit: refuses a folder that is already a git repo"
  local rp; rp=$(_mktemp_dir); git init -q "$rp/repo"
  assert_status "already-a-repo → exit 2" 2 zsh "$gi" --profile acme --no-remote "$rp/repo"
  assert_contains "explains it's already a repo" \
    "$(zsh "$gi" --profile acme --no-remote "$rp/repo" 2>&1)" "already a git repo"

  describe "gitinit: existing-folder confirm — decline leaves it pristine"
  local cf; cf=$(_mktemp_dir); mkdir -p "$cf/proj"; print x > "$cf/proj/f.txt"
  local stubd; stubd=$(_mktemp_dir)/bin; make_gh_stub "$stubd"
  printf 'n\n' | env PATH="$stubd:$PATH" zsh "$gi" --profile acme "$cf/proj" >/dev/null 2>&1
  local dec=$?
  assert_eq "decline → exit 1" "1" "$dec"
  assert_no_file "decline leaves no .git" "$cf/proj/.git"
  assert_no_file "decline made no gh call" "$stubd/gh-calls.log"

  describe "gitinit: --yes skips the confirm (proceeds to commit)"
  local yf; yf=$(_mktemp_dir); mkdir -p "$yf/proj"; print x > "$yf/proj/f.txt"
  local stuby; stuby=$(_mktemp_dir)/bin; make_gh_stub "$stuby"
  # No stdin: without --yes the prompt would read EOF and decline; --yes proceeds
  # (gh create stubbed; push fails with no bare remote, but the commit is made).
  ( env PATH="$stuby:$PATH" zsh "$gi" --profile acme --yes "$yf/proj" </dev/null >/dev/null 2>&1 )
  assert_status "--yes proceeded to a commit (HEAD exists)" 0 git -C "$yf/proj" rev-parse --verify HEAD
}
