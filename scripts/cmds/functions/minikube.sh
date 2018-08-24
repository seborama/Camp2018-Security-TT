#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

[ -n "${_INC_MINIKUBE+x}" ] && return
typeset -xr _INC_MINIKUBE

[ -z "${SECURITY_TT_HOME}" ] && echo "ERROR - Invalid state - Make sure you use lab.sh" && exit 1

#####################################################################
function configure_minikube_hosts_file() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r registryHost=$2 ; : ${registryHost:?<- missing argument in "'${FUNCNAME[0]}()'"}

    # TODO should check Minikube is up and running
    local -r registryClusterIP=$(kubectl --context=${minikubeProfile} -n kube-system get svc registry -o jsonpath="{.spec.clusterIP}") || exit 1
    : ${registryClusterIP:?Unable to determine the registry clusterIP}
    echo "Minikube registry Service: ${registryHost} (${registryClusterIP})"

    [ "$(minikube --profile="${minikubeProfile}" ssh "grep -q registry /etc/hosts && echo -n OK")" == "OK" ] && return

    minikube --profile="${minikubeProfile}" ssh "sudo sh -c 'echo \"${registryClusterIP}    ${registryHost}\" >> /etc/hosts'" || exit 1
}

export -f configure_minikube_hosts_file


#####################################################################
function wait_minikube_registry_addon_is_ready() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r registryHost=$2 ; : ${registryHost:?<- missing argument in "'${FUNCNAME[0]}()'"}

    while ! kubectl --context=${minikubeProfile} -n kube-system get svc registry &>/dev/null; do
        sleep 2
    done

    # now that the registry service is up, it has an IP
    configure_minikube_hosts_file ${minikubeProfile} ${registryHost}

    while ! minikube --profile ${minikubeProfile} ssh "curl -sSI ${registryHost}/v2/" | grep -q " 200 OK"; do
        sleep 2
    done
}

export -f wait_minikube_registry_addon_is_ready


#####################################################################
function display_minikube_services() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r registryHost=$2 ; : ${registryHost:?<- missing argument in "'${FUNCNAME[0]}()'"}

    echo -e "\n"
    echo -e "\nMinikube IP: $(minikube --profile=${minikubeProfile} ip)"
    minikube --profile ${minikubeProfile} service list
    echo -e "\nMinikube registry Service ClusterIP: ${registryHost}"
}

export -f display_minikube_services
