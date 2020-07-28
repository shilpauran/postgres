#!/bin/sh
echo "preparing the file"
echo "setting account subscription for shared tenant"
if az account set --subscription $az_subscription; then 
	echo "subscription set successful"
else 
	echo "Subscription could not set successfully" && exit
fi
echo "restoring postgresql database..."
echo "az postgres server restore --resource-group $az_resource_group --name $az_recovery_server  --restore-point-in-time $az_restore_time --source-server $az_source_server"
if az postgres server restore --resource-group $az_resource_group --name $az_recovery_server  --restore-point-in-time $az_restore_time --source-server $az_source_server; then
	echo "postgresql database has restored successfully" && sleep 60
else
	echo "Error occured while restoring database" && exit
fi
echo "adding vnet rules"
if az postgres server vnet-rule create --resource-group $az_resource_group --server-name $az_recovery_server --name $az_vnetrulename --subnet /subscriptions/$az_subscription/resourceGroups/$az_shoot_resource/providers/Microsoft.Network/virtualNetworks/$az_shoot_resource/subnets/$az_subnet; then
	echo "virtualNetworks has been added successfully for recovered postgres database server" && sleep 60
else
	echo "Error occured while adding vnet rules" && exit
fi
echo "making a call to recovery db"
echo "recovery_name=`PGPASSWORD=$az_password psql -h $az_host_recovery -U $az_user_recovery -d postgres -c "select name from "admin_users" where name = 'root'"`;"
if recovery_name=`PGPASSWORD=$az_password psql -h $az_host_recovery -U $az_user_recovery -d postgres -c "select name from "admin_users" where name = 'root'"`; then
	echo "DB call successful" && sleep 60
else
	echo "DB call unsuccessful" && exit
fi
echo "deleting original instance"
if az postgres server delete --resource-group $az_resource_group --name $az_source_server --subscription $az_subscription; then
	echo "original instance has been deleted successfully" && sleep 500
else
	echo "original instance deletion failed" && exit
fi
echo "restoring to original database..."
currenttime=`date -u +%Y-%m-%dT%H:%M:%S.000Z`;
if az postgres server restore --resource-group $az_resource_group --name $az_source_server  --restore-point-in-time $currenttime --source-server $az_recovery_server;then
	echo "original database has been restored successfully" && sleep 300
else
	echo "original database deletion failed" && exit
fi
echo "adding vnet rules to restored original database"
if az postgres server vnet-rule create --resource-group $az_resource_group --server-name $az_source_server --name $az_vnetrulename --subnet /subscriptions/$az_subscription/resourceGroups/$az_shoot_resource/providers/Microsoft.Network/virtualNetworks/$az_shoot_resource/subnets/$az_subnet; then
	echo "virtualNetworks has been added successfully for original postgres database server" && sleep 60
else
	echo "Error occured while adding vnet rules for original database server" && exit
fi
echo "making a call to original db"
echo "name=`PGPASSWORD=az_password psql -h az_host -U az_user -d postgres -c "select name from "admin_users" where name = 'root'"`;"
if name=`PGPASSWORD=az_password psql -h az_host -U az_user -d postgres -c "select name from "admin_users" where name = 'root'"`; then
	echo "DB call to original server successful" && sleep 60
else
	echo "DB call to original server unsuccessfull" && exit
fi
echo "deleting recovery instance"
if az postgres server delete --resource-group $az_resource_group --name $az_recovery_server --subscription $az_subscription; then
	echo "recovered instance has been deleted successfully" && sleep 60
else
	echo "recovered instance deletion failed" && exit
fi
echo "Postgres Database Server has restored successfully"
exit