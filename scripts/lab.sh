#!/usr/bin/env bash

function usage() {
    cat <<EOF
./sec init
./sec start
./sec stop

1st form: create the lab
2nd form: start the lab after a shutdown (after a reboot for instance)
3rd form: stop the lab (recommended before a reboot for instance)
EOF

    exit 1
}


typeset -xr SECURITY_TT_HOME="$(pushd $(dirname $0)/.. >/dev/null ; echo ${PWD})"
typeset -xr readonly OK=0
typeset -xr readonly NOK=1


source "${SECURITY_TT_HOME}"/scripts/cmds/functions/_functions.sh


#####################################################################
# Main Programme Entry
#####################################################################
COMMAND="$1"
case "${COMMAND}" in
    init|start|stop) "${SECURITY_TT_HOME}"/scripts/cmds/${COMMAND}.sh ;;
    *) usage ;;
esac
