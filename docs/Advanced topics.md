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

#### SSH tunnels - Various general techniques & references

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
