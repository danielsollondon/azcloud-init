# Test Code for installing and configuring cloud-init 18.5 on Debian 9

>> NOTE : THIS IS TEST CODE, provided as-is, and must not be used in production, the author accepts no responsibility for its use.

## Create a Debian 9 VM
```bash
az group create --name <resourceGroup> --location centralus

az vm create \
  --resource-group <resourceGroup> \
  --name <vmName> \
  --admin-username azadmin \
  --image credativ:Debian:9:latest \
  --ssh-key-value /.../.pub 
```
Now ssh in to the VM.

## Disable the Linux Agent for Provisioning
```bash
sed -i 's/Provisioning.Enabled=y/Provisioning.Enabled=n/g' /etc/waagent.conf
sed -i 's/Provisioning.UseCloudInit=n/Provisioning.UseCloudInit=y/g' /etc/waagent.conf
sed -i 's/ResourceDisk.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf
sed -i 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf
```
## Install cloud-init dependencies
```bash
apt-get -y install python3-configobj python3-jinja2 python3-jsonpatch python3-oauthlib python3-prettytable python3-requests python3-requests python3-six python3-six python3-yaml 
apt-get -y install cloud-guest-utils gdisk locales lsb-release eatmydata python3-pip python-pip

pip install --upgrade netutils-linux 
```
>>Note!! We need to go back and evaluate that all these packages are needed.

### install python-six
cloud-init has a dependency on six>=1.11.0, this is not in the Debian 9 repo.

```bash
wget https://pypi.io/packages/source/s/six/six-1.11.0.tar.gz
tar -xf six-1.11.0.tar.gz
cd six-1.11.0
python2 setup.py build
python2 setup.py install --optimize=1
python3 setup.py build
python3 setup.py install --optimize=1

cd ..
```
## install cloud-init
```bash
apt-get -y install git
git clone https://github.com/cloud-init/cloud-init.git
cd cloud-init
sudo pip3 install -r requirements.txt 
sudo python3 setup.py build

sudo python3 setup.py install --init-system systemd
sudo cloud-init init --local
sudo cloud-init status

sudo ln -s /usr/local/bin/cloud-init /usr/bin/cloud-init
for svc in cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service; do
  sudo systemctl enable $svc
  sudo systemctl start  $svc
done
```
## deprovision the VM 
```bash
sudo waagent -deprovision+user -force
cloud-init clean -l
```

## logout of the VM and create the image
```bash
az vm deallocate --resource-group <resourceGroup> --name <vmName>
az vm generalize --resource-group <resourceGroup> --name <vmName>
az image create --resource-group <resourceGroup> --name deb9CiImage01 --source <vmName>
```

```bash
az vm create \
  --resource-group <resourceGroup> \
  --name <newVmName> \
  --admin-username ciadmin \
  --image deb9CiImage01 \
  --location centralus \
  --boot-diagnostics-storage <storageAcc> \
  --ssh-key-value /../.pub 
```

### Known issues
1. Deallocate and start fails to mount the ephemeral disk