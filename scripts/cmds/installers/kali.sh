#!/usr/bin/env bash

#####################################################################
function install_Kali() {
#####################################################################
    pushd "${SECURITY_TT_HOME}/Kali_Linux" >/dev/null || exit 1

    banner "Installing Kali Linux"
    vagrant_destroy && echo -e "\n***WARNING - This may take over an hour depending on the speed of your internet connection and your laptop\n"
    vagrant up

    popd >/dev/null || exit 1
}

install_Kali
