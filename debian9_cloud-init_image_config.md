# Test Code for installing and configuring cloud-init 18.5 on Debian 9

>> NOTE : THIS IS TEST CODE, provided as-is, and must not be used in production, the author accepts no responsibility for its use.

## Create a Debian 9 VM
```bash
az group create --name <resourceGroup> --location centralus

az vm create \
  --resource-group <resourceGroup> \
  --name <srcVmName> \
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
apt-get -y install python3-configobj python3-jinja2 python3-jsonpatch python3-oauthlib python3-prettytable python3-requests python3-requests python3-six python3-six python3-yaml cloud-guest-utils gdisk locales lsb-release eatmydata python3-pip python-pip

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

# patch to address networking config error
wget https://code.launchpad.net/~jasonzio/cloud-init/+git/cloud-init/+merge/365377/+preview-diff/868252/+files/preview.diff

## patch to turn getting network config from IMDS off
wget -O preview2.diff https://code.launchpad.net/~jasonzio/cloud-init/+git/cloud-init/+merge/364012/+preview-diff/865526/+files/preview.diff

cd /home/azadmin/cloud-init/cloudinit
git apply /home/azadmin/preview.diff
git apply /home/azadmin/preview2.diff
cd ..

sudo pip3 install -r requirements.txt 
sudo python3 setup.py build

sudo python3 setup.py install --init-system systemd

## stop cloud-init overriding existing source lists
cat > /etc/cloud/cloud.cfg.d/91-set-src-list.cfg <<EOF
# CLOUD_IMG: This file was created/modified by the Cloud Image build process
system_info:
   package_mirrors:
     - arches: [i386, amd64]
       failsafe:
         primary: http://debian-archive.trafficmanager.net/debian
         security: http://debian-archive.trafficmanager.net/debian-security
       search:
         primary:
           - http://debian-archive.trafficmanager.net/debian
         security: []
     - arches: [armhf, armel, default]
       failsafe:
         primary: http://debian-archive.trafficmanager.net/debian
         security: http://debian-archive.trafficmanager.net/debian
EOF


sudo cloud-init init --local
sudo cloud-init status

# this takes approx 1min to run...wait for it to complete!
sudo ln -s /usr/local/bin/cloud-init /usr/bin/cloud-init
for svc in cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service; do
  sudo systemctl enable $svc
  sudo systemctl start  $svc
done

## this service cause apt-get update, but clashes with cloud-init, if it is install packages or updates at VM provision time
systemctl disable waagent-apt.service

## deprovision VM
sudo waagent -deprovision -force
cloud-init clean
cloud-init clean -l


## and logout
```
### create the image
```bash
az vm deallocate --resource-group cloudinitdeb4 --name <srcVmName>
az vm generalize --resource-group cloudinitdeb4 --name <srcVmName>
az image create --resource-group cloudinitdeb4 --name deb9CiImage01 --source <srcVmName>
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


### Resolved issues
1. Deallocate and start fails to mount the ephemeral disk - resolved by patch: wget https://code.launchpad.net/~jasonzio/cloud-init/+git/cloud-init/+merge/365377/+preview-diff/868252/+files/preview.diff

2. When custom image is created, apt-get installs fail.

/etc/apt/sources.list is populated with default cloud-init source lists

fix: Set up the repos, see override: /etc/cloud/cloud.cfg.d/91-set-src-list.cfg

3. Running a cloud-init config:
#cloud-config
package_upgrade: true
packages:
  - curl

cloud-init.log showed:
```text
cloudinit.util.ProcessExecutionError: Unexpected error while running command. 
Command: ['eatmydata', 'apt-get', '--option=Dpkg::Options::=--force-confold', '--option=Dpkg::options::=--force-unsafe-io', '--assume-yes', '--quiet', 'update'] 
Exit code: 100 
Reason: - 
Stdout: - 
```
Package manager was already in use, caused by waagent-apt.service running at the same time. Check this file:*vi /usr/share/waagent/apt-setup*

disabling fixed this
systemctl disable waagent-apt.service

