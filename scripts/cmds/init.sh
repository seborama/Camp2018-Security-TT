#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

[ -z "${SECURITY_TT_HOME}" ] && echo "ERROR - Invalid state - Make sure you use lab.sh" && exit 1


#####################################################################
function start_Docker() {
#####################################################################
    banner "Starting Docker"

    open --background -a Docker

    while ! docker system info &>/dev/null; do
        sleep 2
    done
}


#####################################################################
function createAndRun_Minikube() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r minikubeVmDriver=$2 ; : ${minikubeVmDriver:?<- missing argument in "'${FUNCNAME[0]}()'"}

    local -r installDir=~/.minikube/machines/${minikubeProfile}/

    banner "Creating and running Minikube (profile: ${minikubeProfile})"

    local keepExisting=0

    if [ -d "${installDir}" ]; then
        echo "Minikube has already been set-up previously."
        local choice
        read -p "WARNING - Would you like to DESTROY it (y/N)? " choice
        if [[ ! "${choice}" =~ ^[Yy1]$ ]]; then
            read -p "Proceed with the existing Minikube install (Y/n)? " choice
            [[ "${choice}" =~ ^[Nn0]$ ]] && exit 1
            keepExisting=1
        fi

        if [ "${keepExisting}" -ne 1 ]; then
            minikube --profile=${minikubeProfile} stop
            minikube --profile=${minikubeProfile} delete
            rm -rf "${installDir}"
        fi
    fi

    if [ "${keepExisting}" -ne 1 ]; then
        minikube --profile=${minikubeProfile} \
                 start \
                 --kubernetes-version=v1.10.7 \
                 --vm-driver=${minikubeVmDriver} \
                 --memory=8192 \
                 --cpus=4  || exit 1

        minikube --profile ${minikubeProfile} addons enable registry || exit 1
        minikube --profile ${minikubeProfile} addons enable metrics-server || exit 1 # this allows "kubectl top pod" and "kubectl top node"
    fi

    eval "$(minikube --profile ${minikubeProfile} docker-env --unset)" || exit 1

    echo -e "\nMinikube IP: $(minikube --profile=${minikubeProfile} ip)"
}


#####################################################################
function wait_for_k8s_environment() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}

    banner "Waiting for K8s environment readiness"
    wait_until_k8s_environment_is_ready ${minikubeProfile}
}


#####################################################################
function wait_for_minikube_registry_addon() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r registryHost=$2 ; : ${registryHost:?<- missing argument in "'${FUNCNAME[0]}()'"}

    banner "Waiting for Minikube registry addon readiness"
    wait_minikube_registry_addon_is_ready ${minikubeProfile} ${registryHost}
}


#####################################################################
function create_Security_K8s_Namespace() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r k8sNamespace=$2 ; : ${k8sNamespace:?<- missing argument in "'${FUNCNAME[0]}()'"}

    banner "Creating and Kubernetes namespace (${k8sNamespace})"

    kubectl --context=${minikubeProfile} get namespace ${k8sNamespace} 2>/dev/null && return
    kubectl --context=${minikubeProfile} create namespace ${k8sNamespace} || exit 1
}


#####################################################################
function build_SplunkImage() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r registryHost=$2 ; : ${registryHost:?<- missing argument in "'${FUNCNAME[0]}()'"}

    pushd "${SECURITY_TT_HOME}/Splunk7" >/dev/null || exit 1

    banner "Building Splunk Docker image"

    eval "$(minikube --profile ${minikubeProfile} docker-env)" || exit 1
    docker --log-level warn build -t ${registryHost}/splunk_7:v1 . || exit 1
    docker --log-level warn push ${registryHost}/splunk_7:v1 || exit 1
    eval "$(minikube --profile ${minikubeProfile} docker-env --unset)" || exit 1

    popd >/dev/null || exit 1
}


