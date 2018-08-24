#!/usr/bin/env bash


# shellcheck source=cmds/_environment.sh
source "$(dirname "$0")/cmds/_environment.sh" || exit 1
# shellcheck source=functions/_functions.sh
source "$(dirname "$0")/cmds/functions/_functions.sh" || exit 1


#####################################################################
function usage() {
#####################################################################
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


#####################################################################
# Main Programme Entry
#####################################################################
COMMAND="$1"
case "${COMMAND}" in
    init) "${SECURITY_TT_HOME}"/scripts/cmds/init.sh ${MINIKUBE_PROFILE} ${REGISTRY_HOST} ${K8S_NAMESPACE} ${MINIKUBE_VM_DRIVER} ;;
    start) "${SECURITY_TT_HOME}"/scripts/cmds/start.sh ${MINIKUBE_PROFILE} ${REGISTRY_HOST} ;;
    stop) "${SECURITY_TT_HOME}"/scripts/cmds/stop.sh ;;
    *) usage ;;
esac
