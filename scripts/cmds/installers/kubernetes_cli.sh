#!/usr/bin/env bash

#####################################################################
function install_kubernetes_cli() {
#####################################################################
    banner "Installing kubernetes-cli"

    isAlreadyAvailableOnCLI "kubectl" && return
    brew_install kubernetes-cli || exit 1
}

install_kubernetes_cli