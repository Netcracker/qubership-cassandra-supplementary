#!/usr/bin/env bash
set -e

export CGO_ENABLED=0
# export GOPATH="/home/netcrk/go"
export GOPROXY="https://artifactorycn.netcracker.com/pd.sandbox-staging.go.group"
export GOSUMDB=off

go build -o ./bin/cassandra-services -gcflags all=-trimpath=${GOPATH} -asmflags all=-trimpath=${GOPATH} ./main.go

docker build -t cassandra-services .
for id in $DOCKER_NAMES
do
    docker tag cassandra-services $id
done

mkdir -p deployments/charts/cassandra-services

cp -R ./charts/helm/cassandra-services/* deployments/charts/cassandra-services/
cp ./charts/helm/cassandra-services/deployment-configuration.json deployments/deployment-configuration.json
