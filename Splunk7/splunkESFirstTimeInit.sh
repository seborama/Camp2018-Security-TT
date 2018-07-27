#!/usr/bin/env bash

#TODO: check that the shebang is coorect for a startup script

# TODO: this file would have to be injected using a 'kubectl copy' or similar - safe?? use K8s Secret instead??
SPLUNK_USER_PASSWORD_FILE=somepasswordfile

COMPLETED_FIRST_TIME_INIT_FLAG="/opt/staging/splunkEnterprise/firstTimeInit.COMPLETED"
if [ -f "${COMPLETED_FIRST_TIME_INIT_FLAG}" ]; then
    echo "First time initialisation of splunkES forwarding app has already been completed previously"
    echo "Nothing more to do"
    # TODO: should we use return instead of exit?
    exit 0
fi

echo "Not written yet"
echo 'RUN: ./bin/splunk install app /opt/staging/splunkES/security-tt//splunkclouduf.spl -auth admin:$(cat "${SPLUNK_USER_PASSWORD_FILE}")'
echo "AND FINALLY ./bin/splunk restart"


# when complete success then mark init complete
rm "${SPLUNK_USER_PASSWORD_FILE}" # Should this be in a K8s Secret? Won't be transient though...
touch "${COMPLETED_FIRST_TIME_INIT_FLAG}"
