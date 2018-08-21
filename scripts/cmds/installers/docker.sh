#!/usr/bin/env bash

#####################################################################
function install_Docker() {
#####################################################################
    banner "Installing Docker"

    isAlreadyOSXInstalled "Docker" && isAlreadyAvailableOnCLI "docker" && return
    brew_cask_install docker || exit 1
    brew_install docker-completion || exit 1
}

install_Docker
