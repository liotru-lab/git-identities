#!/bin/zsh
# uninstall.sh — remove the git-identity toolkit from your home config.
#
#   ./uninstall.sh           remove code + starship modules; keep your data
#   ./uninstall.sh --purge    also delete ~/.config/git-identity (identities,
#                             profiles, ignore, migrate.log)

set -u

BIN_DST="$HOME/.local/bin"
CFG_DST="$HOME/.config/git-identity"
STARSHIP_DST="$HOME/.config/starship.toml"
BEGIN="# >>> git-identity >>>"
END="# <<< git-identity <<<"

purge=0
[[ "${1:-}" == "--purge" ]] && purge=1

info() { print -r -- "  $*" }

print "Removing git-identity toolkit..."
print

# executables
for f in git-identity gitclone gitinit; do
  if [[ -e "$BIN_DST/$f" || -L "$BIN_DST/$f" ]]; then
    rm -f "$BIN_DST/$f"; info "removed $BIN_DST/$f"
  fi
done

# code in config dir
for f in lib.sh starship.sh; do
  if [[ -e "$CFG_DST/$f" || -L "$CFG_DST/$f" ]]; then
    rm -f "$CFG_DST/$f"; info "removed $CFG_DST/$f"
  fi
done

# starship modules — strip the managed block, leave the rest of the config intact
if [[ -f "$STARSHIP_DST" ]] && grep -qF "$BEGIN" "$STARSHIP_DST"; then
  awk -v b="$BEGIN" -v e="$END" \
    'index($0,b){s=1;next} index($0,e){s=0;next} !s{print}' \
    "$STARSHIP_DST" > "$STARSHIP_DST.tmp" && mv "$STARSHIP_DST.tmp" "$STARSHIP_DST"
  info "removed git-identity block from $STARSHIP_DST"
  info "(the \${custom.git_email_*} lines in your format are yours to remove)"
else
  info "no git-identity block found in starship.toml"
fi

# data files
if (( purge )); then
  rm -rf "$CFG_DST"
  info "purged $CFG_DST (identities, profiles, ignore, migrate.log)"
else
  print
  print "Kept your data files in $CFG_DST (identities, profiles, ignore, migrate.log)."
  info "re-run with --purge to delete them too."
fi

print
print "Done. Reload your shell: exec zsh"
