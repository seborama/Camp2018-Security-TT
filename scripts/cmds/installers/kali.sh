#!/usr/bin/env bash
# A desirable attribute of a sub-script is that it does not use global env variables that
# were created by its parents (bash and system env vars are ok). Use function arguments instead to
# pass such variables
# There should be scarce exceptions to this rule (such as a var that contains the script main install dir)

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
