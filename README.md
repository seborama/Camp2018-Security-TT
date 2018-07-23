# Security Topic Team

Pen-testing playground lab.

## Splunk Enterprise Security (pre-requisite)

Sign up for the Trial (Cloud):

- https://www.splunk.com/page/sign_up/es_sandbox?redirecturl=%2Fgetsplunk%2Fes_sandbox

Once your trial instance is running, navigate to it and follow the steps below.

### Download your Universal Forwarder Credentials for the Trial

The set-up script needs your trial credentials to forward events from the Minikube K8s cluster to Splunk Enterprise Security in the Cloud.

Click Apps in the menu bar at the top of the web page > Universal Forwarder

Click the 'Download Universal Forwarder Credentials' button, point number 3 (at time of writing).

This will download a file called `splunkclouduf.spl`. Keep it handy, you'll use it during set-up.

### Community edition (not yet explored)

- https://www.phantom.us/download/

## Set up instructions

To set up the lab, run:

```bash
./scripts/setup.sh
```

### Configuration options

Some default settings may be overridden via shell variables.

`MINIKUBE_PROFILE`: the Minikube profile name. NOTE: several versions of Minikube (e.g. 0.27, 0.28) fail unless the profile name is `minikube`.
`MINIKUBE_VM_DRIVER`: the Minikube VM driver.

```bash
# Example
MINIKUBE_VM_DRIVER=hyperkit MINIKUBE_PROFILE=example-profile ./scripts/setup.sh
```

Note:
- changing `MINIKUBE_VM_DRIVER` may cause issues if Kali Linux is not running in the same Hypervisor.

  You will need to use a NATPF set-up or a tunnelling solution to allow Kali to access the Minikube VM.

## Kali Linux

At time of writing, the default credentials are user `vagrant` and password `changeme`.

To access the root user, use `sudo -s`.

You can also use vagrant ssh and change the password of the vagrant user to a desired value.

Useful reference:

- https://www.kali.org/news/kali-linux-metapackages/
- https://tools.kali.org/tools-listing

## Splunk Enterprise

Splunk runs on the minikube IP on port 30800.

Log in as user `admin` with the password you keyed in during set-up.

## Splunk Trials

This is optional, only to satisfy your curiosity or to explore Splunk further.

Register for a trial at:

- https://www.splunk.com/en_us/download/splunk-enterprise/thank-you-enterprise.html

```bash
wget -O splunk-7.1.1-8f0ead9ec3db-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.1.1&product=splunk&filename=splunk-7.1.1-8f0ead9ec3db-linux-2.6-amd64.deb&wget=true'
```

## Advanced Topics

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

#### Utility `pfctl` (Mac OSX)

Control the packet filter (PF) and network address translation (NAT) device.

See an example use here:

https://apple.stackexchange.com/questions/296520/port-forwarding-on-mac-pro-with-macos-sierra

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

- http://networkinferno.net/port-forwarding-on-vmware-fusion

#### VirtualBox Fusion NATPF

`VBoxManage`

VirtualBox Command Line Management Interface.
