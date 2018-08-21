#!/usr/bin/env bash

#####################################################################
function install_Minikube() {
#####################################################################
    banner "Installing Minikube"

    isAlreadyAvailableOnCLI "minikube" && return
    brew_cask_install minikube || exit 1
}

install_Minikube
