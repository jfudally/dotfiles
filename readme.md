# Dotfiles

Shell environment (zsh + oh-my-zsh, vim, tmux) for **macOS** and **Ubuntu/Debian**.
One `install.sh` detects the platform and does the right thing on either.

## Install

```bash
git clone --recurse-submodules https://github.com/jfudally/dotfiles
cd dotfiles/
./install.sh
```

Already cloned without `--recurse-submodules`? `install.sh` runs
`git submodule init/update` for you, or run `make submodules` explicitly.

On Ubuntu the package step uses `sudo`, so expect a password prompt.

## Common commands

`make help` lists everything. The ones you'll actually use:

| Command | What it does |
| --- | --- |
| `make install` | Full install: configs + packages for this platform |
| `make install-configs` | Config files only, no package manager |
| `make packages` | Packages only, from `Brewfile` or `Aptfile` |
| `make test` | Run the test suite |
| `make lint` | Syntax-check every shell script and zsh config |
| `make submodules` | Fetch/update oh-my-zsh and the zsh plugins |

## Layout

```
install.sh              Entry point: detect platform, install configs + packages
lib/common.sh           Platform detection, logging, backup/copy helpers
scripts/
  packages_macos.sh     brew bundle against the Brewfile
  packages_ubuntu.sh    apt-get against the Aptfile, plus gh/uv/lsd installers
Brewfile                macOS package manifest
Aptfile                 Ubuntu/Debian package manifest
.zshrc .aliases         Shell config, platform-conditional throughout
.vimrc .tmux.conf       Editor and multiplexer config
tests/                  Dependency-free bash test suite
.oh-my-zsh/             Submodule: ohmyzsh/ohmyzsh
zsh-autosuggestions/    Submodule: zsh-users/zsh-autosuggestions
zsh-syntax-highlighting/ Submodule: zsh-users/zsh-syntax-highlighting
```

## How portability works

The configs are written so that **every path is added only if it exists**.
A host missing a toolchain gets a clean shell rather than a broken one.

* **Homebrew** — `.zshrc` probes `/opt/homebrew` (Apple Silicon), `/usr/local`
  (Intel), and `/home/linuxbrew/.linuxbrew` (Linuxbrew), then runs
  `brew shellenv`. Compiler flags for keg-only formulae derive from
  `$HOMEBREW_PREFIX` instead of a hardcoded prefix.
* **asdf** — searched across `~/.asdf`, the Homebrew prefix, and
  `/opt/asdf-vm`, rather than sourced from one hardcoded path.
* **Android SDK** — `~/Library/Android/sdk` on macOS, `~/Android/Sdk` on Linux,
  and only exported when the directory is actually present.
* **Renamed binaries** — Debian ships `bat` as `batcat` and `fd` as `fdfind`.
  The installer symlinks the upstream names into `~/.local/bin`, and `.aliases`
  falls back to the Debian names if it didn't.
* **DNS flush** — `dns-flush` maps to `killall -HUP mDNSResponder` on macOS and
  `resolvectl flush-caches` (or its predecessors) on Linux.

### Packages that differ by platform

| Tool | macOS | Ubuntu |
| --- | --- | --- |
| `gh` | Homebrew | GitHub's apt repo, added by the install script |
| `uv` | Homebrew | Official `astral.sh` installer |
| `lsd` | Homebrew | apt on 23.04+, otherwise an upstream `.deb` |
| `bat` | `bat` | `bat` package, `batcat` binary, symlinked to `bat` |
| 7-Zip | `sevenzip` | `p7zip-full` |
| Python | `python@3.13` | whatever `python3` the release pins |
| `mas` | Mac App Store CLI | no equivalent — omitted |
| `valkey`, `opensearch` | Homebrew services | run via Docker instead |

## Local overrides

Machine-specific settings and secrets belong in `~/.sourceables/` — every
regular file there is sourced last, so it wins over everything in `.zshrc`.
`~/.zprofile` is also sourced if present. Neither is tracked in this repo.

## Tests

```bash
make test
```

The suite is plain bash with no external dependencies, so it runs on a fresh
box before anything is installed. It covers platform detection, the installer's
behaviour on both platforms (via `DOTFILES_OS_OVERRIDE`), backup-before-
overwrite, and the absence of unguarded macOS-only paths in `.zshrc`.

To exercise the Ubuntu path for real on a Mac:

```bash
docker run --rm -it -v "$PWD:/dotfiles:ro" ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -qq sudo curl ca-certificates && \
   cp -r /dotfiles /work && cd /work && DOTFILES_SKIP_SUBMODULES=1 ./install.sh'
```

## Environment overrides

Used by the tests and CI; handy for debugging too.

| Variable | Effect |
| --- | --- |
| `DOTFILES_OS_OVERRIDE` | Force the detected platform (`macos`, `ubuntu`) |
| `DOTFILES_SKIP_PACKAGES` | Install configs only, skip the package manager |
| `DOTFILES_SKIP_SUBMODULES` | Don't run `git submodule init/update` |

## Notes

* Existing config files are moved to `<name>.bk` before being replaced —
  nothing is overwritten silently.
* `install.sh` does **not** change your login shell. If it isn't zsh already,
  the installer prints the `chsh` command to run.
