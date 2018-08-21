#!/usr/bin/env bash

#####################################################################
function install_Vagrant() {
#####################################################################
    banner "Installing Vagrant"

    isAlreadyAvailableOnCLI "vagrant" && return
    brew_cask_install vagrant || exit 1
    brew_install vagrant-completion || exit 1
}

install_Vagrant
