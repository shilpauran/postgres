#!/bin/sh
echo "setting account subscription for shared tenant"
if az account set --subscription $2; then 
	echo "subscription set successful"
else 
	echo "Subscription could not set successfully" && exit
fi
echo "restoring postgresql database..."
if az postgres server restore --resource-group $1 --name $4  --restore-point-in-time $5 --source-server $3; then
	echo "postgresql database has restored successfully" && sleep 60
else
	echo "Error occured while restoring database" && exit
fi
echo "adding vnet rules"
if az postgres server vnet-rule create --resource-group $1 --server-name $4 --name vnrule-test2-saumya-postgres-devazure --subnet /subscriptions/7f6172c5-73bf-4f17-972a-d87da29b09c2/resourceGroups/shoot--iot-dev--devazure-st/providers/Microsoft.Network/virtualNetworks/shoot--iot-dev--devazure-st/subnets/shoot--iot-dev--devazure-st-nodes; then
	echo "virtualNetworks has been added successfully for recovered postgres database server" && sleep 60
else
	echo "Error occured while adding vnet rules" && exit
fi
echo "making a call to recovery db"
if recovery_name=`PGPASSWORD=KCBzylS7tcegomK psql -h psql-test2-saumya-postgres-recovery-devazure.postgres.database.azure.com -U iotroot@psql-test2-saumya-postgres-recovery-devazure -d postgres -c "select name from "admin_users" where name = 'root'"`; then
	echo "DB call successful" && sleep 100
else
	echo "DB call unsuccessfull" && exit
fi
echo "deleting original instance"
if az postgres server delete --resource-group $1 --name $3 --subscription $2; then
	echo "original instance has been deleted successfully" && sleep 500
else
	echo "original instance deletion failed" && exit
fi
echo "restoring to original database..."
currenttime=`date -u +%Y-%m-%dT%H:%M:%S.000Z`;
if az postgres server restore --resource-group $1 --name $3  --restore-point-in-time $currenttime --source-server $4;then
	echo "original database has been restored successfully" && sleep 300
else
	echo "original database deletion failed" && exit
fi
echo "adding vnet rules to restored original database"
if az postgres server vnet-rule create --resource-group $1 --server-name $3 --name vnrule-test2-saumya-postgres-devazure --subnet /subscriptions/7f6172c5-73bf-4f17-972a-d87da29b09c2/resourceGroups/shoot--iot-dev--devazure-st/providers/Microsoft.Network/virtualNetworks/shoot--iot-dev--devazure-st/subnets/shoot--iot-dev--devazure-st-nodes; then
	echo "virtualNetworks has been added successfully for original postgres database server" && sleep 200
else
	echo "Error occured while adding vnet rules for original database server" && exit
fi
echo "making a call to original db"
if name=`PGPASSWORD=KCBzylS7tcegomK psql -h psql-test2-saumya-postgres-devazure.postgres.database.azure.com -U iotroot@psql-test2-saumya-postgres-devazure -d postgres -c "select name from "admin_users" where name = 'root'"`; then
	echo "DB call to original server successful" && sleep 100
else
	echo "DB call to original server unsuccessfull" && exit
fi
echo "deleting recovery instance"
if az postgres server delete --resource-group $1 --name $4 --subscription $2; then
	echo "recovered instance has been deleted successfully" && sleep 500
else
	echo "recovered instance deletion failed" && exit
fi
echo "Postgres Database Server has restored successfully"
exit
