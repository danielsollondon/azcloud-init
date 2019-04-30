# Cloud-init configuration for Debian 9

Please see these instructions to configure an existing Azure Marketplace Debian 9 Azure VM, to be provisioned by cloud-init 18.5.

The script will install an updated waagent package, and cloud-init 18.5, run the configurations, and guests deprovisioning code. 

## Step 1: Create a Debian 9 VM
```bash
az group create --name <resourceGroup> --location centralus

az vm create \
  --resource-group <resourceGroup> \
  --name <srcVmName> \
  --admin-username azadmin \
  --image credativ:Debian:9:latest \
  --ssh-key-value /.../.pub 
```
## Step 2: Run the Script
Inside the VM, run this script as root :debian9_cloud-init_script.sh

## Step 3: Create an Image

```bash
az vm deallocate --resource-group <resourceGroup> --name <srcVmName>
az vm generalize --resource-group <resourceGroup> --name <srcVmName>
az image create --resource-group <resourceGroup> --name deb9CiImage01 --source <srcVmName>
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