#####################################################################
function deploy_Splunk() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r registryHost=$2 ; : ${registryHost:?<- missing argument in "'${FUNCNAME[0]}()'"}

    pushd "${SECURITY_TT_HOME}/Splunk7" >/dev/null || exit 1

    banner "Deploying Splunk to Minikube (profile: ${minikubeProfile})"

    local splunkPassword=" "
    while echo "${splunkPassword}"| grep -qF " " || [ ${#splunkPassword} -lt 8 ]; do
        read -s -p "Enter value for 'splunkPassword' (minimum 8 characters, space characters NOT permitted): " splunkPassword; echo
    done

    kubectl --context=${minikubeProfile} apply -f splunk-config.yaml || exit 1

    local splunkEntSecCredentialsSPL="H.!"
    while [ ! -f "${splunkEntSecCredentialsSPL}" ] && [  "${splunkEntSecCredentialsSPL}" != "none" ]; do
        echo "This step will forward events received by Splunk to your Splunk Enterprise Security server"
        echo "Note that Phantom requires different steps (manual)"
        read -p "Enter the full location of your Splunk Universal Forwarder Credentials file (default ${HOME}/Downloads/splunkclouduf.spl) (type 'none' to skip): " splunkEntSecCredentialsSPL; echo
        splunkEntSecCredentialsSPL=${splunkEntSecCredentialsSPL:-${HOME}/Downloads/splunkclouduf.spl}
    done

    if [  "${splunkEntSecCredentialsSPL}" != "none" ]; then
        local splunkclouduf_spl
        splunkclouduf_spl=$(base64 -i "${splunkEntSecCredentialsSPL}") || exit 1
        local splunkescreds_txt
        splunkescreds_txt=$(echo "admin:${splunkPassword}"| base64 ) || exit 1

        [ -f splunk-secret.generated.yaml ] && rm splunk-secret.generated.yaml

        sed -e "s|{{SPLUNKCLOUDUF_SPL_CONTENTS_BASE64}}|${splunkclouduf_spl}|g" \
            -e "s|{{SPLUNKESCREDS_BASE64}}|${splunkescreds_txt}|g" \
            splunk-secret.templ.yaml >splunk-secret.generated.yaml || exit 1
        kubectl --context=${minikubeProfile} apply -f splunk-secret.generated.yaml || exit 1
    fi

    [ -f splunk-daemonset.generated.yaml ] && rm splunk-daemonset.generated.yaml
    sed -e "s/{{REGISTRY_IP}}/${registryHost}/g" \
        -e "s/{{SPLUNK_PASSWORD}}/${splunkPassword}/g" \
        splunk-daemonset.templ.yaml >splunk-daemonset.generated.yaml || exit 1
    kubectl --context=${minikubeProfile} apply -f splunk-daemonset.generated.yaml || exit 1

    kubectl --context=${minikubeProfile} apply -f splunk-service.yaml || exit 1

    popd >/dev/null || exit 1
}


#####################################################################
function deploy_Wordpress {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r k8sNamespace=$2 ; : ${k8sNamespace:?<- missing argument in "'${FUNCNAME[0]}()'"}

    local wordpressPassword
    local mariadbRootPassword
    local mariadbPassword

    read -s -p "Enter value for 'wordpressPassword': " wordpressPassword; echo
    read -s -p "Enter value for 'mariadbRootPassword': " mariadbRootPassword; echo
    read -s -p "Enter value for 'mariadbPassword': " mariadbPassword; echo

    helm --kube-context=${minikubeProfile} install \
         --name=wordpress \
         --namespace=${k8sNamespace} \
         -f WordPress/values-stable-wordpress-topicteam.yaml \
         stable/wordpress \
         --set-string wordpressPassword="${wordpressPassword}" \
         --set-string mariadbRootPassword="${mariadbRootPassword}" \
         --set-string mariadbPassword="${mariadbPassword}" || exit 1
}

#####################################################################
function deploy_PackagesToMinikube() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r k8sNamespace=$2 ; : ${k8sNamespace:?<- missing argument in "'${FUNCNAME[0]}()'"}

    banner "Deploying packages to Minikube (profile: ${minikubeProfile})"

    helm --kube-context=${minikubeProfile} init || exit 1
    kubectl --context=${minikubeProfile} -n kube-system rollout status deployment.apps/tiller-deploy -w

    if (( $(helm status wordpress 2>/dev/null| grep Running | wc -l) == 2 )); then
        echo "Wordpress is already running"
    else
        deploy_Wordpress ${minikubeProfile} ${k8sNamespace}
    fi
}


#####################################################################
function installer() {
#####################################################################
    local installerName="$1"
    "${SECURITY_TT_HOME}"/scripts/cmds/installers/${installerName}.sh || exit 1
}


#####################################################################
function install_prerequisite_sw() {
#####################################################################
    installer homebrew
    installer virtualbox
    installer vagrant
    installer kali
    installer kubernetes_cli
    installer helm
    installer docker
    start_Docker
}


#####################################################################
function init() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r registryHost=$2 ; : ${registryHost:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r k8sNamespace=$3 ; : ${k8sNamespace:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r minikubeVmDriver=$4 ; : ${minikubeVmDriver:?<- missing argument in "'${FUNCNAME[0]}()'"}

    install_prerequisite_sw

    createAndRun_Minikube ${minikubeProfile} ${minikubeVmDriver}
    wait_for_k8s_environment ${minikubeProfile}
    wait_for_minikube_registry_addon ${minikubeProfile} ${registryHost}

    create_Security_K8s_Namespace ${minikubeProfile} ${k8sNamespace}
    build_SplunkImage ${minikubeProfile} ${registryHost}
    deploy_Splunk ${minikubeProfile} ${registryHost}
    deploy_PackagesToMinikube ${minikubeProfile} ${k8sNamespace}

    display_minikube_services ${minikubeProfile} ${registryHost}
}

echo "DEBUG - refactoring in progress: remove all remaining use of global env variables (other than perhaps SECURITY_TT_HOME)"
init "$@"
