# Owner-drift detection: the repo's GitHub owner on disk vs the owner the
# profiles file declares for its path. This axis is orthogonal to ID_STATE
# (identity can be OK while the owner has drifted). Covers detect_identity's
# ID_OWNER_STATE, the sweep tally/porcelain state, and the --fix handlers
# (local repoint + stubbed gh transfer). All values synthetic; no network.

() {
  local h; h=$(make_home)
  export HOME="$h"
  export IDENTITIES_FILE="$h/.config/git-identity/identities"
  export PROFILES_FILE="$h/.config/git-identity/profiles"

  # Physical root so it matches `git rev-parse --show-toplevel` (macOS resolves
  # /tmp → /private/tmp). Repos live one level BELOW each profile glob root,
  # exactly as in real usage (~/Projects/<area>/** → ~/Projects/<area>/<repo>).
  local root; root=$(_mktemp_dir); root=${root:A}

  # Profiles: declare an expected owner per area (one with a blank owner).
  cat > "$PROFILES_FILE" <<PRO
$root/m/**     acme   acme-org
$root/c/**     acme   acme-org
$root/d/**     acme   acme-org
$root/u/**     acme   acme-org
$root/no/**    acme
PRO

  mkrepo "$root/m/repo"  dev@acme.test  git@ssh-acme:acme-org/repo.git    # match
  mkrepo "$root/c/repo"  dev@acme.test  git@ssh-acme:Acme-Org/repo.git    # match, diff case
  mkrepo "$root/d/repo"  dev@acme.test  git@ssh-acme:wrong-org/repo.git   # drift
  mkrepo "$root/u/repo"  dev@acme.test  git@ssh-acme:repo.git             # owner unparseable
  mkrepo "$root/no/repo" dev@acme.test  git@ssh-acme:anything/repo.git    # profile owner blank
  mkrepo "$root/x/repo"  dev@acme.test  git@ssh-acme:anything/repo.git    # no profile at all

  source "$h/.config/git-identity/lib.sh"

  describe "parse_remote_owner"
  assert_eq "scp-like SSH" "acme-org" "$(parse_remote_owner git@ssh-acme:acme-org/repo.git)"
  assert_eq "https"        "acme-org" "$(parse_remote_owner https://github.com/acme-org/repo.git)"
  assert_eq "ssh url"      "acme-org" "$(parse_remote_owner ssh://git@github.com/acme-org/repo.git)"
  assert_empty "no owner"  "$(parse_remote_owner git@ssh-acme:repo.git)"

  describe "detect_identity: owner-drift axis"
  detect_identity "$root/m/repo"
  assert_eq "match → identity ok"      "ok"       "$ID_STATE"
  assert_eq "match → owner ok"         "ok"       "$ID_OWNER_STATE"
  assert_eq "expected owner resolved"  "acme-org" "$ID_EXPECTED_OWNER"

  detect_identity "$root/c/repo"
  assert_eq "owner case-insensitive → owner ok" "ok" "$ID_OWNER_STATE"
  assert_eq "owner keeps actual casing"  "Acme-Org" "$ID_OWNER"

  detect_identity "$root/d/repo"
  assert_eq "drift → identity still ok" "ok"        "$ID_STATE"
  assert_eq "drift → owner drift"       "drift"     "$ID_OWNER_STATE"
  assert_eq "drift → actual owner"      "wrong-org" "$ID_OWNER"
  assert_eq "drift → expected owner"    "acme-org"  "$ID_EXPECTED_OWNER"

  detect_identity "$root/u/repo"
  assert_eq "unparseable owner → unknown" "unknown" "$ID_OWNER_STATE"

  detect_identity "$root/no/repo"
  assert_eq "blank profile owner → no expectation" "ok" "$ID_OWNER_STATE"
  assert_empty "no expected owner" "$ID_EXPECTED_OWNER"

  detect_identity "$root/x/repo"
  assert_eq "no profile → owner ok" "ok" "$ID_OWNER_STATE"
  assert_empty "no expected owner (no profile)" "$ID_EXPECTED_OWNER"

  # ---- Sweep: porcelain state column + needs-attention tally ----
  local gi="$REPO/bin/git-identity"
  local out; out=$(zsh "$gi" --sweep "$root" --porcelain --no-ignore 2>/dev/null)
  describe "sweep --porcelain reflects owner drift"
  assert_eq "match repo → ok"            "ok"            "$(print -r -- "$out" | grep "$root/m/repo\$"  | cut -f1)"
  assert_eq "drift repo → owner-drift"   "owner-drift"   "$(print -r -- "$out" | grep "$root/d/repo\$"  | cut -f1)"
  assert_eq "unknown repo → owner-unknown" "owner-unknown" "$(print -r -- "$out" | grep "$root/u/repo\$"  | cut -f1)"
  assert_eq "blank-owner repo → ok"      "ok"            "$(print -r -- "$out" | grep "$root/no/repo\$" | cut -f1)"

  local summary; summary=$(zsh "$gi" --sweep "$root" --no-ignore 2>/dev/null | tail -1)
  describe "sweep summary counts drift + unknown as needs-attention"
  assert_contains "needs attention = 2 (drift + unknown)" "$summary" "Needs attention: 2"

  # ---- Fix: local repoint (l) ----
  describe "--fix (l) repoints origin to the expected owner"
  local rd; rd=$(_mktemp_dir); rd=${rd:A}
  cat > "$PROFILES_FILE" <<PRO
$rd/area/**   acme   acme-org
PRO
  mkrepo "$rd/area/proj" dev@acme.test git@ssh-acme:wrong-org/proj.git
  ( cd "$rd/area/proj" && printf 'l\ny\n' | zsh "$gi" --fix >/dev/null 2>&1 )
  assert_eq "origin repointed" "git@ssh-acme:acme-org/proj.git" \
    "$(git -C "$rd/area/proj" remote get-url origin 2>/dev/null)"

  # ---- Fix: gh transfer (t), dry-run — prints intent, calls nothing ----
  describe "--fix (t) --dry-run prints the transfer, runs no gh"
  local stub; stub=$(_mktemp_dir)/bin
  make_gh_stub "$stub"   # gh-acme authenticated
  mkrepo "$rd/area/proj2" dev@acme.test git@ssh-acme:wrong-org/proj2.git
  local dry
  dry=$( cd "$rd/area/proj2" && printf 't\ny\n' | env PATH="$stub:$PATH" zsh "$gi" --fix --dry-run 2>&1 )
  assert_contains "shows gh api transfer"  "$dry" "would run: gh api"
  assert_contains "targets expected owner" "$dry" "new_owner=acme-org"
  assert_no_file "no gh call logged in dry-run" "$stub/gh-calls.log"

  # ---- Fix: gh transfer (t), executed against the stub ----
  describe "--fix (t) performs the transfer (stubbed) and repoints origin"
  mkrepo "$rd/area/proj3" dev@acme.test git@ssh-acme:wrong-org/proj3.git
  ( cd "$rd/area/proj3" && printf 't\ny\n' | env PATH="$stub:$PATH" zsh "$gi" --fix >/dev/null 2>&1 )
  assert_eq "origin repointed after transfer" "git@ssh-acme:acme-org/proj3.git" \
    "$(git -C "$rd/area/proj3" remote get-url origin 2>/dev/null)"
  assert_file "gh was invoked" "$stub/gh-calls.log"
  assert_contains "gh api transfer logged" "$(cat "$stub/gh-calls.log")" \
    "repos/wrong-org/proj3/transfer"
  assert_contains "transfer targets expected owner" "$(cat "$stub/gh-calls.log")" \
    "new_owner=acme-org"

  unset IDENTITIES_FILE PROFILES_FILE
}
