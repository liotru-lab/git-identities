#!/bin/zsh
# Emit identity state/display for the starship custom modules.
# Usage: starship.sh state | display

set -u

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 1

source "${0:A:h}/lib.sh"

detect_identity

case "$ID_STATE" in
  ok)        ss_state=match    ;;
  mismatch)  ss_state=mismatch ;;
  *)         ss_state=warn     ;;
esac

case "$ID_STATE" in
  ok)                 display="$ID_E_ALIAS" ;;
  mismatch)           display="$ID_E_ALIAS!$ID_H_ALIAS" ;;
  warn-no-email)      display="no-email" ;;
  warn-no-remote)     display="${ID_E_ALIAS:-$ID_EMAIL}" ;;
  warn-https)         display="${ID_E_ALIAS:-$ID_EMAIL}!?https" ;;
  warn-unknown-email) display="$ID_EMAIL" ;;
  warn-unknown-host)  display="$ID_E_ALIAS!?$ID_HOST" ;;
  warn-unknown-both)  display="$ID_EMAIL!?$ID_HOST" ;;
esac

case "${1:-display}" in
  state)   echo "$ss_state" ;;
  display) echo "$display"  ;;
  *) echo "usage: $0 state|display" >&2; exit 2 ;;
esac
