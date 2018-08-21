#!/usr/bin/env bash

[ -n "${_INC_IS_ALREADY_OSX_INSTALLED+x}" ] && return
typeset -xr _INC_IS_ALREADY_OSX_INSTALLED

#####################################################################
function isAlreadyOSXInstalled() {
#####################################################################
    local -r appName=$1 ; : ${appName:?<- missing argument in "'${FUNCNAME[0]}()'"}

    if /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump 2>&1 | grep -q "${appName}" ; then
        echo "Skipping: '${appName}' is already installed"
        return ${OK}
    fi

    return ${NOK}
}

export -f isAlreadyOSXInstalled
