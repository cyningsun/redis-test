#! /bin/bash

unset SSH_AUTH_SOCK

DEFAULT_KVROCKS_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n 1 | awk '{print $2}')
if [ -z "${KVROCKS_IP}" ]; then
  export "KVROCKS_IP=$DEFAULT_KVROCKS_IP"
fi

DEFAULT_KVROCKS_PORT=6379
if [ -z "${KVROCKS_PORT}" ]; then
  export "KVROCKS_PORT=$DEFAULT_KVROCKS_PORT"
fi

DEFAULT_KVROCKS_SHARDS=3
if [ -z "${KVROCKS_SHARDS}" ]; then
  export "KVROCKS_SHARDS=$DEFAULT_KVROCKS_SHARDS"
fi

DEFAULT_KVROCKS_REPLICAS=2
if [ -z "${KVROCKS_REPLICAS}" ]; then
  export "KVROCKS_REPLICAS=$DEFAULT_KVROCKS_REPLICAS"
fi

DEFAULT_ETCD_CLIENT_PORT=2379
if [ -z "${ETCD_CLIENT_PORT}" ]; then
  export "ETCD_CLIENT_PORT=$DEFAULT_ETCD_CLIENT_PORT"
fi

DEFAULT_ETCD_PEER_PORT=2380
if [ -z "${ETCD_PEER_PORT}" ]; then
  export "ETCD_PEER_PORT=$DEFAULT_ETCD_PEER_PORT"
fi

DEFAULT_CONTROLLER_PORT=9379
if [ -z "${CONTROLLER_PORT}" ]; then
  export "CONTROLLER_PORT=$DEFAULT_CONTROLLER_PORT"
fi

DEFAULT_CONTROLLER_REPLICAS=3
if [ -z "${CONTROLLER_REPLICAS}" ]; then
  export "CONTROLLER_REPLICAS=$DEFAULT_CONTROLLER_REPLICAS"
fi

KVROCKS_PORT_END=$((KVROCKS_PORT + KVROCKS_SHARDS*KVROCKS_REPLICAS - 1))
KVROCKS_PORTS=$(shuf -i ${KVROCKS_PORT}-${KVROCKS_PORT_END})

CONTROLLER_PORT_END=$((CONTROLLER_PORT + CONTROLLER_REPLICAS - 1))
CONTROLLER_PORTS=$(shuf -i ${CONTROLLER_PORT}-${CONTROLLER_PORT_END})

# cleanup
docker-compose down
docker-compose rm
rm -rf ./kvrocks-cluster

# init docker-compose.yaml
echo "version: \"3\"" > ./docker-compose.yaml
echo "services:" >> ./docker-compose.yaml

# init kvrocks-etcd config
IP=${KVROCKS_IP} PEER_PORT=${ETCD_PEER_PORT} CLIENT_PORT=${ETCD_CLIENT_PORT} envsubst < ./etcd-docker-compose.tpl >> ./docker-compose.yaml

# init kvrocks-cluster config
for port in $KVROCKS_PORTS; do
  mkdir -p ./kvrocks-cluster/kvrocks-cluster-${port}/data
  IP=${KVROCKS_IP} PORT=${port} envsubst < ./kvrocks-cluster.tpl > ./kvrocks-cluster/kvrocks-cluster-${port}/kvrocks.conf

  PORT=${port} envsubst < ./kvrocks-docker-compose.tpl >> ./docker-compose.yaml
done

# init kvrocks-controller config
for port in $CONTROLLER_PORTS; do
  mkdir -p ./kvrocks-cluster/kvrocks-controller-${port}
  IP=${KVROCKS_IP} PORT=${port} ETCD_CLIENT_PORT=${ETCD_CLIENT_PORT} envsubst < ./kvrocks-controller.tpl > ./kvrocks-cluster/kvrocks-controller-${port}/config.yaml

  PORT=${port} envsubst < ./controller-docker-compose.tpl >> ./docker-compose.yaml
done

# setup
docker-compose up -d

# ping all kvrocks util they are up
echo -e "\n\nPING Kvrocks>>>"
for port in $KVROCKS_PORTS; do
  while true; do
    echo "redis-cli -h ${KVROCKS_IP} -p ${port} PING"
    if [ "$(redis-cli -h ${KVROCKS_IP} -p ${port} PING)" == "PONG" ]; then
      break
    fi
    sleep 1
  done
done

# ping all controller util they are up
echo -e "\n\nPing Controller>>>"
for port in $CONTROLLER_PORTS; do
  while true; do
    echo "redis-cli -h ${KVROCKS_IP} -p ${port} PING"
    status_code=$(curl -sL -w "%{http_code}" -o /dev/null "http://${KVROCKS_IP}:${port}/api/v1/controller/leader")
    if [ "${status_code}" == "200" ]; then
      break
    fi
    sleep 1
  done
done

# create namespace
curl -sL -d '{"namespace": "ns" }' -H "Content-Type: application/json" -X POST "http://${KVROCKS_IP}:${CONTROLLER_PORT}/api/v1/namespaces"

# create cluster
nodes=""
for port in $KVROCKS_PORTS; do
	nodes="\"${KVROCKS_IP}:${port}\",${nodes}"
done
nodes=${nodes%?}

curl -sL -d '{"name":"tc","nodes":['"$nodes"'],"replicas":'"$KVROCKS_REPLICAS"',"password":""}' -H "Content-Type: application/json" -X POST "http://${KVROCKS_IP}:${CONTROLLER_PORT}/api/v1/namespaces/ns/clusters"

# list cluster
curl -sL -X GET "http://${KVROCKS_IP}:${CONTROLLER_PORT}/api/v1/namespaces/ns/clusters/tc" | jq 