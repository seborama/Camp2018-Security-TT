FROM splunk/splunk:7.1.2

LABEL com.zuhlke.maintainer="Sebastien C"

# Update base system with latest available security updates
RUN apt-get update # && \
#    apt-get upgrade -y --no-install-recommends && \
#    apt-get autoclean && \
#    apt-get autoremove

# Deploy support tools - This may be removed in the future
RUN apt-get install -y --no-install-recommends vim curl \
    apt-get autoclean && \
    apt-get autoremove

# Re-point configuration files to those exposed by K8s via the ConfigMap volume mount
RUN ln -s /opt/staging/splunk/etc/apps/security-tt /var/opt/splunk/etc/apps

# Adds first-time execution set-up for Splunk Cloud Universal Forwarder app
# This will trigger containers built upon this image to forward messages to Splunk Enterprise Security / Phantom
COPY splunkESFirstTimeInit.sh /etc/rc.local
RUN chmod 754 /etc/rc.local
