#!/usr/bin/env bash

function updateHostsFiles() {
    # TODO this code exists in two places (see also init.sh
    local -r minikubeIP=$(kubectl --context=${MINIKUBE_PROFILE} -n kube-system get svc registry -o jsonpath="{.spec.clusterIP}") || exit 1
    : ${minikubeIP:?Unable to determnine the registry IP}

    minikube --profile=${MINIKUBE_PROFILE} ssh "sudo -c echo '${minikubeIP}    registry' >>/etc/hosts"
}

#####################################################################
# Main Programme Entry
#####################################################################
if [ ! -d ~/.minikube/machines/${MINIKUBE_PROFILE}/config.json ]; then
    echo "It doesn't appear that you have initialised the environment yet"
    read -p "Would you like to do so now? (y/N) " choice
    [[ ! "${choice}" =~ ^Yy1$ ]] && exit 1
    "${SECURITY_TT_HOME}"/scripts/lab.sh init
    exit
fi

minikube start
updateHostsFiles
