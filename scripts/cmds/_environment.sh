#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)
# THIS MEANS THAT THIS FILE SHOULD IDEALLY CONTAIN ONLY ONE VARIABLE AT MOST
# TODO: apply the above rule :-)

#####################################################################
# Global Environment Variables
#####################################################################
typeset -xr SECURITY_TT_HOME="$(pushd "$(dirname $0)"/.. >/dev/null || exit 1; echo ${PWD})"
if [ -z "${SECURITY_TT_HOME}" ]; then
    echo "Could not determine SECURITY_TT_HOME"
    exit 100
fi

typeset -xr K8S_NAMESPACE="security-tt"

#typeset -xr MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikubesecuritytt}"
typeset -xr MINIKUBE_PROFILE="minikube"
[ "${MINIKUBE_PROFILE}" != "minikube" ] &&
    read -p "Note: using a profile name other than 'minikube' may cause stability issues with some versions of minikube"

typeset -xr MINIKUBE_VM_DRIVER="${MINIKUBE_VM_DRIVER:-virtualbox}"

typeset -xr REGISTRY_HOST="registry.minikube"

typeset -xr readonly OK=0
typeset -xr readonly NOK=1
