#!/usr/bin/env bash

[ -n "${_INC_BANNER+x}" ] && return
typeset -xr _INC_BANNER

#####################################################################
function banner() {
#####################################################################
    local message=${1:-Missing message argument in function `$FUNCNAME[0]`}

    echo -e "\n\n*********************************************************************"
    echo -e "*** ${message}"
    echo -e "*********************************************************************\n"
}

export -f banner
