#!/bin/bash
#
# Perform restore of Postgres database Server.

#######################################
# Logs Error in case of failure.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes Error details
#######################################
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

# 1. prepare the environment
echo "setting environment"
az_instance="$1"
az_landscape="$2"
az_user="$3"

az_password="$4"

az_ins_land="${az_instance}-${az_landscape}"
az_ins_recovery_land="${az_instance}-recovery-${az_landscape}"

export az_resource_group="rg-${az_ins_land}"
echo "resource group is $az_resource_group"

export az_source_server="psql-${az_ins_land}"
echo "source server is $az_source_server"

export az_recovery_server="psql-${az_ins_recovery_land}"
echo "recovery server is $az_recovery_server"

export az_restore_time="$5"
echo "restore point in time is $az_restore_time"

if [ $az_landscape == "devazure" ]; then
  export az_subscription="7f6172c5-73bf-4f17-972a-d87da29b09c2"
  echo " subscription is $az_subscription"
  export az_shoot_resource="shoot--iot-dev--devazure-st"
  echo " shoot resource is $az_shoot_resource"
  export az_subnet="shoot--iot-dev--devazure-st-nodes"
  echo " subnet is $az_subnet"
else
  echo " no subscription found"
fi

export az_vnetrulename="vnrule-${az_ins_land}"
echo "vnetrule name is $az_vnetrulename"

export az_host="${az_source_server}.postgres.database.azure.com"
echo "host is $az_host"

export az_host_recovery="${az_recovery_server}.postgres.database.azure.com"
echo "recovery host is $az_host_recovery"

export az_user_recovery="iotroot@psql-${az_ins_recovery_land}"
echo "recovery user is $az_user_recovery"

export credentials_encryption_key="KQzV-bVlu80j@6KT8?Sz8h1"
echo "credentials_encryption_key set"

echo "environment set up complete"

# 2. add az login information to shared tenant
#create service principle
if [[-f credentials.yml]];then
	echo "credentials.yml exists- not creating this file"
elif [[-f credentials.yml.enc]];then
	echo "credentails.yml does not exists, encrypted file present,decrypting"
	chmod +x decrypt_credentials.sh
	echo $credentials_encryption_key > decrypt_password_in
	decrypt_credentials.sh
	if [[ -f decrypt_password_in ]]; then
		rm decrypt_password_in
	fi
	if [[ ! -f credentials.yml ]]; then
        echo "Decryption unsuccessful, aborting"
        exit 1
    fi
	echo "Decryption done"
else
	echo "encrypt key not found"
fi
echo "setting account subscription for shared tenant"
if az account set --subscription "$az_subscription"; then 
	echo " subscription set successful"
else 
	err " Subscription could not set successfully" && exit
fi

#3 check if source server exists. if not terminate the script
echo "checking if source server exists"
if az postgres server show --name "$az_source_server" --resource-group "$az_resource_group"; then
	echo " source server exists"
else
	err " source server does not exist" && exit
fi

#4 check if recovery server exists. If yes delete it
echo "checking for recovery db details"
if az postgres server show --name "$az_recovery_server" --resource-group "$az_resource_group"; then
	if az postgres server delete --resource-group "$az_resource_group" --name "$az_recovery_server"; then
		echo " recovery database deletion successful" && sleep 500
	else
		err " unable to delete the existing recovery server" && exit
	fi
else
	echo " recovery database check complete"
fi

#5 check if virtual network and subnet exists or not. if not terminate the script
echo "checking for subnet and virtual network"
if az network vnet subnet show -g "$az_shoot_resource" --vnet-name "$az_shoot_resource" -n "$az_subnet"; then
	echo " subnet and virtual network exists"
else
	err " required subnet or virtual network to access the resource does not exist" && exit
fi


# 6. restore postgres database server
echo "restoring postgresql database..."
if az postgres server restore --resource-group "$az_resource_group" --name "$az_recovery_server"  --restore-point-in-time "$az_restore_time" --source-server "$az_source_server"; then
	echo " postgresql database has restored successfully" && sleep 60
else
	err " Error occured while restoring database" && exit
fi

# 7. add virtual network rules to the restored database server
echo "adding vnet rules"
if az postgres server vnet-rule create --resource-group "$az_resource_group" --server-name "$az_recovery_server" --name "$az_vnetrulename" --subnet /subscriptions/"$az_subscription"/resourceGroups/"$az_shoot_resource"/providers/Microsoft.Network/virtualNetworks/"$az_shoot_resource"/subnets/"$az_subnet"; then
	echo " virtualNetworks has been added successfully for recovered postgres database server" && sleep 60
else
	err " Error occured while adding vnet rules" && exit
fi

# 8. test connection to the restored server 
echo "making a call to recovery db"
query1="psql -h $az_host_recovery -U $az_user_recovery -d postgres -c "select name from "admin_users" where name = 'root'""
if recovery_name=$(PGPASSWORD=$az_password $query1); then
	echo " DB call successful" && sleep 60
else
	err " DB call unsuccessful" && exit
fi

# 9. delete the original database server
echo "deleting original instance"
if az postgres server delete -y --resource-group "$az_resource_group" --name "$az_source_server" --subscription "$az_subscription"; then
	echo " original instance has been deleted successfully" && sleep 500
else
	err " original instance deletion failed" && exit
fi

# 10. restored to original database server from the recovered server
echo "restoring to original database..."
currenttime=$(date -u +%Y-%m-%dT%H:%M:%S.000Z);
if az postgres server restore --resource-group "$az_resource_group" --name "$az_source_server"  --restore-point-in-time "$currenttime" --source-server "$az_recovery_server";then
	echo " original database has been restored successfully" && sleep 300
else
	err " original database deletion failed" && exit
fi

# 11. add virtual network rule to the original database server
echo "adding vnet rules to restored original database"
if az postgres server vnet-rule create --resource-group "$az_resource_group" --server-name "$az_source_server" --name "$az_vnetrulename" --subnet /subscriptions/"$az_subscription"/resourceGroups/"$az_shoot_resource"/providers/Microsoft.Network/virtualNetworks/"$az_shoot_resource"/subnets/"$az_subnet"; then
	echo " virtualNetworks has been added successfully for original postgres database server" && sleep 60
else
	err " Error occured while adding vnet rules for original database server" && exit
fi

# 12. test connection to the original database server 
echo "making a call to original db"
query2="psql -h $az_host -U $az_user -d postgres -c "select name from "admin_users" where name = 'root'""
if name=$(PGPASSWORD=$az_password $query2); then
	echo " DB call to original server successful" && sleep 60
else
	err " DB call to original server unsuccessfull" && exit
fi

# 13. delete the recovered database server which was used to restored original server
echo "deleting recovery instance"
if az postgres server delete -y --resource-group "$az_resource_group" --name "$az_recovery_server" --subscription "$az_subscription"; then
	echo " recovered instance has been deleted successfully"
else
	err " recovered instance deletion failed" && exit
fi

echo "Postgres Database Server has restored successfully"

exit