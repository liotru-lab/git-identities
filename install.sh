#!/bin/zsh
# install.sh — deploy the git-identity toolkit into your home config.
#
#   ./install.sh                 copy files into place (default)
#   ./install.sh --link          symlink code files to this repo instead of
#                                copying (so `git pull` updates your live tooling)
#   ./install.sh --no-starship   skip the starship prompt integration entirely
#
# Starship integration is auto-skipped if the `starship` binary isn't found.
#
# Code files (bin/*, lib.sh, starship.sh) are always refreshed. Data files
# (identities, profiles, ignore) are created from templates only if they don't
# already exist. The starship modules are MERGED into your existing
# ~/.config/starship.toml inside managed markers — the rest of your prompt
# config is left untouched.

set -e
set -u

REPO="${0:A:h}"
BIN_DST="$HOME/.local/bin"
CFG_DST="$HOME/.config/git-identity"
STARSHIP_DST="$HOME/.config/starship.toml"
SNIPPET="$REPO/config/starship/git-identity.toml"
BEGIN="# >>> git-identity >>>"
END="# <<< git-identity <<<"

info() { print -r -- "  $*" }
warn() { print -r -- "⚠ $*" }

link=0; no_starship=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --link)        link=1; shift ;;
    --no-starship) no_starship=1; shift ;;
    -h|--help)     sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) warn "unknown arg: $1"; shift ;;
  esac
done

mkdir -p "$BIN_DST" "$CFG_DST"

deploy() {  # deploy <src> <dst>  — copy, or symlink with --link
  local src="$1" dst="$2"
  if (( link )); then
    ln -sf "$src" "$dst"; info "linked  $dst"
  else
    cp "$src" "$dst";    info "copied  $dst"
  fi
}

# Merge the starship modules into ~/.config/starship.toml between markers.
# Idempotent: an existing managed block is replaced, never duplicated.
merge_starship() {
  local dst="$STARSHIP_DST"
  mkdir -p "${dst:h}"

  if [[ ! -f "$dst" ]]; then
    cat > "$dst" <<'TOML'
command_timeout = 3000

format = """
$directory\
$git_branch\
${custom.git_email_match}\
${custom.git_email_mismatch}\
${custom.git_email_warn}\
$git_status\
$cmd_duration\
$line_break\
$character"""
TOML
    info "created minimal $dst"
  fi

  # strip any previous managed block so re-running stays clean
  if grep -qF "$BEGIN" "$dst"; then
    awk -v b="$BEGIN" -v e="$END" \
      'index($0,b){s=1;next} index($0,e){s=0;next} !s{print}' \
      "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst"
  fi

  # never create duplicate TOML tables: if unmanaged git_email modules already
  # exist (e.g. you added them by hand before), leave the file untouched
  if grep -qE '^\[custom\.git_email_(match|mismatch|warn)\]' "$dst"; then
    warn "starship.toml already defines git_email modules (unmanaged) — left as-is."
    info "to convert them into a managed block, delete those 3 [custom.git_email_*]"
    info "blocks from $dst and re-run install.sh"
    return
  fi

  # advisory checks on the user's own content (before re-appending the block)
  grep -qF '${custom.git_email_match}' "$dst" || {
    warn "your starship format does not reference the modules; add after \$git_branch:"
    info '${custom.git_email_match}\'
    info '${custom.git_email_mismatch}\'
    info '${custom.git_email_warn}\'
  }
  grep -qE '^[[:space:]]*command_timeout[[:space:]]*=' "$dst" || \
    warn "no command_timeout in starship.toml; add 'command_timeout = 3000'"

  # append fresh managed block
  {
    print ""
    print -r -- "$BEGIN"
    print -r -- "# Managed by git-identity install.sh — do not edit between these markers."
    cat "$SNIPPET"
    print -r -- "$END"
  } >> "$dst"
  info "merged starship modules into $dst"
}

print "Installing git-identity toolkit from: $REPO"
print

# --- executables -> ~/.local/bin ---
for f in git-identity gitclone gitinit; do
  deploy "$REPO/bin/$f" "$BIN_DST/$f"
  chmod +x "$BIN_DST/$f"
done

# --- library + starship caller -> ~/.config/git-identity ---
deploy "$REPO/config/git-identity/lib.sh"      "$CFG_DST/lib.sh"
deploy "$REPO/config/git-identity/starship.sh" "$CFG_DST/starship.sh"
chmod +x "$CFG_DST/starship.sh"

# --- data templates -> only if not already present ---
for name in identities profiles ignore; do
  if [[ -e "$CFG_DST/$name" ]]; then
    info "kept    $CFG_DST/$name (already exists)"
  else
    cp "$REPO/config/git-identity/$name.example" "$CFG_DST/$name"
    info "created $CFG_DST/$name (from template)"
  fi
done

# --- starship modules -> merged into existing config (optional) ---
if (( no_starship )); then
  info "skipped starship modules (--no-starship)"
elif ! command -v starship >/dev/null 2>&1; then
  info "starship not found on PATH — skipped prompt modules"
  info "(install starship and re-run to add them)"
else
  merge_starship
fi

print
print "✓ Files in place."
print

# --- PATH check ---
case ":$PATH:" in
  *":$BIN_DST:"*) ;;
  *) warn "$BIN_DST is not on your PATH."
     info "add to ~/.zshrc:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

print "Next steps:"
print "  1. Fill in your identities:   \$EDITOR $CFG_DST/identities"
print "  2. Adjust directory profiles: \$EDITOR $CFG_DST/profiles"
print "  3. Ensure ~/.ssh/config has a Host block per ssh-host in identities."
print "  4. Reload the shell:          exec zsh"
print
print "Verify:  git-identity --sweep ~/Projects"
