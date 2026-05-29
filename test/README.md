# Tests

A small, dependency-free zsh test harness. No bats, no network, no real `$HOME`.

## Running

```sh
zsh test/run.zsh            # run everything
VERBOSE=1 zsh test/run.zsh  # also print each passing assertion
```

Exit status is `0` only if every assertion passed, so it doubles as the CI gate.

## Layout

```
test/
  run.zsh            entrypoint: runs each case file in its own process, tallies
  lib/
    _case.zsh        per-case process wrapper (isolation boundary)
    assert.zsh       assert_eq / assert_empty / assert_contains / assert_status / …
    fixtures.zsh     make_home, mkrepo, make_bare, add_local_remotes, cleanup
  cases/
    10_lib_pure.zsh        lib.sh: load, lookup maps, parse_remote_host
    20_detect_identity.zsh detect_identity()'s 8-state matrix
    30_sweep_ignore.zsh    --sweep, is_ignored (exact/dir/glob), porcelain, flags
    40_gitclone.zsh        alias resolution, host rewrite, HTTPS→SSH, email set
    50_gitinit.zsh         init + branches + remote URL building + tracking
```

## How isolation works

`run.zsh` runs every `cases/NN_*.zsh` file in a **separate** `zsh` process via
`lib/_case.zsh`. That guarantees one case can't leak `HOME`, exports, or globals
into the next — important because the integration cases reassign `$HOME` to a
throwaway dir. Each child prints a `__RESULT__ <pass> <fail> <total>` marker that
the parent sums; everything else it prints is streamed through verbatim.

## No network, no real identity

`make_home` builds a temp `$HOME` containing a copy of `lib.sh`, a fixture
`identities` table (made-up aliases `acme`, `globex` with `*.test` placeholder
emails), and an isolated `.gitconfig`. `add_local_remotes` + `make_bare` map the
aliased SSH hosts (`git@ssh-acme:`, `git@ssh-globex:`) to local bare repos
through git's `insteadOf`, so a "clone" reads from disk. Nothing reaches GitHub,
and no real email/host ever appears in the suite.

## Adding a case

Create `cases/NN_name.zsh`. Wrap the body in an anonymous function and use the
helpers:

```zsh
() {
  local h; h=$(make_home); export HOME="$h"
  source "$h/.config/git-identity/lib.sh"

  describe "my feature"
  assert_eq "does the thing" "expected" "$(some_command)"
}
```

`describe` labels the group shown on failure. Temp dirs created via the fixture
helpers are tracked and removed automatically when the case process exits.

> Heads-up for zsh: never name an ordinary variable `path` (it is tied to
> `$PATH`). The suite caught a real bug where `local path="$1"` clobbered `PATH`
> and silently broke every `git` call inside `--sweep`.
