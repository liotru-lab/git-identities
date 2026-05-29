# Minimal assertion helpers for the pure-zsh test harness.
# Counters TOTAL/PASS/FAIL are integers owned by run.zsh.
# CURRENT names the group set by `describe`; asserts print it on failure.

CURRENT=""

describe() { CURRENT="$1" }

_pass() { (( PASS++ )); (( TOTAL++ )); [[ -n "${VERBOSE:-}" ]] && print -r -- "  ok  : $1" }
_fail() {
  (( FAIL++ )); (( TOTAL++ ))
  print -r -- "  FAIL: ${CURRENT:+$CURRENT — }$1"
  shift
  local l
  for l in "$@"; do print -r -- "        $l"; done
}

# assert_eq <desc> <expected> <actual>
assert_eq() {
  if [[ "$2" == "$3" ]]; then _pass "$1"
  else _fail "$1" "expected: [$2]" "actual:   [$3]"
  fi
}

# assert_empty <desc> <value>
assert_empty() {
  if [[ -z "$2" ]]; then _pass "$1"
  else _fail "$1" "expected empty, got: [$2]"
  fi
}

# assert_contains <desc> <haystack> <needle>
assert_contains() {
  if [[ "$2" == *"$3"* ]]; then _pass "$1"
  else _fail "$1" "string:  [$2]" "missing: [$3]"
  fi
}

# assert_not_contains <desc> <haystack> <needle>
assert_not_contains() {
  if [[ "$2" != *"$3"* ]]; then _pass "$1"
  else _fail "$1" "string:        [$2]" "should not have: [$3]"
  fi
}

# assert_status <desc> <expected-exit> <cmd...>
assert_status() {
  local desc="$1" want="$2"; shift 2
  "$@" >/dev/null 2>&1
  local got=$?
  if [[ "$got" == "$want" ]]; then _pass "$desc"
  else _fail "$desc" "expected exit: $want" "actual exit:   $got"
  fi
}

# assert_file <desc> <path>
assert_file() {
  if [[ -f "$2" ]]; then _pass "$1"
  else _fail "$1" "missing file: $2"
  fi
}

# assert_no_file <desc> <path>
assert_no_file() {
  if [[ ! -e "$2" ]]; then _pass "$1"
  else _fail "$1" "file should not exist: $2"
  fi
}
