#!/usr/bin/env bash

[ -n "${_INC_VAGRANT+x}" ] && return
typeset -xr _INC_VAGRANT

#####################################################################
function vagrant_destroy() {
#####################################################################
    vagrant status | grep -q "not created" && return

    echo "This Vagrant machine has already been set-up previously."
    vagrant destroy
}

export -f vagrant_destroy
