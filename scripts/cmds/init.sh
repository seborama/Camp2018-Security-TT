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
    local installDir=~/.minikube/machines/${MINIKUBE_PROFILE}/

    banner "Creating and running Minikube (profile: ${MINIKUBE_PROFILE})"

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
            minikube --profile=${MINIKUBE_PROFILE} stop
            minikube --profile=${MINIKUBE_PROFILE} delete
            rm -rf "${installDir}"
        fi
    fi

    if [ "${keepExisting}" -ne 1 ]; then
        minikube --profile=${MINIKUBE_PROFILE} \
                 start \
                 --vm-driver=${MINIKUBE_VM_DRIVER} \
                 --memory=8192 \
                 --cpus=4  || exit 1

        minikube --profile ${MINIKUBE_PROFILE} addons enable registry || exit 1
        minikube --profile ${MINIKUBE_PROFILE} addons enable metrics-server || exit 1 # this allows "kubectl top pod" and "kubectl top node"
    fi

    eval $(minikube --profile ${MINIKUBE_PROFILE} docker-env --unset) || exit 1

    echo -e "\nMinikube IP: $(minikube --profile=${MINIKUBE_PROFILE} ip)"
}


#####################################################################
function wait_for_k8s_environment() {
#####################################################################
    banner "Waiting for K8s environment readiness"
    wait_until_k8s_environment_is_ready ${MINIKUBE_PROFILE}
}


#####################################################################
function wait_for_minikube_registry_addon() {
#####################################################################
    banner "Waiting for Minikube registry addon readiness"
    wait_minikube_registry_addon_is_ready ${MINIKUBE_PROFILE} ${REGISTRY_HOST}
}


#####################################################################
function create_Security_K8s_Namespace() {
#####################################################################
    banner "Creating and Kubernetes namespace (${K8S_NAMESPACE})"

    kubectl --context=${MINIKUBE_PROFILE} get namespace ${K8S_NAMESPACE} 2>/dev/null && return
    kubectl --context=${MINIKUBE_PROFILE} create namespace ${K8S_NAMESPACE} || exit 1
}


#####################################################################
function build_SplunkImage() {
#####################################################################
    pushd "${SECURITY_TT_HOME}/Splunk7" >/dev/null || exit 1

    banner "Building Splunk Docker image"

    eval $(minikube --profile ${MINIKUBE_PROFILE} docker-env) || exit 1
    docker --log-level warn build -t ${REGISTRY_HOST}/splunk_7:v1 . || exit 1
    docker --log-level warn push ${REGISTRY_HOST}/splunk_7:v1 || exit 1
    eval $(minikube --profile ${MINIKUBE_PROFILE} docker-env --unset) || exit 1

    popd >/dev/null || exit 1
}


#####################################################################
function deploy_Splunk() {
#####################################################################
    pushd "${SECURITY_TT_HOME}/Splunk7" >/dev/null || exit 1

    banner "Deploying Splunk to Minikube (profile: ${MINIKUBE_PROFILE})"

    local splunkPassword=" "
    while echo "${splunkPassword}"| grep -qF " " || [ ${#splunkPassword} -lt 8 ]; do
        read -s -p "Enter value for 'splunkPassword' (minimum 8 characters, space characters NOT permitted): " splunkPassword; echo
    done

    kubectl --context=${MINIKUBE_PROFILE} apply -f splunk-config.yaml || exit 1

    local splunkEntSecCredentialsSPL="H.!"
    while [ ! -f "${splunkEntSecCredentialsSPL}" ] && [  "${splunkEntSecCredentialsSPL}" != "none" ]; do
        echo "This step will forward events received by Splunk to your Splunk Enterprise Security server"
        echo "Note that Phantom requires different steps (manual)"
        read -p "Enter the full location of your Splunk Universal Forwarder Credentials file (default ${HOME}/Downloads/splunkclouduf.spl) (type 'none' to skip): " splunkEntSecCredentialsSPL; echo
        splunkEntSecCredentialsSPL=${splunkEntSecCredentialsSPL:-${HOME}/Downloads/splunkclouduf.spl}
    done

    if [  "${splunkEntSecCredentialsSPL}" != "none" ]; then
        local splunkclouduf_spl=$(base64 -i "${splunkEntSecCredentialsSPL}") || exit 1
        local splunkescreds_txt=$(echo "admin:${splunkPassword}"| base64 ) || exit 1

        [ -f splunk-secret.generated.yaml ] && rm splunk-secret.generated.yaml

        sed -e "s|{{SPLUNKCLOUDUF_SPL_CONTENTS_BASE64}}|${splunkclouduf_spl}|g" \
            -e "s|{{SPLUNKESCREDS_BASE64}}|${splunkescreds_txt}|g" \
            splunk-secret.templ.yaml >splunk-secret.generated.yaml || exit 1
        kubectl --context=${MINIKUBE_PROFILE} apply -f splunk-secret.generated.yaml || exit 1
    fi

    [ -f splunk-daemonset.generated.yaml ] && rm splunk-daemonset.generated.yaml
    sed -e "s/{{REGISTRY_IP}}/${REGISTRY_HOST}/g" \
        -e "s/{{SPLUNK_PASSWORD}}/${splunkPassword}/g" \
        splunk-daemonset.templ.yaml >splunk-daemonset.generated.yaml || exit 1
    kubectl --context=${MINIKUBE_PROFILE} apply -f splunk-daemonset.generated.yaml || exit 1

    kubectl --context=${MINIKUBE_PROFILE} apply -f splunk-service.yaml || exit 1

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

    if [ $(helm status wordpress 2>/dev/null| grep Running | wc -l) -eq 2 ]; then
        echo "Wordpress is already running"
    else
        deploy_Wordpress ${minikubeProfile} ${k8sNamespace}
    fi
}


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


#####################################################################
function installer() {
#####################################################################
    local installerName="$1"
    "${SECURITY_TT_HOME}"/scripts/cmds/installers/${installerName}.sh
}


#####################################################################
function install_prerequisite_sw() {
#####################################################################
    installer homebrew
    installer virtualbox
    installer vagrant
    installer Kali
    installer kubernetes_cli
    installer Helm
    installer Docker
    start_Docker
    installer Minikube
}


#####################################################################
function init() {
#####################################################################
    local -r minikubeProfile=$1 ; : ${minikubeProfile:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r registryHost=$2 ; : ${registryHost:?<- missing argument in "'${FUNCNAME[0]}()'"}
    local -r k8sNamespace=$2 ; : ${k8sNamespace:?<- missing argument in "'${FUNCNAME[0]}()'"}

    install_prerequisite_sw

    createAndRun_Minikube
    wait_for_k8s_environment ${minikubeProfile}
    wait_for_minikube_registry_addon

    create_Security_K8s_Namespace
    build_SplunkImage
    deploy_Splunk
    deploy_PackagesToMinikube ${minikubeProfile} ${k8sNamespace}

    display_minikube_services ${minikubeProfile} ${registryHost}
}

echo "DEBUG - refactoring in progress: remove all remaining use of global env variables (other than perhaps SECURITY_TT_HOME)" ; exit 255
init "$@"
