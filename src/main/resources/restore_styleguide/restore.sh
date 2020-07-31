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
echo "preparing the environment"
# TODO: Check for a way to pass the path of the file with arguments
source env.sh "$1" "$2" "$3" "$4" "$5"
echo "environment set up complete"

# 2. add az login information to shared tenant
echo "setting account subscription for shared tenant"
if az account set --subscription "$az_subscription"; then 
	echo " subscription set successful"
else 
	err " Subscription could not set successfully" && exit
fi

# 3. restore postgres database server
echo "restoring postgresql database..."
echo "az postgres server restore --resource-group $az_resource_group --name $az_recovery_server  --restore-point-in-time $az_restore_time --source-server $az_source_server"
if az postgres server restore --resource-group "$az_resource_group" --name "$az_recovery_server"  --restore-point-in-time "$az_restore_time" --source-server "$az_source_server"; then
	echo " postgresql database has restored successfully" && sleep 60
else
	err " Error occured while restoring database" && exit
fi

# 4. add virtual network rules to the restored database server
echo "adding vnet rules"
if az postgres server vnet-rule create --resource-group "$az_resource_group" --server-name "$az_recovery_server" --name "$az_vnetrulename" --subnet /subscriptions/"$az_subscription"/resourceGroups/"$az_shoot_resource"/providers/Microsoft.Network/virtualNetworks/"$az_shoot_resource"/subnets/"$az_subnet"; then
	echo " virtualNetworks has been added successfully for recovered postgres database server" && sleep 60
else
	err " Error occured while adding vnet rules" && exit
fi

# 5. test connection to the restored server 
echo "making a call to recovery db"
query1="psql -h $az_host_recovery -U $az_user_recovery -d postgres -c "select name from "admin_users" where name = 'root'""
if recovery_name=$(PGPASSWORD=$az_password $query1); then
	echo " DB call successful" && sleep 60
else
	err " DB call unsuccessful" && exit
fi

# 6. delete the original database server
echo "deleting original instance"
if az postgres server delete -y --resource-group "$az_resource_group" --name "$az_source_server" --subscription "$az_subscription"; then
	echo " original instance has been deleted successfully" && sleep 500
else
	err " original instance deletion failed" && exit
fi

# 7. restored to original database server from the recovered server
echo "restoring to original database..."
currenttime=$(date -u +%Y-%m-%dT%H:%M:%S.000Z);
if az postgres server restore --resource-group "$az_resource_group" --name "$az_source_server"  --restore-point-in-time "$currenttime" --source-server "$az_recovery_server";then
	echo " original database has been restored successfully" && sleep 300
else
	err " original database deletion failed" && exit
fi

# 8. add virtual network rule to the original database server
echo "adding vnet rules to restored original database"
if az postgres server vnet-rule create --resource-group "$az_resource_group" --server-name "$az_source_server" --name "$az_vnetrulename" --subnet /subscriptions/"$az_subscription"/resourceGroups/"$az_shoot_resource"/providers/Microsoft.Network/virtualNetworks/"$az_shoot_resource"/subnets/"$az_subnet"; then
	echo " virtualNetworks has been added successfully for original postgres database server" && sleep 60
else
	err " Error occured while adding vnet rules for original database server" && exit
fi

# 9. test connection to the original database server 
echo "making a call to original db"
query2="psql -h $az_host -U $az_user -d postgres -c "select name from "admin_users" where name = 'root'""
if name=$(PGPASSWORD=$az_password $query2); then
	echo " DB call to original server successful" && sleep 60
else
	err " DB call to original server unsuccessfull" && exit
fi

# 10. delete the recovered database server which was used to restored original server
echo "deleting recovery instance"
if az postgres server delete -y --resource-group "$az_resource_group" --name "$az_recovery_server" --subscription "$az_subscription"; then
	echo " recovered instance has been deleted successfully" && sleep 60
else
	err " recovered instance deletion failed" && exit
fi

echo "Postgres Database Server has restored successfully"

exit