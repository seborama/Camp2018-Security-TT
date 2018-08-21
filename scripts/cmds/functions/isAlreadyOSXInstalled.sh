#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

[ -n "${_INC_IS_ALREADY_OSX_INSTALLED+x}" ] && return
typeset -xr _INC_IS_ALREADY_OSX_INSTALLED

[ -z "${SECURITY_TT_HOME}" ] && echo "ERROR - Invalid state - Make sure you use lab.sh" && exit 1

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
