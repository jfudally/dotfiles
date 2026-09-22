#!/usr/bin/env bash
#
# test_install.sh — Integration tests for install.sh.
#
# Every test runs the real installer against a throwaway $HOME with package
# installation disabled, so the suite is safe to run repeatedly on a developer
# machine without touching the actual home directory or a package manager.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

# shellcheck source=./helpers.sh
source "${TEST_DIR}/helpers.sh"

SANDBOX="$(mktemp -d)"
trap 'rm -rf "${SANDBOX}"' EXIT

# run_install <fake-home> [env assignments...]
# Invoke install.sh against an isolated HOME, skipping package installation.
# Echoes combined output; returns the installer's exit status.
run_install() {
    local fake_home="${1}"; shift
    mkdir -p "${fake_home}"
    env HOME="${fake_home}" \
        DOTFILES_SKIP_PACKAGES=1 \
        DOTFILES_SKIP_SUBMODULES=1 \
        "$@" \
        bash "${REPO_ROOT}/install.sh" 2>&1
}

suite "install.sh runs on macOS"

home_mac="${SANDBOX}/home-mac"
out_mac="$(run_install "${home_mac}" DOTFILES_OS_OVERRIDE=macos)"
status=$?
assert_equals "0" "${status}" "installer exits cleanly on macos"

for config in .vimrc .aliases .zshrc .tmux.conf; do
    assert_file_exists "${home_mac}/${config}" "installs ${config} on macos"
done
assert_dir_exists "${home_mac}/.oh-my-zsh" "installs .oh-my-zsh on macos"

suite "install.sh runs on Ubuntu"

# The original installer called `brew bundle` unconditionally, which is fatal
# on a host with no Homebrew. Ubuntu must reach the end of the run.
home_ubuntu="${SANDBOX}/home-ubuntu"
out_ubuntu="$(run_install "${home_ubuntu}" DOTFILES_OS_OVERRIDE=ubuntu)"
status=$?
assert_equals "0" "${status}" "installer exits cleanly on ubuntu"

for config in .vimrc .aliases .zshrc .tmux.conf; do
    assert_file_exists "${home_ubuntu}/${config}" "installs ${config} on ubuntu"
done
assert_dir_exists "${home_ubuntu}/.oh-my-zsh" "installs .oh-my-zsh on ubuntu"

assert_not_contains "${out_ubuntu}" "brew bundle" \
    "ubuntu run never invokes brew bundle"

suite "oh-my-zsh plugins are installed"

for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    assert_dir_exists "${home_mac}/.oh-my-zsh/plugins/${plugin}" \
        "installs the ${plugin} plugin"
done

suite "existing files are backed up, not clobbered"

home_backup="${SANDBOX}/home-backup"
mkdir -p "${home_backup}"
printf 'my precious hand-written config\n' > "${home_backup}/.zshrc"
run_install "${home_backup}" DOTFILES_OS_OVERRIDE=macos >/dev/null

assert_file_exists "${home_backup}/.zshrc.bk" "pre-existing .zshrc is backed up"
assert_equals "my precious hand-written config" "$(cat "${home_backup}/.zshrc.bk")" \
    "backup retains the original contents"

suite "Brewfile is staged for macOS only"

assert_file_exists "${home_mac}/.local/env/Brewfile" "macos run stages the Brewfile"
if [[ -e "${home_ubuntu}/.local/env/Brewfile" ]]; then
    _fail "ubuntu run does not stage a Brewfile" "stray Brewfile found"
else
    _pass "ubuntu run does not stage a Brewfile"
fi
assert_file_exists "${home_ubuntu}/.local/env/Aptfile" "ubuntu run stages the Aptfile"

suite "unsupported platforms fail loudly"

home_weird="${SANDBOX}/home-weird"
out_weird="$(run_install "${home_weird}" DOTFILES_OS_OVERRIDE=plan9)"
status=$?
if [[ ${status} -ne 0 ]]; then
    _pass "installer refuses an unsupported platform"
else
    _fail "installer refuses an unsupported platform" "exited 0"
fi
assert_contains "${out_weird}" "plan9" "error message names the platform"

finish
