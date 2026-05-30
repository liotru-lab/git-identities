# git-identity

[![tests](https://github.com/liotru-lab/git-identities/actions/workflows/test.yml/badge.svg)](https://github.com/liotru-lab/git-identities/actions/workflows/test.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> [!WARNING]
> **Personal opinionated tooling, use at your own risk.**
>
> This repo encodes **my** specific multi-account GitHub workflow and personal
> preferences — it is shared as-is, **not** a general-purpose tool. The aliases,
> the `main`/`test`/`develop` branch scaffold, the SSH-host naming scheme, the
> directory→account conventions, and the entire starship prompt styling all
> reflect **my own needs and views**. Nothing here is a recommendation.
> **Fork it and adapt it. Do not expect it to fit your setup unchanged.**

Per-repo git identity management for juggling multiple GitHub accounts on one
machine. It keeps three things in agreement for every repository:

- **`user.email`** — who authors the commit
- **the remote's SSH host** — which key/account actually pushes
- **the prompt** — a short alias telling you, at a glance, who you are right now

When those disagree (e.g. you commit as one account but push through another),
the tooling flags it and offers to fix it.

## Contents

- [Concepts](#concepts)
- [Repo layout](#repo-layout)
- [Install](#install)
- [Configuration files](#configuration-files)
- [Usage](#usage)
- [Requirements](#requirements)
- [License](#license)

## Concepts

An **identity** is a triple, declared once in `identities`:

| field      | meaning                                                      |
| ---------- | ------------------------------------------------------------ |
| `alias`    | short label shown in the prompt, e.g. `<liotru>`             |
| `email`    | the git `user.email` for this account                        |
| `ssh-host` | a `Host` alias in `~/.ssh/config` that carries the right key |

Each `ssh-host` maps to a block in `~/.ssh/config` that pins the SSH key:

```sshconfig
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_personal
    IdentitiesOnly yes
```

A repo is **OK** when its `user.email` alias matches its origin host alias.
Every other situation is a named state (see below).

## Repo layout

```text
.
├── install.sh                      deploy into ~/.config + ~/.local/bin
├── uninstall.sh                    remove (optionally --purge data)
├── bin/                            → ~/.local/bin/
│   ├── git-identity                check / sweep / interactively fix repos
│   ├── gitclone                    clone with the right identity applied
│   ├── gitinit                     init with identity + branch + remote scaffold
│   └── git-identity-doctor         verify install + config (run after install)
└── config/
    ├── starship/
    │   └── git-identity.toml        the 3 prompt modules, MERGED into
    │                                ~/.config/starship.toml (not a full config)
    └── git-identity/               → ~/.config/git-identity/
        ├── lib.sh                  shared logic + identity loader
        ├── starship.sh             prompt module backend
        ├── identities.example      template → identities (you fill in)
        ├── profiles.example        template → profiles
        └── ignore.example          template → ignore
```

**Code** (`bin/*`, `lib.sh`, `starship.sh`) is deployed from this repo. The
**starship modules** are merged into your existing `~/.config/starship.toml`
between managed markers — your tailored prompt config is never copied here.
**Data** (`identities`, `profiles`, `ignore`) lives only in
`~/.config/git-identity/` — your real emails/orgs never enter this repo.

## Install

```sh
./install.sh                # copy files into place
./install.sh --link         # symlink code to this repo (git pull updates tooling)
./install.sh --no-starship  # skip the prompt integration entirely
```

The starship step is **optional** — it's skipped automatically if `starship`
isn't installed, or explicitly with `--no-starship`. The CLI tools
(`git-identity`, `gitclone`, `gitinit`) work fully without it.

The installer:

- copies the three executables to `~/.local/bin/` (with `+x`)
- copies `lib.sh` and `starship.sh` to `~/.config/git-identity/`
- creates `identities`, `profiles`, `ignore` from the `.example` templates
  **only if absent** (never overwrites your edits)
- **merges** the three starship modules into your existing
  `~/.config/starship.toml` between `# >>> git-identity >>>` markers
  (idempotent; creates a minimal config if you don't have one), and warns if
  your `format` doesn't reference them or `command_timeout` is unset
- warns if `~/.local/bin` isn't on your `PATH`

> [!NOTE]
> Starship has no include mechanism, so the modules must live in your single
> `starship.toml`. Because of that, two things stay yours to maintain: the
> `${custom.git_email_*}` lines in your `format`, and `command_timeout = 3000`.
> `install.sh` injects the module blocks and tells you if either is missing.

Then configure your data files:

```sh
$EDITOR ~/.config/git-identity/identities   # your accounts
$EDITOR ~/.config/git-identity/profiles     # dir → account rules
exec zsh                                     # reload prompt + PATH
```

### Uninstall

```sh
./uninstall.sh          # remove code, strip the starship managed block, keep data
./uninstall.sh --purge  # also delete ~/.config/git-identity
```

Uninstall strips only the managed marker block from `starship.toml`; the rest of
your prompt config is untouched (the `${custom.git_email_*}` lines in your
`format` are left for you to remove).

## Configuration files

### `identities` — the source of truth

```text
# alias    email                  ssh-host          gh-user
work       you@company.com        github.com        you-at-work
personal   you@personal.example   github-personal   you
```

Adding an account is a one-line edit here — no script changes. Everything
(prompt, sweep, clone, init) reads this table.

The 4th column, **`gh-user`**, is optional: it's the GitHub username as known to
the [`gh`](https://cli.github.com) CLI, and is only needed when `gitinit` creates
the remote repo (its default), to pick which authenticated `gh` account to use.
Three-column lines (no `gh-user`) remain valid for every other command, and with
`gitinit --no-create`.

### `profiles` — directory → account rules (for `gitclone` / `gitinit`)

```text
# path-glob               alias      owner
~/Projects/clientA/**     work       clientA-org
~/Projects/personal/**    personal   my-gh-user
~/Projects/**             work       my-default-owner
```

Matched **top-to-bottom, first match wins** — put the catch-all last.
`owner` is the GitHub org/user used to build remote URLs in `gitinit`.

### `ignore` — repos to skip during `--sweep`

```text
~/Projects/gopath/        # trailing slash: dir + everything below
**/node_modules/**        # glob: crosses slashes
~/Projects/one-repo       # plain: exact path
```

## Usage

### `git-identity` — check & fix

```sh
git-identity                          # detailed report for the current repo
git-identity --auth                   # ...also test SSH auth to the host
git-identity --sweep ~/Projects       # one line per repo found
git-identity --sweep ~/Projects --porcelain      # tab-separated, for piping
git-identity --sweep ~/Projects --fix            # interactive fix, repo by repo
git-identity --sweep ~/Projects --fix --include-ignored   # revisit ignored repos
git-identity --sweep ~/Projects --fix --dry-run  # preview, write nothing
```

In `--fix` mode each problem repo offers context-aware actions: switch email to
the canonical one, rewrite the remote host, convert HTTPS→SSH, **skip** (just
this run), or **ignore** (persist to the `ignore` file). All applied changes are
logged to `~/.config/git-identity/migrate.log`.

### `gitclone` — clone with identity

```sh
gitclone --profile personal git@github.com:me/repo.git
gitclone git@github-personal:me/repo.git      # alias inferred from host
cd ~/Projects/clientA && gitclone git@github.com:clientA-org/api.git
```

Resolves an alias (flag → URL host → `profiles` by `$PWD`), rewrites the URL to
the right SSH host (and HTTPS→SSH), clones, then sets `user.email`. No match →
behaves exactly like `git clone`.

### `gitinit` — scaffold a new repo (and create it on GitHub)

```sh
cd ~/Projects/personal && gitinit my-thing               # create on GitHub + push
cd ~/Projects/personal && gitinit --public my-thing      # ...as a public repo
cd ~/Projects/personal && gitinit --no-create my-thing   # local scaffold only
```

`gitinit` is for **new** repos (use [`gitclone`](#gitclone--clone-with-identity)
for existing ones), so by default it goes all the way to GitHub.

Default flow: `git init -b main` → set `user.email` → create `README.md` +
initial commit → create `test` and `develop` branches → switch to `develop` →
add `origin` (built as `git@<host>:<owner>/<name>.git` from the profile),
configure `develop` to track `origin/develop` → **create the GitHub repo via
`gh` and push `develop`, `main`, `test`**.

The repo is created **private** by default (`--public` to override) under the
profile `owner` (falling back to the `gh-user`). This needs the alias to have a
`gh-user` (4th `identities` column) and that account authenticated in `gh`
(`gh auth login`) — the right account is selected per-command, so your global
`gh` state is left untouched.

#### Stopping early: `--no-create` vs `--no-remote`

These sound similar but stop at different points:

- **`--no-create`** — do the full local scaffold **including adding `origin`**,
  but don't create the GitHub repo or push. Use it when the remote already
  exists. Because it still wires up `origin`, it must build a remote URL, so it
  needs a `profiles` match (for the `owner`) **or** an explicit `--remote URL` —
  otherwise it errors with *"cannot determine remote URL"*. (Plain `gitinit`
  with no flags needs this too.)
- **`--no-remote`** — skip the remote step entirely: no `origin`, no creation,
  no push. Nothing to resolve, so it works anywhere (e.g. a throwaway repo in
  `/tmp`). Reach for this when you don't want a remote at all.

`--no-remote` and `--no-branches` both imply `--no-create` (you can't push
without a remote or commits).

```sh
gitinit my-thing                       # create on GitHub + push (needs owner)
gitinit --no-create my-thing           # local + origin, no GitHub  (needs owner)
gitinit --no-create --remote URL dir   # ...supply the owner/URL explicitly
gitinit --no-remote /tmp/scratch       # local only, no origin      (works anywhere)
```

Flags: `--no-create` (skip GitHub repo creation + push), `--remote URL`
(override the built URL), `--no-remote` (skip remote setup entirely),
`--no-branches` (just init + email), `--public` (create a public repo),
`--profile <alias>`.

### `git-identity-doctor` — verify your setup

Run after `install.sh` (or any time things look off) to sanity-check the
installation and configuration:

```sh
git-identity-doctor              # offline checks
git-identity-doctor --auth       # also test SSH auth + show each gh token's scopes
git-identity-doctor --init-test  # end-to-end: really create + push + delete a repo
```

It checks that the executables are on your `PATH`, the config files exist, the
`identities` table parses (flagging malformed lines and duplicates), every
`ssh-host` has a matching `Host` block in `~/.ssh/config`, `profiles` rules
reference known aliases, and `gh` is installed with each `gh-user` authenticated.

With **`--auth`** it additionally opens SSH connections per host and prints each
account's actual `gh` token scopes (failing if the `repo` scope `gitinit` needs
is missing, noting when `delete_repo` is absent).

With **`--init-test`** (implies `--auth`) it runs the real thing end-to-end:
`gitinit` creates a throwaway **private** repo on GitHub, pushes all three
branches, then deletes it — so it genuinely fails if `gh` permissions are wrong.
Deleting the test repo needs the `delete_repo` scope
(`gh auth refresh -h github.com -s delete_repo`); without it the test still
creates + pushes but reports the repo for manual deletion.

Exit status is non-zero if any check fails, so it works in scripts too.

### Prompt

The starship prompt shows the active identity in angle brackets after the branch:

| state    | example           | color  | meaning                                   |
| -------- | ----------------- | ------ | ----------------------------------------- |
| match    | `<personal>`      | dim    | email and remote host agree               |
| mismatch | `<work!personal>` | red    | author != pusher (`email!host`)           |
| warn     | `<work!?https>`   | yellow | no remote / unknown email or host / HTTPS |

`GIT_IDENTITY_DEBUG=1` in front of `gitclone`/`gitinit` prints decisions.

## Requirements

- **zsh** (`/bin/zsh`) — all scripts are zsh; uses arrays, `vared`, `${~var}`.
- **git 2.28+** (for `git init -b`).
- **starship** for the prompt integration.
- A `Host` block in `~/.ssh/config` for every `ssh-host` in `identities`,
  each with its own `IdentityFile` and `IdentitiesOnly yes`.

## License

MIT — see [LICENSE](LICENSE). © 2026 Luca Romano.
