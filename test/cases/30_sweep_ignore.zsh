# Integration: `git-identity --sweep` over a fixture tree, including the
# is_ignored matcher (exact path, trailing-slash dir prefix, glob) and the
# --porcelain / --include-ignored / --no-ignore flags.
# All identity values are synthetic (see test/lib/fixtures.zsh).

() {
  local h; h=$(make_home)
  export HOME="$h"

  local root; root=$(_mktemp_dir)
  mkrepo "$root/ok"        dev@acme.test  git@ssh-acme:o/r.git
  mkrepo "$root/bad"       dev@acme.test  git@ssh-globex:o/r.git
  mkrepo "$root/vendor"    dev@acme.test  git@ssh-globex:o/r.git   # ignored via glob
  mkrepo "$root/exact"     dev@acme.test  git@ssh-globex:o/r.git   # ignored exactly
  mkrepo "$root/skipdir/a" dev@acme.test  git@ssh-globex:o/r.git   # ignored via dir/

  cat > "$h/.config/git-identity/ignore" <<IGN
$root/exact
$root/skipdir/
$root/v*
IGN

  local gi="$REPO/bin/git-identity"

  describe "sweep: porcelain output"
  local out; out=$(zsh "$gi" --sweep "$root" --porcelain 2>/dev/null)
  assert_contains "ok repo present, state ok"     "$out" $'ok\t'
  assert_contains "bad repo present, mismatch"    "$out" $'mismatch\t'
  assert_not_contains "exact-ignored hidden"      "$out" "$root/exact"
  assert_not_contains "glob-ignored hidden"       "$out" "$root/vendor"
  assert_not_contains "dir-ignored hidden"        "$out" "$root/skipdir/a"

  describe "sweep: counts (human summary)"
  # Total counts every repo found (ignored ones included); Ignored is the subset
  # skipped, Needs-attention the non-ignored non-ok ones.
  out=$(zsh "$gi" --sweep "$root" 2>/dev/null)
  assert_contains "total counts all repos found" "$out" "Total: 5"
  assert_contains "one needs attention"          "$out" "Needs attention: 1"
  assert_contains "three ignored"                "$out" "Ignored: 3"

  describe "sweep: --include-ignored"
  out=$(zsh "$gi" --sweep "$root" --porcelain --include-ignored 2>/dev/null)
  assert_contains "ignored rows now shown" "$out" $'ignored\t'
  assert_contains "exact repo now listed"  "$out" "$root/exact"

  describe "sweep: --no-ignore"
  out=$(zsh "$gi" --sweep "$root" --porcelain --no-ignore 2>/dev/null)
  assert_contains "previously-ignored repo evaluated" "$out" "$root/vendor"

  describe "sweep: exit status reflects findings"
  # A tree with a mismatch present → non-zero.
  assert_status "non-zero when work remains" 1 zsh "$gi" --sweep "$root"
  # A clean-only subtree → zero.
  local clean; clean=$(_mktemp_dir)
  mkrepo "$clean/good" dev@acme.test git@ssh-acme:o/r.git
  assert_status "zero when all ok" 0 zsh "$gi" --sweep "$clean"

  describe "sweep: argument handling"
  assert_status "missing dir → exit 2" 2 zsh "$gi" --sweep "$root/does-not-exist"
  assert_status "unknown flag → exit 2" 2 zsh "$gi" --bogus
  assert_status "--help → exit 0" 0 zsh "$gi" --help
}
