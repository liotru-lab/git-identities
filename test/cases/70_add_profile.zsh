# Integration: `git-identity --add-profile` — validates the alias, refuses
# duplicates, and (the important part) inserts the new rule BEFORE the first
# existing rule that would already capture the path, so it isn't shadowed by a
# broader/catch-all rule. All identity values are synthetic.

() {
  local h; h=$(make_home); export HOME="$h"
  export IDENTITIES_FILE="$h/.config/git-identity/identities"
  export PROFILES_FILE="$h/.config/git-identity/profiles"
  local gi="$REPO/bin/git-identity"

  cat > "$PROFILES_FILE" <<PRO
# pattern               alias    owner
~/Projects/special/**   globex   globex-org
~/Projects/**           acme     acme-default
PRO

  source "$h/.config/git-identity/lib.sh"

  describe "add-profile: lands above the catch-all so it takes effect"
  ( zsh "$gi" --add-profile '~/Projects/work/**' acme acme-org >/dev/null 2>&1 )
  match_profile "$HOME/Projects/work/x"
  assert_eq "new rule wins for its path"      "acme/acme-org"       "$pf_alias/$pf_owner"
  match_profile "$HOME/Projects/special/y"
  assert_eq "more-specific rule still wins"   "globex/globex-org"   "$pf_alias/$pf_owner"
  match_profile "$HOME/Projects/other/z"
  assert_eq "catch-all still applies elsewhere" "acme/acme-default" "$pf_alias/$pf_owner"

  describe "add-profile: owner is optional"
  ( zsh "$gi" --add-profile '~/Projects/noown/**' globex >/dev/null 2>&1 )
  match_profile "$HOME/Projects/noown/x"
  assert_eq "alias set, owner empty" "globex/" "$pf_alias/$pf_owner"

  describe "add-profile: validation"
  assert_status "duplicate pattern → exit 2" 2 zsh "$gi" --add-profile '~/Projects/work/**' acme acme-org
  assert_status "unknown alias → exit 2"     2 zsh "$gi" --add-profile '~/Projects/x/**' nosuch
  assert_status "missing args → exit 2"      2 zsh "$gi" --add-profile '~/Projects/x/**'

  describe "add-profile: a duplicate doesn't mutate the file"
  local before; before=$(wc -l < "$PROFILES_FILE")
  ( zsh "$gi" --add-profile '~/Projects/work/**' acme acme-org >/dev/null 2>&1 )
  assert_eq "line count unchanged after rejected dup" "$before" "$(wc -l < "$PROFILES_FILE")"

  unset IDENTITIES_FILE PROFILES_FILE
}
