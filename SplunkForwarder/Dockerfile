FROM splunk/universalforwarder:7.0.3

LABEL com.zuhlke.maintainer="Sebastien Chatal"

RUN ln -s /opt/staging/splunk/etc/apps/splunkclouduf /var/opt/splunk/etc/apps

COPY inputs.conf /var/opt/splunk/etc/system/local
COPY outputs.conf /var/opt/splunk/etc/system/local
