#!/usr/bin/env bash

#####################################################################
# Global Environment Variables
#####################################################################
readonly SCRIPT_HOME="$(pushd $(dirname $0)/.. >/dev/null ; echo ${PWD})"

readonly K8S_NAMESPACE="security-tt"
#readonly MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikubesecuritytt}"
readonly MINIKUBE_PROFILE="minikube"
[ "${MINIKUBE_PROFILE}" != "minikube" ] &&
    read -p "Note: using a profile name other than minikube may cause stability issues with some versions of minikube"

readonly MINIKUBE_VM_DRIVER="${MINIKUBE_VM_DRIVER:-virtualbox}"

readonly OK=0
readonly NOK=1


#####################################################################
function banner() {
#####################################################################
    local message=${1:-Missing message argument in function `$FUNCNAME[0]`}

    echo -e "\n\n*********************************************************************"
    echo -e "*** ${message}"
    echo -e "*********************************************************************\n"
}


#####################################################################
function brew_install() {
#####################################################################
    local package=${1:-Missing package argument in function `$FUNCNAME[0]`}

    brew list "${package}" &>/dev/null || brew install "${package}" || exit 1
    echo Done
}


#####################################################################
function brew_cask_install() {
#####################################################################
    local package=${1:-Missing package argument in function `$FUNCNAME[0]`}

    brew cask list "${package}" &>/dev/null || brew cask install "${package}" || exit 1
    echo Done
}


#####################################################################
function install_brew() {
#####################################################################
    banner "Installing Homebrew"

    which -s brew && return

    echo "Homebrew is a pre-requisite but I can't locate your installation."
    local choice
    read -p "Perform installation homebrew (y/N)? " choice
    [[ ! "${choice}" =~ ^[Yy1]$ ]] || exit 1

    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
    brew update || exit 1
    echo Done
}


#####################################################################
function install_VirtualBox() {
#####################################################################
    banner "Installing VirtualBox"

    brew_cask_install virtualbox || exit 1
    brew_cask_install virtualbox-extension-pack || exit 1
}


#####################################################################
function install_Vagrant() {
#####################################################################
    banner "Installing Vagrant"

    brew_cask_install vagrant || exit 1
    brew_install vagrant-completion || exit 1
}


#####################################################################
function vagrant_destroy() {
#####################################################################
    vagrant status | grep -q "not created" && return

    echo "This Vagrant machine has already been set-up previously."
    vagrant destroy
}


#####################################################################
function install_Kali() {
#####################################################################
    pushd "${SCRIPT_HOME}/Kali_Linux" >/dev/null || exit 1

    banner "Installing Kali Linux"
    vagrant_destroy && echo -e "\n***WARNING - This may take over an hour depending on the speed of your internet connection and your laptop\n"
    vagrant up

    popd >/dev/null || exit 1
}


#####################################################################
function install_kubernetes_cli() {
#####################################################################
    banner "Installing kubernetes-cli"

    brew_install kubernetes-cli || exit 1
}


#####################################################################
function install_Helm() {
#####################################################################
    banner "Installing Helm"

    brew_install kubernetes-helm || exit 1
}


#####################################################################
function install_Minikube() {
#####################################################################
    banner "Installing Minikube"

    brew_cask_install minikube || exit 1
}


#####################################################################
function install_Docker() {
#####################################################################
    banner "Installing Docker"

    brew_cask_install docker || exit 1
    brew_install docker-completion || exit 1
}


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

    eval $(minikube --profile ${MINIKUBE_PROFILE} docker-env --unset) || exit 1

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
                 --cpus=4 || exit 1

        minikube --profile ${MINIKUBE_PROFILE} addons enable registry || exit 1
        minikube --profile ${MINIKUBE_PROFILE} addons disable heapster &>/dev/null
        minikube --profile ${MINIKUBE_PROFILE} addons disable metrics-server &>/dev/null
    fi

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
    echo "Minikube registry Service ClusterIP: ${REGISTRY_CLUSTERIP}"

    echo "(Press {RETURN} to stop waiting)"
    while ! minikube --profile ${MINIKUBE_PROFILE} ssh "curl -sSI ${REGISTRY_CLUSTERIP}/v2/" | grep -q " 200 OK"; do
        read -t 2 && break
    done
}


#####################################################################
function build_SplunkImage() {
#####################################################################
    pushd "${SCRIPT_HOME}/Splunk7" >/dev/null || exit 1

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
    pushd "${SCRIPT_HOME}/Splunk7" >/dev/null || exit 1

    banner "Deploying Splunk to Minikube (profile: ${MINIKUBE_PROFILE})"

    local splunkPassword=" "
    while echo "${splunkPassword}"| grep -qF " " || [ ${#splunkPassword} -lt 8 ]; do
        read -s -p "Enter value for 'splunkPassword' (minimum 8 characters, space characters NOT permitted): " splunkPassword; echo
    done

    kubectl --context=${MINIKUBE_PROFILE} apply -f splunk-config.yaml || exit 1

    local splunkEntSecCredentialsSPL="H.!"
    while [ ! -f "${splunkEntSecCredentialsSPL}" ]; do
        read -p "Enter the full location of your Splunk Universal Forwarder Credentials file (default ${HOME}/Downloads/splunkclouduf.spl): " splunkEntSecCredentialsSPL; echo
        splunkEntSecCredentialsSPL=${splunkEntSecCredentialsSPL:-${HOME}/Downloads/splunkclouduf.spl}
    done

    local splunkclouduf_spl=$(base64 -i "${splunkEntSecCredentialsSPL}") || exit 1
    local splunkescreds_txt=$(echo "admin:${splunkPassword}"| base64 ) || exit 1

    [ -f splunk-secret.generated.yaml ] && rm splunk-secret.generated.yaml

    sed -e "s|{{SPLUNKCLOUDUF_SPL_CONTENTS_BASE64}}|${splunkclouduf_spl}|g" \
        -e "s|{{SPLUNKESCREDS_BASE64}}|${splunkescreds_txt}|g" \
        splunk-secret.templ.yaml >splunk-secret.generated.yaml || exit 1
    kubectl --context=${MINIKUBE_PROFILE} apply -f splunk-secret.generated.yaml || exit 1

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
# Main Programme Entry
#####################################################################
install_brew
install_VirtualBox
install_Vagrant
install_Kali
install_kubernetes_cli
install_Helm
install_Docker
start_Docker
install_Minikube
createAndRun_Minikube
wait_until_k8s_environment_is_ready
wait_minikiube_registry_addon_is_ready
create_K8s_Namespace
build_SplunkImage
deploy_Splunk
deploy_PackagesToMinikube

display_minikube_services