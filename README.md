## Security Topic Team

Pen-testing detection lab.

⚠️ Under construction ⚠️

### Set up instructions

To set up the lab, run:

```bash
./scripts/setup.sh
```

##### Configuration options

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

##### Vagrant and VMWare Fusion

This requires a commercial addon.

Alternatively, you can download the .box file from:

- https://app.vagrantup.com/csi/boxes/kali_rolling/versions/2018.2.2/providers/vmware_desktop.box

Extract the contents and manually install.

Commands to investigate:

```bash
vagrant box add kali-linux file:///d:/path/to/csi_kali/vmware_desktop.box
```

### NATPF and SSH Tunnels

You need to allow Kali to connect to the Minikube VM. This is particularly important when they are not running under the same Hypervisor.


##### SSH tunnel

```bash
# expose access to wordpress inside minikube via localhost:30100 (this could also be done with kubectl port-forward)
ssh -i ~/.minikube/machines/<profile_name>/id_rsa -L 30100:localhost:30100 -N docker@`minikube --profile=<profile_name> ip`

# enable access to wordpress inside minikube via localhost:30100 from within Kali Linux
vagrant ssh -- -R 30100:localhost:30100 -N
```

Together, these two commands effectively create a bridge between Kali Linux and the wordpress service running inside Minikube.

##### Utility `pfctl` (Mac OSX)

TBC

##### Utility `kubectl port-forward`

TBC

##### Utility `socat`

On Mac OSX, you can `brew` it.

TBC

##### VMWare Fusion NATPF

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

##### VirtualBox Fusion NATPF

`VBoxManage`

TBC

### Kali Linux

At time of writing, the default credentials are user `vagrant` and password `changeme`.

To access the root user, use `sudo -s`.

You can also use vagrant ssh and change the password of the vagrant user to a desired value.

Useful reference:

- https://www.kali.org/news/kali-linux-metapackages/
- https://tools.kali.org/tools-listing

### Splunk Enterprise


Splunk runs on the minikube IP on port 30800.

Log in as user `admin` with the password you keyed in during set-up.

#### Splunk Trials

This is optional, only to satisfy your curiosity or to explore Splunk further.

Register for a trial at:

- https://www.splunk.com/en_us/download/splunk-enterprise/thank-you-enterprise.html

```bash
wget -O splunk-7.1.1-8f0ead9ec3db-linux-2.6-amd64.deb 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.1.1&product=splunk&filename=splunk-7.1.1-8f0ead9ec3db-linux-2.6-amd64.deb&wget=true'
```

### Splunk Enterprise Security

Trial (Cloud):

- https://www.splunk.com/page/sign_up/es_sandbox?redirecturl=%2Fgetsplunk%2Fes_sandbox

Community edition:

- https://www.phantom.us/download/
