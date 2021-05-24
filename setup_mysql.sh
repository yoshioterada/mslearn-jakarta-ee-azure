#!/bin/bash
set -e
#########################################################
# This script create the Azure Database for MySQL.
# After completed success, you can see like following result
# on your screen.
# After you executed the script, you can execute the client command.
# 
# Please execute the following command.
# ./setup_mysql.sh [generic/flexible]
# 
#[INFO] -------------------------------------------------------
#[INFO] Azure Database for MySQL Setup Completed SUCCESS
#[INFO] -------------------------------------------------------
#[INFO] 1. Please copy the following value into your temporal file
#[INFO]
#[INFO] RESOURCE GROUP is MySQL-RG-20201126014905
#[INFO] MySQL HOSTNAME is mysqlserver-dTvtrnTHlQ.mysql.database.azure.com
#[INFO] MySQL USERNAME is azureuser@mysqlserver-dTvtrnTHlQ
#[INFO] MySQL PASSWORD is !XlXveYjn29202
#[INFO]
#[INFO]
#[INFO] 2. Please execute the following command.
#[INFO]
#[INFO] mysql -u azureuser@mysqlserver-dTvtrnTHlQ \
#[INFO]       -h mysqlserver-dTvtrnTHlQ.mysql.database.azure.com \
#[INFO]       -p [Enter Key]
#[INFO] -------------------------------------------------------
#########################################################

#########################################################
# Argument Check
#########################################################

MYSQL_INSTANCE_SELECT=""
if [ -z "${1:-}" ]; then
    echo "Usage: ${0##*/} [generic/flexible]" >&2
    exit 1
fi
ARGUMENT=$1
echo "ARGUMENT:"$ARGUMENT;

if [ "$ARGUMENT" = "generic" ]; then 
  MYSQL_INSTANCE_SELECT="generic"
elif [ "$ARGUMENT" = "flexible" ]; then
  MYSQL_INSTANCE_SELECT="flexible"
else
  echo "Invalid Argument" 1>&2
  echo "$0 [generic/flexible]" 1>&2
  exit 1
fi

#########################################################
# You can change the following parameters due to the Rule
#
# MYSQL_RES_GRP_NAME= Azure Resource Group Name 
# MYSQL_SERVER_NAME= MySQL Server Name
# MYSQL_USER= MySQL Login Account Name
# MYSQL_PASSWORD= MySQL Login Password
#########################################################

RESOURCE_GRP_NAME_DATE=$(date '+%Y%m%d%T' |tr -d :)

### Following is the correct version. It create the severname with lower case
RANDOM_SERVER_NAME=$(cat /dev/urandom | base64 | tr -dc [:alpha:]|tr [:upper:] [:lower:] | fold -w 10 | head -n 1)

export MYSQL_RES_GRP_NAME='MySQL-RG-'$RESOURCE_GRP_NAME_DATE
export MYSQL_SERVER_NAME='mysqlserver-'$RANDOM_SERVER_NAME
export MYSQL_USER='azureuser'
MYSQL_PASSWORD='!'$(cat /dev/urandom | base64 | tr -dc [:alpha:]| fold -w 8 | head -n 1)$RANDOM
export PUBLIC_IP=$(curl ifconfig.io)

#########################################################
# For DEBUG
#########################################################
# echo "---------- DEBUG ----------"
# echo 'MYSQL_RES_GRP_NAME='$MYSQL_RES_GRP_NAME
# echo 'MYSQL_SERVER_NAME='$MYSQL_SERVER_NAME
# echo 'MYSQL_USER='$MYSQL_USER
# echo 'MYSQL_PASSWORD='$MYSQL_PASSWORD
# echo 'PUBLIC_IP='$PUBLIC_IP
# echo "---------- DEBUG ----------"

#########################################################
# When error happened following function will be executed  
#########################################################

function error_handler() {
  az group delete --no-wait --yes --name $MYSQL_RES_GRP_NAME
  echo "ERROR $1 occure :line no = $2" >&2
  exit 1
}
trap 'error_handler $? $LINENO' ERR

#########################################################
# Function Create Generic MySQL Instance
#########################################################

