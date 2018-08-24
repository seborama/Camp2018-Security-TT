#!/bin/bash

echo "=================================================="
echo Parameters: "$@"
echo "=================================================="

echo "*** Run the original splunk/splunk entrypoint"
/sbin/entrypoint-ORG.sh "$@" &

if [ -e "/opt/staging/splunkEnterprise/security-tt/splunkclouduf.spl" ]; then
    echo "*** Integrate with SplunkES"
    sleep 60
    # shellcheck source=/opt/splunk/bin/setSplunkEnv
    . "${SPLUNK_HOME:-/opt/splunk}/bin/setSplunkEnv"
    /opt/staging/splunkEnterprise/splunkESFirstTimeInit.sh
fi

echo "*** Holding onto the container while background processes are running..."
wait
