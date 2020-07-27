#!/bin/sh
echo "restoring postgresql database..."
az postgres server restore --resource-group $1 --name $4  --restore-point-in-time $5 --source-server $3;
echo "adding vnet rules"
az postgres server vnet-rule create -g rg-test-i347159-devazure -s psql-test-i347159-recovery-devazure -n vnrule-test-i347159-devazure --subnet /subscriptions/7f6172c5-73bf-4f17-972a-d87da29b09c2/resourceGroups/shoot--iot-dev--devazure-st/providers/Microsoft.Network/virtualNetworks/shoot--iot-dev--devazure-st/subnets/shoot--iot-dev--devazure-st-nodes;
echo "making a call to db"
recovery_name=`PGPASSWORD=am0wo4DCrZdqnzP psql -h psql-test-i347159-recovery-devazure.postgres.database.azure.com -U iotroot@psql-test-i347159-recovery-devazure -d postgres -c "select name from "admin_users" where name = 'root'"`;
echo "deleting original instance"
az postgres server delete --resource-group $1 --name $3 --subscription $2;
sleep 500;
echo "restoring to original database..."
currenttime=`date -u +%Y-%m-%dT%H:%M:%S.000Z`;
az postgres server restore --resource-group $1 --name $3  --restore-point-in-time $currenttime --source-server $4;
echo "adding vnet rules"
az postgres server vnet-rule create -g rg-test-i347159-devazure -s psql-test-i347159-devazure -n vnrule-test-i347159-devazure --subnet /subscriptions/7f6172c5-73bf-4f17-972a-d87da29b09c2/resourceGroups/shoot--iot-dev--devazure-st/providers/Microsoft.Network/virtualNetworks/shoot--iot-dev--devazure-st/subnets/shoot--iot-dev--devazure-st-nodes;
echo "making a call to db"
name=`PGPASSWORD=am0wo4DCrZdqnzP psql -h psql-test-i347159-devazure.postgres.database.azure.com -U iotroot@psql-test-i347159-devazure -d postgres -c "select name from "admin_users" where name = 'root'"`;
echo "deleting recovery instance"
az postgres server delete --resource-group $1 --name $4 --subscription $2