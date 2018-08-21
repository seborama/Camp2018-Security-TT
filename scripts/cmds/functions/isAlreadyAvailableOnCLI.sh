#!/usr/bin/env bash

[ -n "${_INC_IS_ALREADY_AVAILABLE_ON_CLI+x}" ] && return
typeset -xr _INC_IS_ALREADY_AVAILABLE_ON_CLI

#####################################################################
function isAlreadyAvailableOnCLI() {
#####################################################################
    local -r appName=$1 ; : ${appName:?<- missing argument in "'${FUNCNAME[0]}()'"}

    if which -s "${appName}"; then
        echo "'${appName}' is already available on the CLI. Skipping this step"
        return ${OK}
    fi

    return ${NOK}
}

export -f isAlreadyAvailableOnCLI
