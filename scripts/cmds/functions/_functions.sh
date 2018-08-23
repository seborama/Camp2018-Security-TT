#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

[ -n "${_INC_FUNCTIONS+x}" ] && return
typeset -xr _INC_FUNCTIONS

thisFile="${BASH_SOURCE[0]}"


for functionFile in "${SECURITY_TT_HOME}"/scripts/cmds/functions/*.sh
do
    [ "${functionFile}" == "${thisFile}" ] && continue
    # shellcheck source=functions/*.sh
    source "${functionFile}"
done
