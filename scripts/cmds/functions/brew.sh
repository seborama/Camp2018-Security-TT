#!/usr/bin/env bash

[ -n "${_INC_BREW+x}" ] && return
typeset -xr _INC_BREW

#####################################################################
function isHomebrewAvailable() {
#####################################################################
    which -s brew && return ${OK}
    echo "Homebrew is not installed. Skipping this step - you must proceed manually"
    return ${NOK}
}

export -f isHomebrewAvailable

#####################################################################
function brew_install() {
#####################################################################
    local package=${1:-Missing package argument in function `$FUNCNAME[0]`}

    isHomebrewAvailable || return
    brew list "${package}" &>/dev/null || brew install "${package}" || exit 1
    echo Done
}

export -f brew_install

#####################################################################
function brew_cask_install() {
#####################################################################
    local package=${1:-Missing package argument in function `$FUNCNAME[0]`}

    isHomebrewAvailable || return
    brew cask list "${package}" &>/dev/null || brew cask install "${package}" || exit 1
    echo Done
}

export -f brew_cask_install
