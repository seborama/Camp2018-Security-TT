#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

[ -n "${_INC_BANNER+x}" ] && return
typeset -xr _INC_BANNER

[ -z "${SECURITY_TT_HOME}" ] && echo "ERROR - Invalid state - Make sure you use lab.sh" && exit 1

#####################################################################
function banner() {
#####################################################################
    local -r message=$1 ; : ${message:?<- missing argument in "'${FUNCNAME[0]}()'"}

    echo -e "\n\n*********************************************************************"
    echo -e "*** ${message}"
    echo -e "*********************************************************************\n"
}

export -f banner
