#!/bin/zsh
# Runs a single case file in its own process for full isolation, then prints a
# machine-readable result line the runner parses. Invoked as:
#   zsh test/lib/_case.zsh <case-file>
# Env: REPO (repo root), VERBOSE (optional).

emulate -L zsh
setopt extended_glob null_glob no_unset

: ${REPO:?REPO must be set}
local case_file="$1"

source "$REPO/test/lib/assert.zsh"
source "$REPO/test/lib/fixtures.zsh"

integer TOTAL=0 PASS=0 FAIL=0
trap 'cleanup_fixtures' EXIT INT TERM

source "$case_file"

# Marker consumed by run.zsh (kept distinct from ordinary output).
print -r -- "__RESULT__ $PASS $FAIL $TOTAL"
