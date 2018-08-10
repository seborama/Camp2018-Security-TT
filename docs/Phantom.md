## Phantom (Community edition of Splunk Enterprise Security)

**This is an optional alternative to SES, set-up and configuration are manual.**

  - Register at:
    - https://www.phantom.us/download/
  - Download the Phantom VM
  - Install it (VirtualBox recommended for network reasons since the rest of this project currently uses VirtualBox)

### Phantom app for Splunk

This is not currently automated.

  - Download the Phantom app for Splunk from SplunkBase:
    - https://splunkbase.splunk.com/app/3411/
  - Installation instructions at:
    - https://<phantom_vm_ip>/docs/admin/splunk
  
Notes:

  - App: Phantom -> Phantom Server Configuration:
  
    Error loading Phantom Server Configurations: You must have phantom_read, phantom_write and admin_all_objects permissions.
      - Splunk Web UI > Settings > Access controls > Roles > Admin > Capabilities
      - Move phantom_read, phantom_write from Available capabilities to Selected capabilities
      - Save
      - Then try Phantom Server Configuration again
  - App: Phantom -> Phantom Server Configuration:
  
    Could not communicate with Phantom server "https://a.b.c.d": [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed
    - From your browser (or any other method you like), export the certificate of the Phantom. machine as X.509 Certificate (PEM).
    - For instance, with Firefox: Click the padlock icon on the left of the URL > Click the arrow next to the IP address (if you're using the IP as I am) > More information (at the bottom) > Security tab > View Certificate > in the next open that opens > Details > Export
    - Copy this to your Splunk machine in $SPLUNK_HOME/etc/apps/phantom/local/cert_bundle.pem
    - Now return to Splunk's Web UI and save your "Phantom Server Configuration" again. This should be accepted. No restart required.
    - If you get stuck, you could disable HTTPS verification in `$SPLUNK_HOME/etc/apps/phantom/local/phantom.conf`
  - App: Phantom -> Phantom Server Configuration:
  
    Could not communicate with Phantom server "https://a.b.c.d": hostname 'a.b.c.d' doesn't match u'phantom'
      - Log onto the Splunk container
      - Edit /etc/hosts
      - Add: `a.b.c.d phantom`,  a.b.c.d should be the actual IP of the Phantom machine
      - Edit the Phantom Server Configuration and replace the a.b.c.d IP with `phantom`:
        - "server": "https://phantom"
