#!/usr/bin/env bash

#####################################################################
function install_brew() {
#####################################################################
    banner "Installing Homebrew"

    which -s brew && return

    echo "Homebrew is a pre-requisite but I can't locate your installation."
    local choice
    read -p "Perform homebrew installation (y/N)? " choice
    if [[ ! "${choice}" =~ ^[Yy1]$ ]]; then
        echo "OK, you will need to install the required software (Docker, Vagrant, etc) yourself"
        return
    fi

    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
    brew analytics off
    brew update || exit 1
    echo Done
}

install_brew
