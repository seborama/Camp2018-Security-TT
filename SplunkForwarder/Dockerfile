FROM splunk/universalforwarder:7.0.3

LABEL com.zuhlke.maintainer="Sebastien C"

# Re-point configuration files to those exposed by K8s via the ConfigMap volume mount
RUN rm /var/opt/splunk/etc/auth/splunk.secret ; \
    rm /var/opt/splunk/etc/system/local/deploymentclient.conf ; \
    ln -s /opt/staging/splunk/etc/apps/splunkclouduf/default/splunk.secret /var/opt/splunk/etc/auth/splunk.secret && \
    ln -s /opt/staging/splunk/etc/apps/splunkclouduf/default/deploymentclient.conf /var/opt/splunk/etc/system/local/deploymentclient.conf
