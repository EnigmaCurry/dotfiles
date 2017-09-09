#!/bin/bash

# This script is designed to be idempotent. You can run it as often as
# you wish. Run it once to perform initial setup, and run it again
# later to update your configuration.

# Fail fast if we get into trouble
set -e

GIT_HOME=$HOME/git

# Helpers
need_pkg() {
    # Require a package to be installed:
    pacman -T $1 > /dev/null || { echo >&2 "You need to install $1"; exit 1;}
}
exe() {
    # Log commands that are executed:
    echo "\$ $@"; "$@";
}
exe_fork() {
    # Log commands that are executed:
    # Wrap command into a new shell:
    echo "\$ $@"; bash -c "$@";
}
exe_nofail() {
    # Log commands that are executed:
    # Commands DO NOT have to execute succesfully:
    echo "\$ $@"; "$@" || true;
}
check_sudo() {
    if [ $UID == 0 ]; then
        echo "Do not execute this script as root. You will need sudo privileges though."
        exit 1
    else
        need_pkg sudo
        sudo -v
    fi    
}

prerequisites() {
    # Prerequisites
    check_sudo
    need_pkg rsync
    need_pkg findutils
}

setup_systemd_units() {
    # configure systemd units
    echo "### Copy systemd unit files"
    exe sudo rsync -a --chown=root:root systemd/system /etc/systemd
    echo "### Enable systemd units described in systemd/enable.sh"
    exe_fork "cat systemd/system_enabled.txt | grep -v '^#' | xargs sudo systemctl enable --now"
}

setup_systemd_networkd() {
    # Networking using systemd-networkd
    echo "### Setting up systemd-networkd"
    exe sudo systemctl mask netctl
    exe sudo systemctl enable --now systemd-networkd systemd-resolved
    exe sudo rm /etc/resolv.conf
    exe sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
    echo "### Copy network configs to /etc/systemd/network"
    exe sudo rsync -a --chown=root:root systemd/network /etc/systemd/
}

install_packages() {
    echo "### Installing packages"
    exe_fork "sudo pacman --noconfirm --needed -q -S - < packages.txt 2>&1 | grep -v 'up to date -- skipping'"
}

setup_dotfiles() {
    echo "### Linking dotfiles"
    mkdir -p $HOME/.config
    exe_fork "ls _config | xargs -iXX ln -f -s `pwd`/_config/XX $HOME/.config"
    exe_fork "ls | grep "^_" | grep -v "_config" | sed 's/_//' | xargs -iXX ln -f -s `pwd`/_XX $HOME/.XX"    
}

setup_emacs() {
    echo "### Setup Emacs"
    if [ -d "$GIT_HOME/emacs" ]; then
        echo "Skipping Emacs setup"
    else
        pushd $GIT_HOME
        git clone --origin https_origin https://github.com/EnigmaCurry/emacs.git
        ln -s -f `pwd`/emacs $HOME/.emacs.d
        popd
    fi
    
}

main() {
    prerequisites
    echo "### Running setup and showing you the exact commands run:"
    setup_systemd_networkd
    setup_systemd_units
    install_packages
    setup_dotfiles
    setup_emacs
}

main
