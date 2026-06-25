# git-identity

[![tests](https://github.com/liotru-lab/git-identities/actions/workflows/test.yml/badge.svg)](https://github.com/liotru-lab/git-identities/actions/workflows/test.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> [!NOTE]
> **Personal, opinionated tooling.**
>
> This repo encodes **my** specific multi-account GitHub workflow and personal
> preferences. The aliases, the `main`/`test`/`develop` branch scaffold, the
> SSH-host naming scheme, the directory→account conventions, and the starship
> prompt styling all reflect **my own needs**. It's shared in case it's useful —
> if it doesn't fit you, take what's helpful, fork it, and make it your own.

Per-repo git identity management for juggling multiple GitHub accounts on one
machine. It keeps four things in agreement for every repository:

- **`user.email`** — who authors the commit
- **the remote's SSH host** — which key/account actually pushes
- **the prompt** — a short alias showing who you are at a glance
- **the GitHub owner** — the org/user the repo lives under, checked against the
  owner your `profiles` rule expects for its directory

When they disagree — you commit as one account but push through another, or a
repo sits in a different org than its rule expects — the tooling flags it and
offers to fix it.

## Contents

- [Concepts](#concepts)
- [Repo layout](#repo-layout)
- [Install](#install)
- [Configuration files](#configuration-files)
- [Usage](#usage)
- [Claude Code skill](#claude-code-skill)
- [Requirements](#requirements)
- [License](#license)

## Concepts

An **identity** is a row in `identities` — up to four fields:

| field      | meaning                                                          |
| ---------- | --------------------------------------------------------------- |
| `alias`    | short label shown in the prompt, e.g. `<liotru>`                |
| `email`    | the git `user.email` for this account                           |
| `ssh-host` | a `Host` alias in `~/.ssh/config` that carries the right key    |
| `gh-user`  | *(optional)* the `gh` CLI account, used only when `gitinit` creates a repo |

Each `ssh-host` maps to a block in `~/.ssh/config` that pins the SSH key:

```sshconfig
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_personal
    IdentitiesOnly yes
```

A repo is **OK** when its `user.email` alias matches its origin SSH-host alias;
anything else is flagged — a **mismatch** (you'd commit as one account but push
as another) or a **warning** (missing/unknown email, host, or remote).

Independently, the tooling checks **owner drift**. The GitHub owner in a repo's
origin URL is a property of the repo, set once at clone/init — not of the
identity pushing it. But once a `profiles` rule declares an expected `owner` for
a path, a repo living under a *different* owner is flagged (`owner-drift`), even
when the identity itself is OK.

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
├── skills/
│   └── git-identity/SKILL.md       Claude Code skill → ~/.claude/skills/
├── .claude-plugin/                 plugin manifest (listed in the liotru-lab marketplace)
│   └── plugin.json
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
between managed markers — your tailored prompt config is never copied here. The
**Claude Code skill** is deployed to `~/.claude/skills/` so Claude prefers the
wrappers (see [Claude Code skill](#claude-code-skill)). **Data** (`identities`,
`profiles`, `ignore`) lives only in `~/.config/git-identity/` — your real
emails/orgs never enter this repo.

## Install

```sh
./install.sh                # copy files into place
./install.sh --link         # symlink code to this repo (git pull updates tooling)
./install.sh --no-starship  # skip the prompt integration entirely
./install.sh --no-skill     # skip installing the Claude Code skill
```

The installer copies the four executables to `~/.local/bin/` and `lib.sh` +
`starship.sh` to `~/.config/git-identity/`; creates `identities`, `profiles`,
`ignore` from the `.example` templates **only if absent** (never overwriting
your edits); **merges** the three starship modules into your existing
`~/.config/starship.toml` between `# >>> git-identity >>>` markers (idempotent,
creating a minimal config if you have none); installs the Claude Code skill to
`~/.claude/skills/`; and warns if `~/.local/bin` isn't on your `PATH`.

Both integrations are optional: the **starship** step is auto-skipped if
`starship` isn't installed (or with `--no-starship`), and the **Claude Code
skill** is auto-skipped if Claude Code isn't detected (or with `--no-skill`). The
CLI tools work fully without either.

> [!NOTE]
> Starship has no include mechanism, so the modules must live in your single
> `starship.toml`. Two things stay yours to maintain: the `${custom.git_email_*}`
> lines in your `format`, and `command_timeout = 3000`. `install.sh` injects the
> module blocks and tells you if either is missing.

Then fill in your data files and reload the shell:

```sh
$EDITOR ~/.config/git-identity/identities   # your accounts
$EDITOR ~/.config/git-identity/profiles     # dir → account rules
exec zsh                                     # reload prompt + PATH
```

### Uninstall

```sh
./uninstall.sh          # remove code + skill, strip the starship block, keep data
./uninstall.sh --purge  # also delete ~/.config/git-identity
```

Uninstall removes the executables and the Claude Code skill, and strips only the
managed marker block from `starship.toml` — the rest of your prompt config
(including the `${custom.git_email_*}` lines) is left for you to remove.

## Configuration files

All three live only in `~/.config/git-identity/`.

### `identities` — the source of truth

```text
# alias    email                  ssh-host          gh-user
work       you@company.com        github.com        you-at-work
personal   you@personal.example   github-personal   you
```

One line per account; everything (prompt, sweep, clone, init) reads this table,
so adding an account is a one-line edit — no script changes. The 4th column
**`gh-user`** is optional — the GitHub username as `gh` knows it, needed only
when `gitinit` creates the remote repo, to pick which authenticated `gh` account
to use. Three-column lines work for everything else (and `gitinit --no-create`).

### `profiles` — directory → account rules

```text
# path-glob               alias      owner
~/Projects/clientA/**     work       clientA-org
~/Projects/personal/**    personal   my-gh-user
~/Projects/**             work       my-default-owner
```

Matched **top-to-bottom, first match wins** — put the catch-all last.
`gitclone`/`gitinit` use these to pick the identity and build remote URLs, and
the `owner` doubles as the **expected owner** for `git-identity`'s owner-drift
check.

Add a rule without hand-editing (and without the ordering footgun) via
[`git-identity --add-profile`](#git-identity--check--fix); it inserts the rule
above any broader rule that would otherwise shadow it.

### `ignore` — repos to skip during `--sweep`

```text
~/Projects/gopath/        # trailing slash: dir + everything below
**/node_modules/**        # glob: crosses slashes
~/Projects/one-repo       # plain: exact path
```

## Usage

### `git-identity` — check & fix

```sh
git-identity                                 # detailed report for the current repo
git-identity --auth                          # ...also test SSH auth to the host
git-identity --sweep [PATH]                  # one line per repo under PATH (default: .)
git-identity --sweep ~/Projects --porcelain  # tab-separated, for piping
git-identity --sweep ~/Projects --fix        # interactive fix, repo by repo
```

Other sweep flags: `--include-ignored` (revisit ignored repos), `--dry-run`
(preview, write nothing), `--ignore-file PATH`, `--no-ignore`.

Add a `profiles` rule with **`--add-profile`** (no hand-editing, no ordering
footgun — it inserts the rule above any broader rule that would shadow it):

```sh
git-identity --add-profile '~/Projects/clientA/**' work clientA-org
```

In `--fix` mode each flagged repo offers context-aware actions — switch email to
the canonical one, rewrite the remote host, convert HTTPS→SSH, **skip** (just
this run), or **ignore** (persist to the `ignore` file). For **owner drift** it
offers either **(l)** repoint `origin` to the expected owner (when the repo
already moved on GitHub and only the local remote is stale), or **(t)** transfer
the repo on GitHub (`gh api repos/<owner>/<repo>/transfer`) then repoint — gated
on `gh` being installed and the alias having a `gh-user`, with an extra confirm
since transfers are hard to undo. All applied changes are logged to
`~/.config/git-identity/migrate.log`.

### `gitclone` — clone with identity

```sh
gitclone --profile personal git@github.com:me/repo.git
gitclone git@github-personal:me/repo.git      # alias inferred from host
cd ~/Projects/clientA && gitclone git@github.com:clientA-org/api.git
```

Resolves an alias (flag → URL host → `profiles` by `$PWD`), rewrites the URL to
the right SSH host (and HTTPS→SSH), clones, then sets `user.email`. No match →
behaves exactly like `git clone`.

### `gitinit` — scaffold a repo (new or existing folder) and create it on GitHub

```sh
cd ~/Projects/personal && gitinit my-thing     # create ./my-thing on GitHub + push
cd ~/Projects/personal/my-thing && gitinit     # init the CURRENT dir (no argument)
gitinit --profile personal my-thing            # no profile match? name the identity
gitinit --profile work --owner some-org thing  # ...and create it under some-org
gitinit --public my-thing                      # public instead of private
gitinit -s my-thing                            # main only (no test/develop)
gitinit --no-remote /tmp/scratch               # local only, no origin
```

> [!IMPORTANT]
> `gitinit`'s argument is a **child directory to create**, not the current one.
> `gitinit <name>` makes `./<name>`; **`gitinit` with no argument** inits the
> directory you're already in. So inside `~/Projects/mailhub`, run `gitinit`
> (not `gitinit mailhub`, which would nest `mailhub/mailhub`).

**Existing, non-empty folder?** `gitinit` adopts it (run `gitinit` inside it, or
`gitinit <name>` from the parent). It asks once before creating + pushing
(`-y`/`--yes` to skip). With a `.gitignore` your tracked files go into the initial
commit; **without one only a README is committed** and `gitinit` tells you to add
a `.gitignore` and commit your code yourself. A folder that's already a git repo
is refused (use `git-identity` to fix its identity/owner instead).

For new repos (and to adopt existing local folders). Default flow:
`git init -b main` → set `user.email` → `README.md` + initial commit → create
`test` and `develop` branches and switch to `develop` → add `origin`
(`git@<host>:<owner>/<name>.git`) → **create the private GitHub repo via `gh` and
push `develop`, `main`, `test`**. The right `gh` account is selected per-command,
so your global `gh` state is left untouched.

The **owner** (who the repo is created and pushed under) is taken from the
`--remote` URL when you pass one; otherwise it resolves as **`--owner` → the
`profiles` rule's owner → the alias's own `gh-user` namespace**. That last
fallback means `gitinit --profile <alias> <dir>` works with no profile and no
`--remote` — it just creates under your own account.

Flags:

- **`--owner <org/user>`** — create/push under this owner (overrides the profile;
  defaults to the alias's `gh-user`).
- **`--profile <alias>`** — force the identity instead of matching `profiles`.
- **`-s`, `--simple`** — `main` only: no `test`/`develop`, stays on `main`, tracks
  and pushes only `main`. Composes with everything below.
- **`-y`, `--yes`** — skip the confirmation prompt when adopting an existing folder.
- **`--public`** — create a public repo (default: private).
- **`--no-create`** — full local scaffold **including `origin`**, but don't create
  the GitHub repo or push (the remote already exists).
- **`--remote URL`** — supply the full remote URL explicitly (host still rewritten
  to the alias's; its owner becomes the create target).
- **`--no-remote`** — skip the remote entirely (no `origin`, creation, or push);
  works anywhere, e.g. a throwaway repo in `/tmp`.
- **`--no-branches`** — just `init` + `user.email`.

`--no-remote` and `--no-branches` both imply `--no-create` (you can't push
without a remote or commits).

### `git-identity-doctor` — verify your setup

```sh
git-identity-doctor              # offline checks
git-identity-doctor --auth       # + SSH auth, gh token scopes, profile-owner existence
git-identity-doctor --init-test [alias]   # end-to-end: really create + push + delete
```

Offline it checks that the executables are on your `PATH`, the config files
exist, the installed `lib.sh` is current enough for the owner-drift check (a
stale install fails with a "re-run install.sh" hint), `identities` parses
(flagging malformed lines and duplicates), every `ssh-host` has a matching `Host`
block, `profiles` aliases are known, and `gh` is installed with each `gh-user`
authenticated.

**`--auth`** adds network checks: SSH auth per host, each token's actual `gh`
scopes (needs `repo`), and that every owner declared in `profiles` actually
exists on GitHub — catching a typo'd owner (`reachnetap` vs `reachnetapp`) that
would otherwise surface as confusing owner-drift on every repo under that rule.

**`--init-test [alias]`** (implies `--auth`) runs the real thing end-to-end:
`gitinit` creates a throwaway private repo, pushes, then deletes it — so it
genuinely fails if `gh` permissions are wrong. Deleting needs the `delete_repo`
scope (`gh auth refresh -h github.com -s delete_repo`); without it the repo is
left for manual cleanup. Tests under the given `alias`, else the first identity
with a `gh-user`. Exit status is non-zero if any check fails.

### Prompt

The starship prompt shows the active identity in angle brackets after the branch:

| state    | example           | color  | meaning                                   |
| -------- | ----------------- | ------ | ----------------------------------------- |
| match    | `<personal>`      | dim    | email and remote host agree               |
| mismatch | `<work!personal>` | red    | author != pusher (`email!host`)           |
| warn     | `<work!?https>`   | yellow | no remote / unknown email or host / HTTPS |

`GIT_IDENTITY_DEBUG=1` in front of `gitclone`/`gitinit` prints decisions.

## Claude Code skill

The repo ships a [Claude Code](https://claude.com/claude-code) skill at
`skills/git-identity/SKILL.md`. `install.sh` deploys it to
`~/.claude/skills/git-identity/` (auto-skipped when Claude Code isn't detected,
or with `--no-skill`), so Claude prefers the wrappers — `gitclone` over
`git clone`, `gitinit` over `git init`, and `git-identity` for identity/owner
checks. It degrades gracefully (points back at `install.sh`) on a machine where
the commands aren't installed.

A skill is *model-invoked* from its description, so it makes Claude reach for the
wrappers when your request matches. To make that the hard default, also add a
line to your `CLAUDE.md` (user-level `~/.claude/CLAUDE.md` or per-project):

```markdown
When setting up git repos, prefer the git-identity wrappers: `gitclone` instead
of `git clone`, `gitinit` instead of `git init`, and `git-identity --fix` to
check/fix identity & owner. Fall back to plain git if those commands are absent.
```

### Install the skill as a plugin

This repo is a plugin in the shared **`liotru-lab`** Claude Code marketplace
([liotru-lab/plugins](https://github.com/liotru-lab/plugins)), so you can get the
skill without cloning — across all your projects:

```text
/plugin marketplace add liotru-lab/plugins
/plugin install git-identity@liotru-lab
```

> [!IMPORTANT]
> The plugin ships only the **skill** — Claude Code plugins can't put the
> `gitclone`/`gitinit`/`git-identity` executables on your `PATH`. You still need
> the CLI itself: clone this repo and run `./install.sh` (which also deploys the
> skill, so the plugin is mainly for discovery / skill-only setups). The skill
> degrades gracefully and points back at `install.sh` when the commands are
> absent.

## Requirements

- **zsh** (`/bin/zsh`) — all scripts are zsh; uses arrays, `vared`, `${~var}`.
- **git 2.28+** (for `git init -b`).
- **starship** — for the prompt integration only.
- **Claude Code** — optional; only to use the bundled skill.
- **gh** (GitHub CLI) — for `gitinit`'s repo creation and `git-identity --fix`'s
  owner-drift transfer. Each account's token needs the `repo` scope (and
  `delete_repo` only for `git-identity-doctor --init-test`'s cleanup); a transfer
  also needs admin on the repo and create rights in the target owner.
- A `Host` block in `~/.ssh/config` for every `ssh-host` in `identities`, each
  with its own `IdentityFile` and `IdentitiesOnly yes`.

## License

MIT — see [LICENSE](LICENSE). © 2026 Luca Romano.
