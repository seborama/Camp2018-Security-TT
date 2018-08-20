#!/usr/bin/env bash

#####################################################################
function install_VirtualBox() {
#####################################################################
    banner "Installing VirtualBox"

    isAlreadyOSXInstalled "VirtualBox" && return
    brew_cask_install virtualbox || exit 1
    brew_cask_install virtualbox-extension-pack || exit 1
}

install_VirtualBox
