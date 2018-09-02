#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)


[ -z "${SECURITY_TT_HOME}" ] && echo "ERROR - Invalid state - Make sure you use lab.sh" && exit 1


#####################################################################
function stop_Kali() {
#####################################################################
    pushd "${SECURITY_TT_HOME}/Kali_Linux" >/dev/null || exit 1

    vagrant halt || exit 1

    popd >/dev/null || exit 1
}


#####################################################################
function stop() {
#####################################################################
    minikube stop || exit 1
    stop_Kali
}

stop
