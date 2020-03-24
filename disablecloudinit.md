# Testing disabling cloud-init
> Note! This is test code, not for production!

## Ubuntu 18.04

```bash
echo disable cloud-init
touch /etc/cloud/cloud-init.disabled
sudo sed -i '/azure_resource/d' /etc/fstab
echo comment out source VM config
sudo sed -i -e 's/match:/#match:/g' /etc/netplan/50-cloud-init.yaml
sudo sed -i -e 's/macaddress:/#macaddress:/g' /etc/netplan/50-cloud-init.yaml
sudo sed -i -e 's/set-name:/#set-name:/g' /etc/netplan/50-cloud-init.yaml
echo update the netplan config
echo note you would need to restart the systemd.networkd.service to apply it
echo this relies on a new VM starting the network with this config
sudo netplan generate
sudo netplan apply
```
 
