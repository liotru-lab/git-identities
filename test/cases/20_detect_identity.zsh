# Exercises detect_identity()'s full 8-state decision matrix against real repos.
# We build one repo per state and assert ID_STATE (plus a couple of derived vars).
# All identity values are synthetic (see test/lib/fixtures.zsh).

() {
  local h; h=$(make_home)
  export HOME="$h"
  export IDENTITIES_FILE="$h/.config/git-identity/identities"
  source "$h/.config/git-identity/lib.sh"

  local root; root=$(_mktemp_dir)

  mkrepo "$root/ok"          dev@acme.test     git@ssh-acme:o/r.git
  mkrepo "$root/mismatch"    dev@acme.test     git@ssh-globex:o/r.git
  mkrepo "$root/no-email"    ""                git@ssh-acme:o/r.git
  mkrepo "$root/no-remote"   dev@acme.test     ""
  mkrepo "$root/https"       dev@acme.test     https://github.com/o/r.git
  mkrepo "$root/unk-email"   stranger@x.test   git@ssh-acme:o/r.git
  mkrepo "$root/unk-host"    dev@acme.test     git@ssh-nope:o/r.git
  mkrepo "$root/unk-both"    stranger@x.test   git@ssh-nope:o/r.git

  describe "detect_identity: state matrix"
  detect_identity "$root/ok";        assert_eq "ok"                "ok"                 "$ID_STATE"
  detect_identity "$root/mismatch";  assert_eq "mismatch"          "mismatch"           "$ID_STATE"
  detect_identity "$root/no-email";  assert_eq "warn-no-email"     "warn-no-email"      "$ID_STATE"
  detect_identity "$root/no-remote"; assert_eq "warn-no-remote"    "warn-no-remote"     "$ID_STATE"
  detect_identity "$root/https";     assert_eq "warn-https"        "warn-https"         "$ID_STATE"
  detect_identity "$root/unk-email"; assert_eq "warn-unknown-email" "warn-unknown-email" "$ID_STATE"
  detect_identity "$root/unk-host";  assert_eq "warn-unknown-host" "warn-unknown-host"  "$ID_STATE"
  detect_identity "$root/unk-both";  assert_eq "warn-unknown-both" "warn-unknown-both"  "$ID_STATE"

  describe "detect_identity: derived vars"
  detect_identity "$root/ok"
  assert_eq "email alias resolved" "acme"     "$ID_E_ALIAS"
  assert_eq "host alias resolved"  "acme"     "$ID_H_ALIAS"
  assert_eq "host parsed"          "ssh-acme" "$ID_HOST"
  detect_identity "$root/mismatch"
  assert_eq "mismatch keeps both aliases" "acme/globex" "$ID_E_ALIAS/$ID_H_ALIAS"

  unset IDENTITIES_FILE
}