function CreateGeneriMySQLInstance() {
  echo "Creating MySQL Server"
  az mysql server create \
      --name $MYSQL_SERVER_NAME \
      --resource-group $MYSQL_RES_GRP_NAME \
      --admin-user $MYSQL_USER \
      --admin-password $MYSQL_PASSWORD \
      --sku-name GP_Gen5_2
  echo "Created MySQL Server as " $MYSQL_SERVER_NAME
  echo "Adding Firewall Rule for your Local IP Address" 
  az mysql server firewall-rule create \
      -g $MYSQL_RES_GRP_NAME \
      -s $MYSQL_SERVER_NAME \
      -n allowip_fromclient \
      --start-ip-address $PUBLIC_IP \
      --end-ip-address $PUBLIC_IP
  echo "Added Firewall Rule for your Local IP Address as" $PUBLIC_IP 
  echo "Adding Firewall Rule for Azure Address"
  az mysql server firewall-rule create \
      -g $MYSQL_RES_GRP_NAME \
      -s $MYSQL_SERVER_NAME \
      -n AllowAllAzureIPs \
      --start-ip-address 0.0.0.0 \
      --end-ip-address 255.255.255.255
  echo "Added Firewall Rule for Azure Address"
}

#########################################################
# Function Create Flexible Server MySQL Instance
#########################################################

function CreateFlexibleMySQLInstance() {
  echo "Creating MySQL Server"
  az mysql flexible-server create \
      --resource-group $MYSQL_RES_GRP_NAME \
      --name $MYSQL_SERVER_NAME \
      --admin-user $MYSQL_USER \
      --admin-password $MYSQL_PASSWORD \
      --sku-name Standard_B1ms \
      --public-access $PUBLIC_IP \
      --storage-size 32 \
      --version 5.7
  echo "Created MySQL Server as " $MYSQL_SERVER_NAME
  echo "Adding Firewall Rule for Azure Address"
  az mysql flexible-server firewall-rule create \
      -g $MYSQL_RES_GRP_NAME \
      -n $MYSQL_SERVER_NAME \
      -r AllowAllAzureIPs \
      --start-ip-address 0.0.0.0 
  echo "Added Firewall Rule for Azure Address"
}

#########################################################
# Create Azure Resource Group
#########################################################

echo "Creating Resource Group"
az group create --name $MYSQL_RES_GRP_NAME 
echo "Created Resource Group as " $MYSQL_RES_GRP_NAME

#########################################################
# Create MySQL on Azure Resource Group
#########################################################

if [ "$MYSQL_INSTANCE_SELECT" = "generic" ]; then 
  CreateGeneriMySQLInstance
else
  CreateFlexibleMySQLInstance
fi

#########################################################
# After setup completed, Following message will be showed
#########################################################
function yellowEcho() {
    echo -e "\033[33m$*\033[m"
}

yellowEcho "[INFO] -------------------------------------------------------"
yellowEcho "[INFO] Azure Database for MySQL Setup Completed SUCCESS"
yellowEcho "[INFO] -------------------------------------------------------"
yellowEcho  "[INFO] 1. Please copy the following value into your temporal file"
yellowEcho  "[INFO]"
yellowEcho  "[INFO] RESOURCE GROUP is $MYSQL_RES_GRP_NAME"
yellowEcho  "[INFO] MySQL HOSTNAME is" $MYSQL_SERVER_NAME'.mysql.database.azure.com'
yellowEcho  "[INFO] MySQL USERNAME is" $MYSQL_USER
yellowEcho  "[INFO] MySQL PASSWORD is $MYSQL_PASSWORD"
yellowEcho  "[INFO]"
yellowEcho  "[INFO]"
yellowEcho  "[INFO] 2. Please execute the following command."
yellowEcho  "[INFO]"
if [ "$MYSQL_INSTANCE_SELECT" = "generic" ]; then 
yellowEcho  '[INFO] mysql -u' $MYSQL_USER@$MYSQL_SERVER_NAME \
   '-h' $MYSQL_SERVER_NAME'.mysql.database.azure.com' -p '[Enter Key]'
else
yellowEcho  '[INFO] mysql -u' $MYSQL_USER \
   '-h' $MYSQL_SERVER_NAME'.mysql.database.azure.com' -p '[Enter Key]'
fi
yellowEcho "[INFO] Enter password:" $MYSQL_PASSWORD "[COPY&PASTE]"
yellowEcho  "[INFO] "
yellowEcho  "[INFO] "
yellowEcho  "[INFO] 3. Clean up Resource (Delete MySQL DB)"
yellowEcho  "[INFO] az group delete -n $MYSQL_RES_GRP_NAME"
yellowEcho  "[INFO] -------------------------------------------------------"
