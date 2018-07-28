#!/bin/bash

RESTART_SPLUNK=1
[ "x$1" == "x--no-restart" ] && RESTART_SPLUNK=0


readonly COMPLETED_FIRST_TIME_INIT_FLAG="/opt/staging/splunkEnterprise/firstTimeInit.COMPLETED"
failed=0
if [ -z "${HOME}" ]; then
    export HOME=/root
fi


if [ -f "${COMPLETED_FIRST_TIME_INIT_FLAG}" ]; then
    echo "*******************************************************************************"
    echo "SplunkES forwarding app has already been initialised"
    echo "Nothing more to do"
    echo "*******************************************************************************"
    exit 0
fi

echo "*******************************************************************************"
echo "First time initialisation of SplunkES forwarding app"
echo "*******************************************************************************"
echo
echo "*** Installing splunkclouduf app"
/opt/splunk/bin/splunk install app "/opt/staging/splunkEnterprise/security-tt/splunkclouduf.spl" -auth "$(cat "/opt/staging/splunkEnterprise/security-tt/splunkescreds.txt")"
if [ $? -ne 0 ]; then
    echo "*******************************************************************************"
    echo "FATAL: Initialisation FAILED"
    echo "*******************************************************************************"
    failed=1
fi

if [ "${RESTART_SPLUNK}" == "1" ]; then
    echo "*** Restarting splunk to apply changes"
    echo
    /opt/splunk/bin/splunk restart
    if [ $? -ne 0 ]; then
        echo "*******************************************************************************"
        echo "FATAL: SplunkES restart FAILED"
        echo "*******************************************************************************"
        failed=1
    fi
fi


# when complete success then mark init complete
[ ${failed} -eq 0 ] && touch "${COMPLETED_FIRST_TIME_INIT_FLAG}"

exit 0
