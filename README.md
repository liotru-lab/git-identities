# git-identity

> # ⚠️ PERSONAL TOOLING — OPINIONATED, USE AT YOUR OWN RISK
>
> This repo encodes **my** specific multi-account GitHub workflow and personal
> preferences — it is shared as-is, **not** a general-purpose tool. The aliases,
> the `main`/`test`/`develop` branch scaffold, the SSH-host naming scheme, the
> directory→account conventions, and the entire starship prompt styling all
> reflect **my own needs and views**. Nothing here is a recommendation.
>
> **Fork it and adapt it. Do not expect it to fit your setup unchanged.**

Per-repo git identity management for juggling multiple GitHub accounts on one
machine. It keeps three things in agreement for every repository:

- **`user.email`** — who authors the commit
- **the remote's SSH host** — which key/account actually pushes
- **the prompt** — a short alias telling you, at a glance, who you are right now

When those disagree (e.g. you commit as one account but push through another),
the tooling flags it and offers to fix it.

---

## Concepts

An **identity** is a triple, declared once in `identities`:

| field      | meaning                                                        |
|------------|----------------------------------------------------------------|
| `alias`    | short label shown in the prompt, e.g. `<liotru>`               |
| `email`    | the git `user.email` for this account                          |
| `ssh-host` | a `Host` alias in `~/.ssh/config` that carries the right key   |

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

---

## Repo layout

```
.
├── install.sh                      deploy into ~/.config + ~/.local/bin
├── uninstall.sh                    remove (optionally --purge data)
├── bin/                            → ~/.local/bin/
│   ├── git-identity                check / sweep / interactively fix repos
│   ├── gitclone                    clone with the right identity applied
│   └── gitinit                     init with identity + branch + remote scaffold
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

---

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

---

## Configuration files

### `identities` — the source of truth

```
# alias    email                  ssh-host
work       you@company.com        github.com
personal   you@personal.example   github-personal
```

Adding an account is a one-line edit here — no script changes. Everything
(prompt, sweep, clone, init) reads this table.

### `profiles` — directory → account rules (for `gitclone` / `gitinit`)

```
# path-glob               alias      owner
~/Projects/clientA/**     work       clientA-org
~/Projects/personal/**    personal   my-gh-user
~/Projects/**             work       my-default-owner
```

Matched **top-to-bottom, first match wins** — put the catch-all last.
`owner` is the GitHub org/user used to build remote URLs in `gitinit`.

### `ignore` — repos to skip during `--sweep`

```
~/Projects/gopath/        # trailing slash: dir + everything below
**/node_modules/**        # glob: crosses slashes
~/Projects/one-repo       # plain: exact path
```

---

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

### `gitinit` — scaffold a new repo

```sh
cd ~/Projects/personal && gitinit my-thing
```

Default flow: `git init -b main` → set `user.email` → create `README.md` +
initial commit → create `test` and `develop` branches → switch to `develop` →
add `origin` (built as `git@<host>:<owner>/<name>.git` from the profile) and
configure `develop` to track `origin/develop`.

Flags: `--remote URL` (override the built URL), `--no-remote` (skip remote
setup), `--no-branches` (just init + email), `--profile <alias>`.

### Prompt

The starship prompt shows the active identity in angle brackets after the branch:

| state    | example            | color  | meaning                                   |
|----------|--------------------|--------|-------------------------------------------|
| match    | `<personal>`       | dim    | email and remote host agree               |
| mismatch | `<work!personal>`  | red    | author≠pusher (`email!host`)              |
| warn     | `<work!?https>`    | yellow | no remote / unknown email or host / HTTPS |

`GIT_IDENTITY_DEBUG=1` in front of `gitclone`/`gitinit` prints decisions.

---

## Requirements

- **zsh** (`/bin/zsh`) — all scripts are zsh; uses arrays, `vared`, `${~var}`.
- **git 2.28+** (for `git init -b`).
- **starship** for the prompt integration.
- A `Host` block in `~/.ssh/config` for every `ssh-host` in `identities`,
  each with its own `IdentityFile` and `IdentitiesOnly yes`.

---

## License

MIT — see [LICENSE](LICENSE). © 2026 Luca Romano.
