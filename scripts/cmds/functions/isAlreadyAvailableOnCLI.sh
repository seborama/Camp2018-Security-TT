#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

[ -n "${_INC_IS_ALREADY_AVAILABLE_ON_CLI+x}" ] && return
typeset -xr _INC_IS_ALREADY_AVAILABLE_ON_CLI

[ -z "${SECURITY_TT_HOME}" ] && echo "ERROR - Invalid state - Make sure you use lab.sh" && exit 1

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
