#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

[ -n "${_INC_MINIKUBE+x}" ] && return
typeset -xr _INC_MINIKUBE

[ -z "${SECURITY_TT_HOME}" ] && echo "ERROR - Invalid state - Make sure you use lab.sh" && exit 1

#####################################################################
function wait_until_k8s_environment_is_ready() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}

    local -r reportFile=/tmp/setup_local.$$
    local -r jsonPath='{range .items[*]}±{@.metadata.name}:{range @.status.containerStatuses[*]}ready={@.ready};{end}{end}'

    echo "(Press {RETURN} stop waiting)"
    while true;
    do
        kubectl --context=${minikubeProfile} get pods --all-namespaces -o jsonpath="${jsonPath}" | tr "±" "\n" | grep false >"${reportFile}"
        [ "$(wc -l ${reportFile} | awk '{print $1}')" == 0 ] && break
        read -t 2 && break
    done

    rm "${reportFile}"
}

export -f wait_until_k8s_environment_is_ready
