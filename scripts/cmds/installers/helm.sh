#!/usr/bin/env bash

#####################################################################
function install_Helm() {
#####################################################################
    banner "Installing Helm"

    isAlreadyAvailableOnCLI "helm" && return
    brew_install kubernetes-helm || exit 1
}

install_Helm
