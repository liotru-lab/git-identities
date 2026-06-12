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

Use `gitinit` instead of `git init` — it scaffolds, sets identity, and (by
default) creates the repo on GitHub and pushes:

```sh
gitinit <dir>                      # create on GitHub + push (owner from profile/gh-user)
gitinit --owner <org> <dir>        # create under a specific org
gitinit -s <dir>                   # main only (skip test/develop scaffold)
gitinit --no-create <dir>          # local scaffold + origin only, no GitHub
```

When there's no matching directory profile, name the identity with
`--profile <alias>` (owner then defaults to that account's own namespace unless
`--owner` is given).

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
