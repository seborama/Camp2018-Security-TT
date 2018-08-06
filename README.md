# Security Topic Team

Pen-testing playground lab.

What you get:

  - ✅ Homebrew, VirtualBox, Docker, Vagrant, Minikube
  - ✅ Kali Linux (in VirtualBox)
  - ✅ Slunk (Minikube K8s cluster)
  - ✅ Wordpress (Minikube K8s cluster)
  - ✅ Integration with Splunk Enterprise Security
  - ✅ (manual) Phantom (Community edition of Splunk Enterprise Security) (VirtualBox)

To do:
  - ❎ Add CPU and RAM limits to K8s pods

## Pre-requisites

### Recommended machine specifications

  - 16 GB RAM
  - 8 core CPU
  - 30 GB storage

### Splunk Enterprise Security (current solution)

Sign up for the Trial (Cloud):

  - https://www.splunk.com/page/sign_up/es_sandbox?redirecturl=%2Fgetsplunk%2Fes_sandbox

### Download your Universal Forwarder Credentials from your Splunk Enterprise Security / Phantom instance (for explorers only ☺️)

Once your instance of SES or Phantom is running, log on to its Web UI.

The set-up script needs your SUF credentials to forward events from the Minikube K8s cluster's Splunk instance.

In SES:

  - Click Apps in the menu bar at the top of the web page > Universal Forwarder
  - Click the 'Download Universal Forwarder Credentials' button, point number 3 (at time of writing).
  - This will download a file called `splunkclouduf.spl`. Keep it handy, you'll use it during set-up.

### Phantom (Community edition of Splunk Enterprise Security)

  - Register at:
    - https://www.phantom.us/download/
  - Download the VM
  - Install it (VirtualBox recommended for network reasons since the rest of this project currently uses VirtualBox)

#### Phantom app for Splunk

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

  
## Set up instructions

To set up the lab, run:

```bash
./scripts/setup.sh
```

And follow the instructions the script displays.

### Configuration options

Some default settings may be overridden via shell variables:

  - `MINIKUBE_PROFILE`: the Minikube profile name.

    NOTE: several versions of Minikube (e.g. 0.27, 0.28) fail unless the profile name is `minikube`.
  - `MINIKUBE_VM_DRIVER`: the Minikube VM driver.

```bash
# Example
MINIKUBE_VM_DRIVER=hyperkit MINIKUBE_PROFILE=example-profile ./scripts/setup.sh
```

Note:

- changing `MINIKUBE_VM_DRIVER` may cause issues if Kali Linux is not running in the same Hypervisor.

  You will need to use a NATPF set-up or a tunnelling solution to allow Kali to access the Minikube VM.

## Kali Linux

The login user is `vagrant` and the password is `vagrant`, change it manually after the first logon.

To access the root user, use `sudo -s`.

Useful reference:

  - https://www.kali.org/news/kali-linux-metapackages/
  - https://tools.kali.org/tools-listing
  
You can access the Wordpress service from Kali on:
  - http://<`minikube ip>`:30100
  - https://<`minikube ip>`:30101
    - (you will likely require to export the cert from wordpress and import it where necessary)

## Splunk Enterprise

Splunk runs on the minikube IP on port 30800.

The minikube IP is displayed during the set-up. After that you can run this command to find it again:

```bash
minikube ip
```

Log in as user `admin` with the password you keyed in during set-up.

## Splunk Trials

This is not needed and only to satisfy your curiosity or to explore Splunk further.

Register for a trial at:

  - https://www.splunk.com/en_us/download/splunk-enterprise/thank-you-enterprise.html

```bash
wget -O splunk-7.1.1-8f0ead9ec3db-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.1.1&product=splunk&filename=splunk-7.1.1-8f0ead9ec3db-linux-2.6-amd64.deb&wget=true'
```

## Advanced Topics

### Vagrant base boxes

Useful links:

  - https://www.vagrantup.com/docs/boxes/base.html

  - https://www.engineyard.com/blog/building-a-vagrant-box-from-start-to-finish

### Vagrant and VMWare Fusion

This requires a commercial addon.

Alternatively, you can download the .box file from:

  - https://app.vagrantup.com/csi/boxes/kali_rolling/versions/2018.2.2/providers/vmware_desktop.box

Extract the contents and manually install.

Commands to investigate:

```bash
vagrant box add kali-linux file:///d:/path/to/csi_kali/vmware_desktop.box
```

### NATPF and SSH Tunnels

Below are some options that also exist to create network configurations that may be useful in some advanced situations.

#### SSH tunnel

```bash
# expose access to wordpress inside minikube via localhost:30100 (this could also be done with kubectl port-forward)
ssh -i ~/.minikube/machines/<profile_name>/id_rsa -L 30100:localhost:30100 -N docker@`minikube --profile=<profile_name> ip`

# enable access to wordpress inside minikube via localhost:30100 from within Kali Linux
vagrant ssh -- -R 30100:localhost:30100 -N
```

Together, these two commands effectively create a bridge between Kali Linux and the wordpress service running inside Minikube.

#### Utility `pfctl` (Mac OSX)

Control the packet filter (PF) and network address translation (NAT) device.

See an example use here:

  - https://apple.stackexchange.com/questions/296520/port-forwarding-on-mac-pro-with-macos-sierra

The pfdump.sh script has been included to this repo for convenience (under the directory `scripts`).
     
#### Utility `kubectl port-forward`

Forward one or more local ports to a pod.

#### Utility `socat`

Multipurpose relay (SOcket CAT).

On Mac OSX, you can `brew` it.

#### VMWare Fusion NATPF

Edit `/Library/Preferences/VMware\ Fusion/vmnet???/nat.conf`

Where `vmnet???` can be determined using `ifconfig` and locating the IP address of the Fusion VM.

Refer to the bottom of `nat.conf` for examples of NATPF (`incomingtcp` / `incomingudp`)

Run:

```bash
sudo /Applications/VMware\ Fusion.app/Contents/Library/vmnet-cli --stop
sudo /Applications/VMware\ Fusion.app/Contents/Library/vmnet-cli --start
```

More information:

  - - http://networkinferno.net/port-forwarding-on-vmware-fusion

#### VirtualBox Fusion NATPF

`VBoxManage`

VirtualBox Command Line Management Interface.
