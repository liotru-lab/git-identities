---
name: git-identity
description: Use the git-identity wrappers for git repo setup — `gitclone` instead of `git clone`, `gitinit` instead of `git init`, and `git-identity` to check or fix a repo's commit identity and GitHub owner. Trigger whenever cloning a repository, initializing or creating a new repo, or diagnosing a wrong commit author/email, push remote, or GitHub org.
allowed-tools: Bash(gitclone *) Bash(gitinit *) Bash(git-identity *) Bash(git-identity-doctor *)
---

# git-identity

[git-identity](https://github.com/liotru-lab/git-identities) keeps four things in
agreement per repo: the commit `user.email`, the push SSH host (key), the prompt
label, and the GitHub owner. Prefer its wrappers over raw git.

**If a command below is missing** (`command -v gitclone` fails), the toolkit isn't
installed — fall back to plain git and mention it can be installed via
`./install.sh` from the repo above. Don't try to replicate the tooling by hand.

## Cloning a repo

Use `gitclone` instead of `git clone` — it picks the identity (from the URL host
or the directory's profile), rewrites the URL to the right SSH host, clones, and
sets `user.email`:

```sh
gitclone <url> [dir]
```

## Creating a new repo

Use `gitinit` instead of `git init`. **Its argument is a child directory to
create — not the current one:**

- `gitinit` (no argument) → initialize the **current** directory as a new repo
- `gitinit <name>` → create subdirectory `<name>` and init it (run from the parent)

So to set up a folder you're already inside (e.g. `~/Projects/mailhub`), run
`gitinit` with **no argument** — `gitinit mailhub` there would nest
`mailhub/mailhub`. Passing a clone **URL** as the argument is refused (`gitinit`
takes a folder name, not a URL — use `gitclone <url>` to clone).

It scaffolds, sets identity, and (by default) creates the repo on GitHub and pushes:

```sh
gitinit                            # init the CURRENT dir (repo name = its basename)
gitinit <name>                     # create ./<name> and init it
gitinit --owner <org> <name>       # create under a specific org
gitinit -s <name>                  # main only (skip test/develop scaffold)
gitinit --no-create <name>         # local scaffold + origin only, no GitHub
```

Owner resolves: `--owner` → the directory's profile → the alias's gh-user. With
no matching profile, name the identity via `--profile <alias>`. `gitinit` prints
the resolved identity/owner before creating and warns when only the catch-all
profile matched.

**Existing folder with files?** `gitinit` works on it too — run `gitinit` inside
it, or `gitinit <name>` from the parent. It asks once before creating + pushing
(skip with `-y`/`--yes`). If the folder has a `.gitignore`, your tracked files
are committed; if not, only a README is committed and it tells you to add a
`.gitignore` and commit your code yourself. A folder that's already a git repo is
refused (use `git-identity` to fix its identity/owner instead).

## Adding a directory profile

A profile maps a directory glob to an identity + GitHub owner. Add one with:

```sh
git-identity --add-profile '~/Projects/<dir>/**' <alias> [owner]
```

It validates the alias and inserts the rule so it actually takes effect (above
any broader/catch-all rule). Then `git-identity-doctor --auth` confirms the owner
exists on GitHub.

## Checking / fixing a repo

Use `git-identity` to report or fix identity and owner drift:

```sh
git-identity                       # detailed report for the current repo
git-identity --fix                 # interactively fix this repo
git-identity --sweep [PATH]        # scan a tree (default: .), one line per repo
git-identity --sweep ~/Projects --fix
```

`--fix` handles wrong email/host, HTTPS→SSH, and **owner drift** (repo in the
wrong GitHub org) — for which it can transfer the repo on GitHub then repoint
`origin`. Verify the install/config any time with `git-identity-doctor`
(add `--auth` for SSH/gh/owner network checks).
