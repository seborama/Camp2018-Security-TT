#!/usr/bin/env bash

#####################################################################
# Global Environment Variables
#####################################################################
readonly K8S_NAMESPACE="security-tt"
#readonly MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikubesecuritytt}"
readonly MINIKUBE_PROFILE="minikube"
[ "${MINIKUBE_PROFILE}" != "minikube" ] &&
    read -p "Note: using a profile name other than minikube may cause stability issues with some versions of minikube"

readonly MINIKUBE_VM_DRIVER="${MINIKUBE_VM_DRIVER:-virtualbox}"


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
function create_K8s_Namespace() {
#####################################################################
    banner "Creating and Kubernetes namespace (${K8S_NAMESPACE})"

    kubectl --context=${MINIKUBE_PROFILE} get namespace ${K8S_NAMESPACE} 2>/dev/null && return
    kubectl --context=${MINIKUBE_PROFILE} create namespace ${K8S_NAMESPACE} || exit 1
}


#####################################################################
function wait_until_k8s_environment_is_ready() {
#####################################################################
    local reportFile=/tmp/setup_local.$$
    local jsonPath='{range .items[*]}±{@.metadata.name}:{range @.status.containerStatuses[*]}ready={@.ready};{end}{end}'

    banner "Waiting for K8s environment readiness"

    echo "(Press {RETURN} stop waiting)"
    while true;
    do
        kubectl --context=${MINIKUBE_PROFILE} get pods --all-namespaces -o jsonpath="${jsonPath}" | tr "±" "\n" | grep false >"${reportFile}"
        [ "$(wc -l ${reportFile} | awk '{print $1}')" == 0 ] && break
        read -t 2 && break
    done

    rm "${reportFile}"
}


#####################################################################
function wait_minikiube_registry_addon_is_ready() {
#####################################################################
    banner "Waiting for Minikube registry addon readiness"

    while ! kubectl --context=${MINIKUBE_PROFILE} -n kube-system get svc registry &>/dev/null; do sleep 2 ; done

    # get the ip of the registry endpoint
    export REGISTRY_CLUSTERIP=$(kubectl --context=${MINIKUBE_PROFILE} -n kube-system get svc registry -o jsonpath="{.spec.clusterIP}") || exit 1
    minikube --profile ${MINIKUBE_PROFILE} ssh "sudo echo '${REGISTRY_CLUSTERIP} registry' >> /etc/hosts"
    echo "Minikube registry Service ClusterIP: ${REGISTRY_CLUSTERIP}"
    REGISTRY_CLUSTERIP=registry

    echo "(Press {RETURN} to stop waiting)"
    while ! minikube --profile ${MINIKUBE_PROFILE} ssh "curl -sSI ${REGISTRY_CLUSTERIP}/v2/" | grep -q " 200 OK"; do
        read -t 2 && break
    done
}


#####################################################################
function build_SplunkImage() {
#####################################################################
    pushd "${SECURITY_TT_HOME}/Splunk7" >/dev/null || exit 1

    banner "Building Splunk Docker image"

    eval $(minikube --profile ${MINIKUBE_PROFILE} docker-env) || exit 1
    docker --log-level warn build -t ${REGISTRY_CLUSTERIP}/splunk_7:v1 . || exit 1
    docker --log-level warn push ${REGISTRY_CLUSTERIP}/splunk_7:v1 || exit 1
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
    sed -e "s/{{REGISTRY_IP}}/${REGISTRY_CLUSTERIP}/g" \
        -e "s/{{SPLUNK_PASSWORD}}/${splunkPassword}/g" \
        splunk-daemonset.templ.yaml >splunk-daemonset.generated.yaml || exit 1
    kubectl --context=${MINIKUBE_PROFILE} apply -f splunk-daemonset.generated.yaml || exit 1

    kubectl --context=${MINIKUBE_PROFILE} apply -f splunk-service.yaml || exit 1

    popd >/dev/null || exit 1
}


#####################################################################
function deploy_Wordpress {
#####################################################################
    local wordpressPassword
    local mariadbRootPassword
    local mariadbPassword

    read -s -p "Enter value for 'wordpressPassword': " wordpressPassword; echo
    read -s -p "Enter value for 'mariadbRootPassword': " mariadbRootPassword; echo
    read -s -p "Enter value for 'mariadbPassword': " mariadbPassword; echo

    helm --kube-context=${MINIKUBE_PROFILE} install \
         --name=wordpress \
         --namespace=${K8S_NAMESPACE} \
         -f WordPress/values-stable-wordpress-topicteam.yaml \
         stable/wordpress \
         --set-string wordpressPassword="${wordpressPassword}" \
         --set-string mariadbRootPassword="${mariadbRootPassword}" \
         --set-string mariadbPassword="${mariadbPassword}" || exit 1
}

#####################################################################
function deploy_PackagesToMinikube() {
#####################################################################
    banner "Deploying packages to Minikube (profile: ${MINIKUBE_PROFILE})"

    helm --kube-context=${MINIKUBE_PROFILE} init || exit 1
    kubectl --context=${MINIKUBE_PROFILE} -n kube-system rollout status deployment.apps/tiller-deploy -w

    if [ $(helm status wordpress 2>/dev/null| grep Running | wc -l) -eq 2 ]; then
        echo "Wordpress is already running"
    else
        deploy_Wordpress
    fi
}


#####################################################################
function display_minikube_services() {
#####################################################################
    echo -e "\n"
    echo -e "\nMinikube IP: $(minikube --profile=${MINIKUBE_PROFILE} ip)"
    minikube --profile ${MINIKUBE_PROFILE} service list
    echo -e "\nMinikube registry Service ClusterIP: ${REGISTRY_CLUSTERIP}"
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
# Main Programme Entry
#####################################################################
install_prerequisite_sw

createAndRun_Minikube
wait_until_k8s_environment_is_ready
wait_minikiube_registry_addon_is_ready
create_K8s_Namespace
build_SplunkImage
deploy_Splunk
deploy_PackagesToMinikube

display_minikube_services
