#!/bin/sh

enable_in_conf()
{
    conffile=$1
    option=$2
    sed -i "s/${option}=n/${option}=y/g" $conffile
}
disable_in_conf()
{
    conffile=$1
    option=$2
    sed -i "s/${option}=y/${option}=n/g" $conffile
}

move_task_to_top()
{
    task=$1
    sed -i "/ - ${task}/d" /etc/cloud/cloud.cfg
    sed -i "/cloud_init_modules/a\\ - ${task}" /etc/cloud/cloud.cfg
}

echo Install required packages
apt-get -y install python3-jinja2 python3-jsonpatch python3-jsonschema python3-oauthlib python3-requests python3-six python3-yaml python3-configobj lsb-release dirmngr apt-transport-https locales


echo adding key for repo
apt-key adv --keyserver packages.microsoft.com --recv-keys BC528686B50D79E339D3721CEB3E94ADBE1229CF

echo Install correct APT package mirror definitions
cat >/etc/apt/sources.list.d/cloudinit.list <<EOF3
## Note, this file is added on first boot of an instance
## modifications made here will not survive a re-bundle.
## if you wish to make changes you can:
## a.) add 'apt_preserve_sources_list: true' to /etc/cloud/cloud.cfg
##     or do the same in user-data
## b.) add sources in /etc/apt/sources.list.d
## c.) make changes to template file /etc/cloud/templates/sources.list.tmpl

deb https://packages.microsoft.com/repos/cloudinit-debian-9 trusty main
EOF3
sudo apt-get update

echo installing 2.2.34 waagent, that is customized to work with cloud-init
apt install -y waagent=2.2.34-4ms~deb9u1
apt-get -y install cloud-init

echo locking version of agent and cloud-init, so it does not get upgraded
apt-mark hold waagent
apt-mark hold cloud-init


ci=/etc/cloud
cloudcfg=$ci/cloud.cfg
cicfgd=$ci/cloud.cfg.d

echo Ensure cloud-init uses its builtin function to interact with control plane
cat >$cicfgd/01_agentless.cfg <<EOF1

# config for Azure

datasource:
  Azure:
    agent_command: __builtin__
EOF1

echo Install correct APT package mirror definitions
cat >$cicfgd/91-set-src-list.cfg <<EOF3
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
EOF3

echo Configure waagent to rely on cloud-init for provisioning actions
disable_in_conf /etc/waagent.conf Provisioning.Enabled
enable_in_conf  /etc/waagent.conf Provisioning.UseCloudInit
disable_in_conf /etc/waagent.conf ResourceDisk.Format
disable_in_conf /etc/waagent.conf ResourceDisk.EnableSwap

echo Alter standard config to attach/format/mount disks at the first opportunity
move_task_to_top mounts
move_task_to_top disk_setup

echo Alter standard config to specify ubuntu as the distro
sed -i '/distro:/s/: .*$/: debian/' $cloudcfg

echo disabling waagent-apt.service, as it runs apt-get update, but clashes with cloud-init configs that do the same
systemctl disable waagent-apt.service

echo Enabling cloud-init service
systemctl enable cloud-config cloud-final cloud-init-local cloud-init
cloud-init clean --logs

echo Deprovision VM via waagent
/usr/sbin/waagent -force -deprovision+user
rm -f /var/log/syslog /var/log/waagent.log

export HISTSIZE=0 && sync
