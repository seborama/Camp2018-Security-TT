#!/usr/bin/env bash

#####################################################################
# Global Environment Variables
#####################################################################
readonly SCRIPT_HOME="$(pushd $(dirname $0)/.. >/dev/null ; echo ${PWD})"

readonly K8S_NAMESPACE="security-tt"
#readonly MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikubesecuritytt}"
readonly MINIKUBE_PROFILE="minikube"
[ "${MINIKUBE_PROFILE}" != "minikube" ] &&
    read -p "Note: using a profile name other than minikube appears to cause stability issues with minikube and kubeadm"

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

    brew list "${package}" || brew install "${package}" || exit 1
    echo Done
}


#####################################################################
function brew_cask_install() {
#####################################################################
    local package=${1:-Missing package argument in function `$FUNCNAME[0]`}

    brew cask list "${package}" || brew cask install "${package}" || exit 1
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
function install_Splunk() {
#####################################################################
    pushd "${SCRIPT_HOME}/Splunk" >/dev/null || exit 1

    local splunkPassword

    banner "Installing Splunk"
    if vagrant_destroy; then
        read -s -p "Enter value for 'splunkPassword': " splunkPassword; echo
        echo -e "\n***WARNING - This may take over an hour depending on the speed of your internet connection and your laptop\n"
    fi

    read -p "TODO - Should we run Splunk inside the Minikube K8s cluster to avoid IP complications (this would also be more secure)? Pb: might overload the cluster capacity!? Press {RETURN} to continue..."

    SPLUNK_PASSWORD="${splunkPassword:-splunkPassword}" vagrant up

    echo "Obtaining Splunk VM IP..."
    SPLUNK_IP=""
    while [ -z "${SPLUNK_IP}" ];
    do
        SPLUNK_IP=$(vagrant ssh -c "ip address show eth1 | awk '/inet /{print \$2}' | cut -d/ -f 1")
        sleep 2
    done
    echo "SPLUNK_IP=${SPLUNK_IP}"

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

    eval $(minikube docker-env --unset) || exit 1

    if [ -d "${installDir}" ]; then
        echo "Minikube has already been set-up previously."
        local choice
        read -p "WARNING - Would you like to DESTROY it? (default: n) " choice
        [[ ! "${choice}" =~ ^[Yy]$ ]] && exit 1

        minikube --profile=${MINIKUBE_PROFILE} stop
        minikube --profile=${MINIKUBE_PROFILE} delete
        rm -rf "${installDir}"
    fi

    #  --logtostderr --v=2 --stderrthreshold=2 --loglevel=1
    minikube --profile=${MINIKUBE_PROFILE} start --vm-driver=${MINIKUBE_VM_DRIVER} --memory=8192 --cpus=4 || exit 1
    minikube addons enable registry || exit 1
    minikube addons disable heapster
    minikube addons disable metrics-server
}


#####################################################################
function create_K8s_Namespace() {
#####################################################################
    banner "Creating and Kubernetes namespace (${K8S_NAMESPACE})"

    kubectl --context=${MINIKUBE_PROFILE} create namespace ${K8S_NAMESPACE}
}


#####################################################################
#function run_SplunkForwarderContainer() {
#####################################################################
#    pushd "${SCRIPT_HOME}/SplunkForwarder" >/dev/null || exit 1
#
#    banner "Running Splunk Universal Forwarder Docker container"
#    echo "NOTE: This will be transferred to K8s ASAP"
#
#    docker run --rm --env SPLUNK_START_ARGS="--accept-license" -d splunk_fwdr:latest || exit 1
#
#    popd >/dev/null || exit 1
#}


#####################################################################
function wait_until_k8s_environment_is_ready() {
#####################################################################
    local reportFile=/tmp/setup_local.$$
    local jsonPath='{range .items[*]}±{@.metadata.name}:{range @.status.containerStatuses[*]}ready={@.ready};{end}{end}'

    banner "Waiting for K8s environment readiness"

    while true;
    do
        kubectl get pods --all-namespaces -o jsonpath="${jsonPath}" | tr "±" "\n" | grep false >"${reportFile}"
        [ "$(wc -l ${reportFile} | awk '{print $1}')" == 0 ] && break
        sleep 2
    done

    rm "${reportFile}"
}


#####################################################################
function wait_minikiube_registry_addon_is_ready() {
#####################################################################
    banner "Waiting for Minikube registry addon readiness"

    while ! kubectl -n kube-system get svc registry &>/dev/null; do sleep 2 ; done

    # get the ip of the registry endpoint
    export REGISTRY_CLUSTERIP=$(kubectl -n kube-system get svc registry -o jsonpath="{.spec.clusterIP}") || exit 1
    echo "Minikube registry Service ClusterIP: ${REGISTRY_CLUSTERIP}"

    while ! minikube ssh "curl -sSI ${REGISTRY_CLUSTERIP}/v2/" | grep -q " 200 OK"; do sleep 2; done
}


#####################################################################
function build_SplunkForwarderImage() {
#####################################################################
    pushd "${SCRIPT_HOME}/SplunkForwarder" >/dev/null || exit 1

    banner "Building Splunk Universal Forwarder Docker image"

    eval $(minikube docker-env) || exit 1
    docker --log-level warn build -t ${REGISTRY_CLUSTERIP}/splunk_fwdr_7:v1 . || exit 1
    docker --log-level warn push ${REGISTRY_CLUSTERIP}/splunk_fwdr_7:v1 || exit 1
    eval $(minikube docker-env --unset) || exit 1

    popd >/dev/null || exit 1
}


#####################################################################
function deploy_SplunkUF() {
#####################################################################
    pushd "${SCRIPT_HOME}/SplunkForwarder" >/dev/null || exit 1

    banner "Deploying Splunk Universal Forwarder to Minikube (profile: ${MINIKUBE_PROFILE})"

    kubectl apply -f splunk-forwarder-config.yaml || exit 1

    [ -f splunk-forwarder-daemonset.generated.yaml ] && rm splunk-forwarder-daemonset.generated.yaml
    sed "s/{{REGISTRY_IP}}/${REGISTRY_CLUSTERIP}/g" splunk-forwarder-daemonset.templ.yaml >splunk-forwarder-daemonset.generated.yaml || exit 1
    kubectl apply -f splunk-forwarder-daemonset.generated.yaml || exit 1

    popd >/dev/null || exit 1
}


#####################################################################
function build_SplunkImage() {
#####################################################################
    pushd "${SCRIPT_HOME}/Splunk7" >/dev/null || exit 1

    banner "Building Splunk Docker image"

    eval $(minikube docker-env) || exit 1
    docker --log-level warn build -t ${REGISTRY_CLUSTERIP}/splunk_7:v1 . || exit 1
    docker --log-level warn push ${REGISTRY_CLUSTERIP}/splunk_7:v1 || exit 1
    eval $(minikube docker-env --unset) || exit 1

    popd >/dev/null || exit 1
}


#####################################################################
function deploy_Splunk() {
#####################################################################
    pushd "${SCRIPT_HOME}/Splunk7" >/dev/null || exit 1

    banner "Deploying Splunk to Minikube (profile: ${MINIKUBE_PROFILE})"
    read -p "DEBUG - THIS IS NOT FINISHED"

    local splunkPassword=" "
    while echo "${splunkPassword}"| grep -qF " " || [ ${#splunkPassword} -lt 8 ]; do
        read -s -p "Enter value for 'splunkPassword' (space characters are NOT permitted): " splunkPassword; echo
    done

    kubectl apply -f splunk-config.yaml || exit 1

    [ -f splunk-daemonset.generated.yaml ] && rm splunk-daemonset.generated.yaml
    sed -e "s/{{REGISTRY_IP}}/${REGISTRY_CLUSTERIP}/g" \
        -e "s/{{SPLUNK_PASSWORD}}/${splunkPassword}/g" \
        splunk-daemonset.templ.yaml >splunk-daemonset.generated.yaml || exit 1
    kubectl apply -f splunk-daemonset.generated.yaml || exit 1

    kubectl apply -f splunk-service.yaml || exit 1

    popd >/dev/null || exit 1
}


#####################################################################
function deploy_PackagesToMinikube() {
#####################################################################
    banner "Deploying packages to Minikube (profile: ${MINIKUBE_PROFILE})"

    helm --kube-context=${MINIKUBE_PROFILE} init || exit 1

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
function display_minikube_services() {
#####################################################################
    echo -e "\n\n"

    minikube service list
}


#####################################################################
# Main Programme Entry
#####################################################################
install_VirtualBox
install_Vagrant
install_Kali
#install_Splunk
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
#build_SplunkForwarderImage
#deploy_SplunkUF
deploy_PackagesToMinikube

display_minikube_services