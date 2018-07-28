#!/bin/bash

echo "=================================================="
echo Parameters: "$@"
echo "=================================================="

echo "*** Run the original splunk/splunk entrypoint"
/sbin/entrypoint-ORG.sh "$@" &

echo "*** Integrate with SplunkES / Phantom"
sleep 60
. "${SPLUNK_HOME}/bin/setSplunkEnv"
/opt/staging/splunkEnterprise/splunkESFirstTimeInit.sh

echo "*** Hold onto the container while background processes are running"
wait
