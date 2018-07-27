#!/usr/bin/env bash

readonly COMPLETED_FIRST_TIME_INIT_FLAG="/opt/staging/splunkEnterprise/firstTimeInit.COMPLETED"
failed=0


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
/opt/splunk/bin/splunk install app "/opt/staging/splunkEnterprise/security-tt/splunkclouduf.spl" -auth admin:$(cat "/opt/staging/splunkEnterprise/security-tt/splunkescreds.txt")
if [ $? -ne 0 ]; then
    echo "*******************************************************************************"
    echo "FATAL: Initialisation FAILED"
    echo "*******************************************************************************"
    failed=1
fi

/opt/splunk/bin/splunk restart
if [ $? -ne 0 ]; then
    echo "*******************************************************************************"
    echo "FATAL: SplunkES restart FAILED"
    echo "*******************************************************************************"
    failed=1
fi


# when complete success then mark init complete
[ ${failed} -eq 0 ] && touch "${COMPLETED_FIRST_TIME_INIT_FLAG}"

exit 0
