# Unit tests for the pure helpers in lib.sh: identity loading, the four lookup
# maps, and SSH-host parsing. We point IDENTITIES_FILE at a fixture and source
# lib.sh directly (extended_glob is on, as the real entrypoints set it).
# All identity values are synthetic (see test/lib/fixtures.zsh).

() {
  local h; h=$(make_home)
  export IDENTITIES_FILE="$h/.config/git-identity/identities"
  source "$h/.config/git-identity/lib.sh"

  describe "lib: _load_identities"
  assert_eq  "loads two aliases in order"  "acme globex" "${ALIASES_ORDERED[*]}"
  assert_eq  "skips comment + header lines" 2 "${#ALIASES_ORDERED[@]}"

  describe "lib: lookup maps"
  assert_eq  "alias_to_email acme"   "dev@acme.test"  "$(alias_to_email acme)"
  assert_eq  "alias_to_host  globex" "ssh-globex"     "$(alias_to_host globex)"
  assert_eq  "email_to_alias"        "acme"           "$(email_to_alias dev@acme.test)"
  assert_eq  "host_to_alias"         "globex"         "$(host_to_alias ssh-globex)"
  assert_empty "unknown email → empty" "$(email_to_alias nobody@nowhere.test)"
  assert_empty "unknown alias → empty" "$(alias_to_host ghost)"

  describe "lib: alias_to_ghuser (optional 4th column)"
  assert_eq  "alias_to_ghuser acme"   "gh-acme"   "$(alias_to_ghuser acme)"
  assert_eq  "alias_to_ghuser globex" "gh-globex" "$(alias_to_ghuser globex)"
  assert_empty "unknown alias → empty" "$(alias_to_ghuser ghost)"

  describe "lib: 3-column identities still load (gh-user optional)"
  local legacy="$h/.config/git-identity/identities-legacy"
  print -r -- "solo  dev@solo.test  ssh-solo" > "$legacy"
  IDENTITIES_FILE="$legacy" _load_identities
  assert_eq  "alias loaded without gh-user"  "ssh-solo" "$(alias_to_host solo)"
  assert_empty "missing gh-user → empty"     "$(alias_to_ghuser solo)"
  # reload the standard fixture for any later assertions
  IDENTITIES_FILE="$h/.config/git-identity/identities" _load_identities

  describe "lib: parse_remote_host"
  assert_eq  "ssh url host"         "ssh-acme"   "$(parse_remote_host git@ssh-acme:owner/repo.git)"
  assert_eq  "plain github host"    "github.com" "$(parse_remote_host git@github.com:o/r.git)"
  assert_empty "https url → empty"  "$(parse_remote_host https://github.com/o/r.git)"
  assert_empty "garbage → empty"    "$(parse_remote_host not-a-url)"
  assert_empty "empty input → empty" "$(parse_remote_host '')"

  unset IDENTITIES_FILE
}
