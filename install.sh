#!/bin/bash
readonly configs=".vimrc .aliases .zshrc .tmux.conf"

git submodule init
git submodule update

for config in ${configs}; do
    dest="${HOME}/${config}"
    [[ -h ${dest} ]] && mv ${dest} ${dest}.bk
    cp ${config} ${dest}
done

for dir in ${dirs}; do
    dest="${HOME}/${dir}"
    [[ -d ${dest} ]] && rm -rf ${dest}
    rsync -a ${dir} ${HOME}
done

[[ -d ${HOME}/.oh-my-zsh ]] && rm -rf ${HOME}/.oh-my-zsh
rsync -a .oh-my-zsh ${HOME}
rsync -a zsh-autosuggestions ${HOME}/.oh-my-zsh/plugins
rsync -a zsh-syntax-highlighting ${HOME}/.oh-my-zsh/plugins
