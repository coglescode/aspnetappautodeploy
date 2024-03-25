#!/bin/bash

# Variables
rg=AppDriftMiljö
asg=App-SG
bastion_sg=BastionHost-NSG
appserver_sg=AppServer-NSG
webserver_sg=WebServer-NSG
location=northeurope
vnet_name=RPNetwork
address_prefix="10.0.0.0/16"
subnet_name=DNSubnet
subnet_prefixes="10.0.0.0/24" 
app_server_port=5000
web_server_port=80
vm_size=Standard_B1s
vm_name1=BastionHost
vm_name2=WebServer
vm_name3=AppServer
image=Ubuntu2204
username=coglescode
nginx_cloud_init=install_nginx.sh
dotnet_cloud_init=dotnet_init.sh
bastionhost_cloud_init=bastion_init.sh

echo "Enter the name of the app:" 
read appname
sed "s/\${appname}/$appname/g" cloud_init.sh > $dotnet_cloud_init 

ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/$vm_name1

ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/$vm_name2

ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/$vm_name3


az group create -n $rg --location $location 

az network vnet create -g $rg --name $vnet_name --address-prefix $address_prefix 

# Subnet creation requiered a VNet
az network vnet subnet create -g $rg --vnet-name $vnet_name -n $subnet_name --address-prefixes $subnet_prefixes


#### Application Security Group ###
az network asg create -g $rg -n $asg --location $location


### Network Security Groups and  Rules ###
az network nsg create -g $rg -n $bastion_sg --location $location

az network nsg create -g $rg -n $appserver_sg --location $location

az network nsg create -g $rg -n $webserver_sg --location $location


### Network Security Groups Rules --source-address-prefixes Internet###
az network nsg rule create -g $rg --nsg-name $bastion_sg -n Allow-SSH --priority 100 --source-address-prefixes Internet --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH on port 5022."

az network nsg rule create -g $rg --nsg-name $appserver_sg -n Allow-HTTP --priority 100 --source-address-prefixes Internet --destination-port-ranges 5000 --access Allow --protocol Tcp --description "Allow HTTP traffic."

az network nsg rule create -g $rg --nsg-name $appserver_sg -n Allow-SSH --priority 101 --source-asgs $asg  --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH for App-SG on port 22."

az network nsg rule create -g $rg --nsg-name $appserver_sg -n Denied-SSH --priority 102 --source-address-prefixes Internet --destination-port-ranges 22 --access Deny --protocol Tcp --description "Deny all SSH access on port 22."

az network nsg rule create -g $rg --nsg-name $webserver_sg -n Allow-HTTP --priority 100 --source-address-prefixes Internet --destination-port-ranges 80 --access Allow --protocol Tcp --description "Allow HTTP traffic."

az network nsg rule create -g $rg --nsg-name $webserver_sg -n Allow-SSH --priority 101 --source-asgs $asg  --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH for App-SG on port 2022."

az network nsg rule create -g $rg --nsg-name $webserver_sg -n Denied-SSH --priority 102 --source-address-prefixes Internet --destination-port-ranges 22 --access Deny --protocol Tcp --description "Deny all SSH access on port 22."

## Bastion Host Server
az sshkey create --location $location  -g $rg --name $vm_name1 --public-key @c:/Users/leito/.ssh/$vm_name1".pub"
az vm create -g $rg -n $vm_name1 --image $image --size $vm_size --vnet-name $vnet_name --subnet $subnet_name --nsg $bastion_sg --asg $asg --admin-username $username \
  --ssh-key-name $vm_name1 \
  --verbose

## Nginx Reverse Proxy Web Server 
az sshkey create --location $location  -g $rg --name $vm_name2 --public-key @c:/Users/leito/.ssh/$vm_name2".pub"
az vm create -g $rg -n $vm_name2 --image $image --size $vm_size --vnet-name $vnet_name --subnet $subnet_name  --nsg $webserver_sg --admin-username $username \
  --ssh-key-name $vm_name2 \
  --custom-data @$nginx_cloud_init \
  --verbose

az network nic ip-config update --name "ipconfig"$vm_name2 -g $rg --nic-name $vm_name2"VMNic" --public-ip-address null


## App server VM
az sshkey create --location $location  -g $rg --name $vm_name3 --public-key @c:/Users/leito/.ssh/$vm_name3".pub"
az vm create -g $rg -n $vm_name3 --image $image --size $vm_size --vnet-name $vnet_name --subnet $subnet_name  --nsg $appserver_sg --admin-username $username \
  --ssh-key-name $vm_name3 \
  --custom-data @$dotnet_cloud_init --verbose

az network nic ip-config update --name "ipconfig"$vm_name3 -g $rg --nic-name $vm_name3"VMNic" --public-ip-address null


####
bastionPublicIp=$(az vm show -g $rg -n $vm_name1 --show-details --query publicIps --output table)
proxyPrivateIp=$(az vm show -g $rg -n $vm_name2 --show-details --query privateIps --output table)
appPrivateIp=$(az vm show -g $rg -n $vm_name3 --show-details --query privateIps --output table)


echo "AppServer and WebServer private keys are going to be copied to BastionHost. Type yes when prompted"
scp -r -i ~/.ssh/$vm_name1 ~/.ssh/$vm_name2 ~/.ssh/$vm_name3 coglescode@$bastionPublicIp:~/.ssh

####
#az vm run-command invoke -g $rg -n $vm_name1 --command-id RunShellScript --scripts "chmod 400 ~/.ssh/$vm_name2 chmod 400 ~/.ssh/$vm_name3"

echo "$vm_name1 ${bastionPublicIp}"
echo "$vm_name2 ${proxyPrivateIp}"
echo "$vm_name3 ${appPrivateIp}"