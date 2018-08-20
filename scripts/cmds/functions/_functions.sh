#!/usr/bin/env bash

[ -n "${_INC_FUNCTIONS+x}" ] && return
typeset -xr _INC_FUNCTIONS

this="${BASH_SOURCE[0]}"


for functionFile in "${SECURITY_TT_HOME}"/scripts/cmds/functions/*.sh
do
    [ "${functionFile}" == "$this" ] && continue
    echo "Loading ${functionFile}"
    source "${functionFile}"
done
