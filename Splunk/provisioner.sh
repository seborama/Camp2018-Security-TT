#!/usr/bin/env bash

sudo dpkg -i /vagrant/splunk-7*
sudo /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd "${SPLUNK_PASSWORD}"
sudo /opt/splunk/bin/splunk enable boot-start
