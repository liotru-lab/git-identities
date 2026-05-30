# Integration: git-identity-doctor offline checks against fixture $HOME dirs.
# Tests don't install to ~/.local/bin, so the "Executables on PATH" section will
# report failures for that — therefore each case scopes its assertions to the
# specific output line it cares about (assert_contains), not the exit code.
# All identity values are synthetic (see test/lib/fixtures.zsh).

() {
  local doctor="$REPO/bin/git-identity-doctor"

  # ---- healthy config ----
  local h; h=$(make_home); export HOME="$h"
  cat > "$h/.config/git-identity/profiles" <<PRO
$h/code/**   acme   acme-org
PRO
  # ssh config with a Host block for each non-default host
  mkdir -p "$h/.ssh"
  cat > "$h/.ssh/config" <<SSH
Host ssh-acme
    HostName github.com
    IdentityFile ~/.ssh/id_acme
Host ssh-globex
    HostName github.com
    IdentityFile ~/.ssh/id_globex
SSH

  local out
  out=$(zsh "$doctor" 2>&1)

  describe "doctor: parses a healthy config"
  assert_contains "lists the two identities" "$out" "2 identities: acme globex"
  assert_contains "profiles section ok"      "$out" "profile rule"
  assert_contains "ssh-acme block found"     "$out" "alias 'acme' → Host 'ssh-acme' present"
  assert_contains "ssh-globex block found"   "$out" "alias 'globex' → Host 'ssh-globex' present"
  assert_not_contains "no malformed-identities failure" "$out" "needs at least"
  assert_not_contains "no profiles parse failure"        "$out" "profiles line"

  describe "doctor: --help and bad arg"
  assert_status "--help exits 0"      0 zsh "$doctor" --help
  assert_status "unknown arg exits 2" 2 zsh "$doctor" --bogus

  # ---- missing ssh Host block → failure for that alias ----
  local h2; h2=$(make_home); export HOME="$h2"
  # no ~/.ssh/config at all
  out=$(zsh "$doctor" 2>&1)
  describe "doctor: flags a missing SSH Host block"
  assert_contains "acme host missing reported" "$out" "no 'Host ssh-acme' block"

  # ---- malformed identities line → failure ----
  local h3; h3=$(make_home); export HOME="$h3"
  cat > "$h3/.config/git-identity/identities" <<IDS
acme   dev@acme.test   ssh-acme   gh-acme
brokenline
IDS
  out=$(zsh "$doctor" 2>&1)
  describe "doctor: flags a malformed identities line"
  assert_contains "malformed line reported" "$out" "needs at least <alias>"

  # ---- profile referencing an unknown alias → failure ----
  local h4; h4=$(make_home); export HOME="$h4"
  cat > "$h4/.config/git-identity/profiles" <<PRO
$h4/x/**   nosuchalias   owner
PRO
  out=$(zsh "$doctor" 2>&1)
  describe "doctor: flags a profile with an unknown alias"
  assert_contains "unknown-alias profile reported" "$out" "alias 'nosuchalias' is not in identities"

  # ---- missing lib.sh → hard fail, can't continue ----
  local h5; h5=$(make_home); export HOME="$h5"
  rm -f "$h5/.config/git-identity/lib.sh"
  describe "doctor: missing lib.sh fails"
  assert_status "exit 1 without lib.sh" 1 zsh "$doctor"
}
