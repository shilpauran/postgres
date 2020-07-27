#!/bin/sh
echo "restoring postgresql database..."
az deployment group create --rollback-on-error --resource-group $1 --mode $2 --subscription $3 --template-file template.json --parameters @otr.json;
echo "checking connection with the restored postgres database"
psql --host=$5 --port=5432 --username=$6 --dbname=postgres -c "\dt";
echo "deleting original instance"
az postgres server delete --resource-group $1 --name $4 --subscription $3;
echo "restoring to original database..."
az deployment group create --rollback-on-error --resource-group $1 --mode $2 --subscription $3 --name "postgres-deploy-rto" --template-file template.json --parameters @rto.json;
echo "checking connection with original restored database instance"
psql --host=$7 --port=5432 --username=$8 --dbname=postgres;
echo "deleting recovery instance"
az postgres server delete --resource-group $1 --name $5 --subscription $3