#!/bin/sh
echo "restoring postgresql database..."
az postgres server restore --resource-group $1 --name $4  --restore-point-in-time $5 --source-server $3;
sleep 300;
echo "adding vnet rules"
az postgres server vnet-rule create -g rg-test2-saumya-postgres-devazure -s psql-test2-saumya-postgres-recovery-devazure -n vnrule-test2-saumya-postgres-devazure --subnet /subscriptions/7f6172c5-73bf-4f17-972a-d87da29b09c2/resourceGroups/shoot--iot-dev--devazure-st/providers/Microsoft.Network/virtualNetworks/shoot--iot-dev--devazure-st/subnets/shoot--iot-dev--devazure-st-nodes;
sleep 200;
echo "making a call to db"
recovery_name=`PGPASSWORD=KCBzylS7tcegomK psql -h psql-test2-saumya-postgres-recovery-devazure.postgres.database.azure.com -U iotroot@psql-test2-saumya-postgres-recovery-devazure -d postgres -c "select name from "admin_users" where name = 'root'"`;
echo "deleting original instance"
az postgres server delete --resource-group $1 --name $3 --subscription $2;
sleep 500;
echo "restoring to original database..."
currenttime=`date -u +%Y-%m-%dT%H:%M:%S.000Z`;
az postgres server restore --resource-group $1 --name $3  --restore-point-in-time $currenttime --source-server $4;
sleep 300;
echo "adding vnet rules"
az postgres server vnet-rule create -g rg-test2-saumya-postgres-devazure -s psql-test2-saumya-postgres-devazure -n vnrule-test2-saumya-postgres-devazure --subnet /subscriptions/7f6172c5-73bf-4f17-972a-d87da29b09c2/resourceGroups/shoot--iot-dev--devazure-st/providers/Microsoft.Network/virtualNetworks/shoot--iot-dev--devazure-st/subnets/shoot--iot-dev--devazure-st-nodes;
sleep 200;
echo "making a call to db"
name=`PGPASSWORD=KCBzylS7tcegomK psql -h psql-test2-saumya-postgres-devazure.postgres.database.azure.com -U iotroot@psql-test2-saumya-postgres-devazure -d postgres -c "select name from "admin_users" where name = 'root'"`;
echo "deleting recovery instance"
az postgres server delete --resource-group $1 --name $4 --subscription $2