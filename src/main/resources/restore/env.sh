#!/bin/sh
echo "setting environment"
az_instance=$1
az_landscape=$2
az_user=$3
echo "user name is $az_user"
az_password=$4
echo "password is $az_password"
az_ins_land="${1}-${2}"
az_ins_recovery_land="${1}-recovery-${2}"
export az_resource_group="rg-${az_ins_land}"
echo "resource group is $az_resource_group"
export az_source_server="psql-${az_ins_land}"
echo "source server is $az_source_server"
export az_recovery_server="psql-${az_ins_recovery_land}"
echo "recovery server is $az_recovery_server"
export az_restore_time=$5
echo "restore point in time is $az_restore_time"
if [ $az_landscape == "devazure" ]; then
export az_subscription="7f6172c5-73bf-4f17-972a-d87da29b09c2"
echo "subscription is $az_subscription"
export az_shoot_resource="shoot--iot-dev--devazure-st"
echo "shoot resource is $az_shoot_resource"
export az_subnet="shoot--iot-dev--devazure-st-nodes"
echo "subnet is $az_subnet"
else
echo "no subscription found"
fi
export az_vnetrulename="vnrule-${az_ins_land}"
echo "vnetrule name is $az_vnetrulename"
export az_host="${az_source_server}.postgres.database.azure.com"
echo "host is $az_host"
export az_host_recovery="${az_recovery_server}.postgres.database.azure.com"
echo "recovery host is $az_host_recovery"
export az_user_recovery="iotroot@psql-${az_ins_recovery_land}"
echo "recovery user is $az_user_recovery"
export az_query_recovery="psql -h $az_host_recovery -U $az_user_recovery -d postgres -c "select name from "admin_users" where name = 'root'""
echo " query to recovery db is $az_query_recovery"
export az_query="psql -h $az_host -U $az_user -d postgres -c "select name from "admin_users" where name = 'root'""
echo "query to original db is $az_query"
