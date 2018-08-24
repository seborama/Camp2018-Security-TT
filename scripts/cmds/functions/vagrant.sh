#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

[ -n "${_INC_VAGRANT+x}" ] && return
typeset -xr _INC_VAGRANT

[ -z "${SECURITY_TT_HOME}" ] && echo "ERROR - Invalid state - Make sure you use lab.sh" && exit 1

#####################################################################
function vagrant_destroy() {
#####################################################################
    vagrant status | grep -q "not created" && return

    echo "This Vagrant machine has already been set-up previously."
    vagrant destroy
}

export -f vagrant_destroy
