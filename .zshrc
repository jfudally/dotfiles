export PATH="/usr/local/opt/openssl/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/curl/lib -L/usr/local/opt/openssl/lib"
export CPPFLAGS="-I/usr/local/opt/curl/include -I/user/local/opt/openssl/include"
export ZSH="${HOME}/.oh-my-zsh"
export ANDROID_HOME=$HOME/Library/Android/sdk

export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH="/usr/local/opt/openjdk/bin:$PATH"
export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/workspace/scripts:$PATH"
export PATH="$HOME/.asdf/shims:$PATH"
export PATH="$(brew --prefix)/bin:$PATH"

ZSH_THEME="agnoster"

# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="false"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh
source $HOME/.aliases

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# General Exports
export EDITOR=vi
export SUDO_EDITOR=${EDITOR}

# Bindkeys
bindkey -v
bindkey '^R' history-incremental-search-backward

# External source files
if [[ -d ~/.sourceables ]] ; then
  for f in $(find ~/.sourceables -type f -print); do
    source ${f}
  done
fi

# Source asdf
. /opt/homebrew/opt/asdf/libexec/asdf.sh
