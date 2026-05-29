#!/bin/zsh
# Pure-zsh test runner. Each test/cases/*.zsh file runs in its OWN zsh process
# (via test/lib/_case.zsh) so cases can't leak env (HOME, exports) into one
# another. Exit status is non-zero if any assertion failed.
#
#   zsh test/run.zsh           # run all
#   VERBOSE=1 zsh test/run.zsh # also print passing assertions

emulate -L zsh
setopt extended_glob null_glob

# Repo root = parent of this script's dir.
export REPO=${0:A:h:h}

integer TOTAL=0 PASS=0 FAIL=0 FILES=0

local f line
for f in "$REPO"/test/cases/[0-9]*.zsh(n); do
  (( FILES++ ))
  print -r -- "▸ ${f:t:r}"
  # Run the case isolated; stream its human output, capture the result marker.
  zsh "$REPO/test/lib/_case.zsh" "$f" | while IFS= read -r line; do
    if [[ "$line" == __RESULT__\ * ]]; then
      local -a parts=( ${(s: :)line} )
      (( PASS  += parts[2] ))
      (( FAIL  += parts[3] ))
      (( TOTAL += parts[4] ))
    else
      print -r -- "$line"
    fi
  done
done

print -r --
print -r -- "──────────────────────────────────────────"
if (( FAIL == 0 )); then
  print -r -- "PASS  ${PASS}/${TOTAL} assertions  (${FILES} files)"
else
  print -r -- "FAIL  ${FAIL} failed, ${PASS} passed, ${TOTAL} total  (${FILES} files)"
fi

(( FAIL == 0 ))
