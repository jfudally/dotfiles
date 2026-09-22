# ~/.zshrc — interactive zsh configuration, portable across macOS and Ubuntu.
#
# Structure:
#   1. Locale & platform detection   5. oh-my-zsh
#   2. Homebrew                      6. General environment
#   3. Language toolchains           7. Keybindings
#   4. Application paths             8. Local overrides
#
# Section 1 must stay first: zsh fixes its character-set handling early, so
# the locale has to be set before the theme renders any Unicode glyph.
#
# Rule of thumb: every path below is added only if it actually exists, so a
# host missing a given toolchain starts a clean shell instead of a broken one.

# ── 1. Locale & platform detection ───────────────────────────────────────────

# Locale. The agnoster theme draws its prompt with Unicode powerline glyphs,
# which fail with "character not in range" under the C/POSIX locale -- the
# default on a minimal Ubuntu install, a container, or a bare SSH session.
# macOS always has a UTF-8 locale, so this is effectively Linux-only.
if [[ "${LC_ALL}${LANG}" != *[Uu][Tt][Ff]* ]]; then
  if (( ${+commands[locale]} )); then
    for _locale in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
      if locale -a 2>/dev/null | grep -qxF "${_locale}"; then
        export LANG="${_locale}"
        break
      fi
    done
    unset _locale
  fi
fi

case "$(uname -s)" in
  Darwin) DOTFILES_OS="macos" ;;
  Linux)  DOTFILES_OS="linux" ;;
  *)      DOTFILES_OS="unknown" ;;
esac
export DOTFILES_OS

# prepend_path <dir>
# Add a directory to the front of PATH, but only if it exists and is not
# already present. Keeps PATH clean across repeated `source ~/.zshrc`.
prepend_path() {
  [[ -d "$1" ]] || return 0
  case ":${PATH}:" in
    *":$1:"*) return 0 ;;
  esac
  export PATH="$1:${PATH}"
}

# prepend_flag <var-name> <flag>
# Add a compiler flag to the front of a flag variable unless it is already
# there. Same idempotency reasoning as prepend_path: without the check, every
# `source ~/.zshrc` would append another copy and LDFLAGS would grow without
# bound over a long-lived shell session.
prepend_flag() {
  local var="$1" flag="$2" current
  current="${(P)var}"
  case " ${current} " in
    *" ${flag} "*) return 0 ;;
  esac
  export "${var}=${flag}${current:+ ${current}}"
}

# ── 2. Homebrew ──────────────────────────────────────────────────────────────
# Three possible prefixes: Apple Silicon, Intel Mac, and Linuxbrew. `brew
# shellenv` sets PATH, MANPATH, and HOMEBREW_PREFIX correctly for whichever
# one is present.

for _brew_candidate in \
  /opt/homebrew \
  /usr/local \
  /home/linuxbrew/.linuxbrew \
  "${HOME}/.linuxbrew"
do
  if [[ -x "${_brew_candidate}/bin/brew" ]]; then
    eval "$("${_brew_candidate}/bin/brew" shellenv)"
    break
  fi
done
unset _brew_candidate

export HOMEBREW_NO_AUTO_UPDATE=1

# Compiler flags for keg-only formulae (openssl, curl) that build tooling needs
# to find. Derived from HOMEBREW_PREFIX rather than hardcoded to /usr/local,
# which was wrong on Apple Silicon and meaningless on Ubuntu.
if [[ -n "${HOMEBREW_PREFIX}" ]]; then
  for _keg in openssl curl; do
    if [[ -d "${HOMEBREW_PREFIX}/opt/${_keg}" ]]; then
      prepend_flag LDFLAGS  "-L${HOMEBREW_PREFIX}/opt/${_keg}/lib"
      prepend_flag CPPFLAGS "-I${HOMEBREW_PREFIX}/opt/${_keg}/include"
    fi
  done
  unset _keg
  prepend_path "${HOMEBREW_PREFIX}/opt/openssl/bin"
  prepend_path "${HOMEBREW_PREFIX}/opt/openjdk/bin"
fi

# ── 3. Language toolchains ───────────────────────────────────────────────────

# asdf. Location varies by platform and install method, and asdf 0.16+ dropped
# asdf.sh entirely in favour of a single binary plus its shims directory.
for _asdf_init in \
  "${HOME}/.asdf/asdf.sh" \
  "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/asdf/libexec/asdf.sh" \
  /opt/asdf-vm/asdf.sh \
  /usr/local/opt/asdf/libexec/asdf.sh
do
  if [[ -f "${_asdf_init}" ]]; then
    source "${_asdf_init}"
    break
  fi
done
unset _asdf_init

prepend_path "${HOME}/.asdf/shims"

# Android SDK. macOS and Linux use different default SDK locations; respect an
# already-exported ANDROID_HOME either way.
if [[ -z "${ANDROID_HOME}" ]]; then
  if [[ "${DOTFILES_OS}" == "macos" ]]; then
    ANDROID_HOME="${HOME}/Library/Android/sdk"
  else
    ANDROID_HOME="${HOME}/Android/Sdk"
  fi
fi
if [[ -d "${ANDROID_HOME}" ]]; then
  export ANDROID_HOME
  prepend_path "${ANDROID_HOME}/platform-tools"
  prepend_path "${ANDROID_HOME}/tools/bin"
  prepend_path "${ANDROID_HOME}/tools"
  prepend_path "${ANDROID_HOME}/emulator"
else
  unset ANDROID_HOME
fi

# ── 4. Application paths ─────────────────────────────────────────────────────

# VS Code ships its `code` CLI inside the app bundle on macOS; on Linux the
# package manager already puts it on PATH.
if [[ "${DOTFILES_OS}" == "macos" ]]; then
  prepend_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

prepend_path "${HOME}/workspace/scripts"
prepend_path "${HOME}/.local/bin"

# ── 5. oh-my-zsh ─────────────────────────────────────────────────────────────

export ZSH="${HOME}/.oh-my-zsh"

ZSH_THEME="agnoster"

DISABLE_AUTO_UPDATE="true"     # no bi-weekly auto-update checks
DISABLE_UPDATE_PROMPT="true"   # ...and no prompt about them
ENABLE_CORRECTION="false"      # no command auto-correction
COMPLETION_WAITING_DOTS="true" # red dots while completing

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# Guarded: a host that has these dotfiles but no oh-my-zsh yet (or a partial
# install) should still get a working shell.
if [[ -f "${ZSH}/oh-my-zsh.sh" ]]; then
  source "${ZSH}/oh-my-zsh.sh"
fi

[[ -f "${HOME}/.aliases" ]] && source "${HOME}/.aliases"
[[ -f "${HOME}/.zprofile" ]] && source "${HOME}/.zprofile"

# ── 6. General environment ───────────────────────────────────────────────────

export EDITOR=vi
export SUDO_EDITOR="${EDITOR}"

# ── 7. Keybindings ───────────────────────────────────────────────────────────

bindkey -v
bindkey '^R' history-incremental-search-backward

# ── 8. Local overrides ───────────────────────────────────────────────────────
# Anything dropped in ~/.sourceables is loaded last, so machine-specific
# settings and secrets win over everything above without being committed here.

if [[ -d "${HOME}/.sourceables" ]]; then
  for _f in "${HOME}"/.sourceables/*(.N); do
    source "${_f}"
  done
  unset _f
fi
