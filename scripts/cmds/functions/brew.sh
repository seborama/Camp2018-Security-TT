#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

[ -n "${_INC_BREW+x}" ] && return
typeset -xr _INC_BREW

[ -z "${SECURITY_TT_HOME}" ] && echo "ERROR - Invalid state - Make sure you use lab.sh" && exit 1

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
    local -r package=$1 ; : ${package:?<- missing argument in "'${FUNCNAME[0]}()'"}

    isHomebrewAvailable || return
    brew list "${package}" &>/dev/null || brew install "${package}" || exit 1
    echo Done
}

export -f brew_install

#####################################################################
function brew_cask_install() {
#####################################################################
    local -r package=$1 ; : ${package:?<- missing argument in "'${FUNCNAME[0]}()'"}

    isHomebrewAvailable || return
    brew cask list "${package}" &>/dev/null || brew cask install "${package}" || exit 1
    echo Done
}

export -f brew_cask_install
