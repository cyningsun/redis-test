#! /bin/bash

DEFAULT_REDIS_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n 1 | awk '{print $2}')
if [ -z "${REDIS_IP}" ]; then
  export "REDIS_IP=$DEFAULT_REDIS_IP"
fi

DEFAULT_REDIS_PORT=6379
if [ -z "${REDIS_PORT}" ]; then
  export "REDIS_PORT=$DEFAULT_REDIS_PORT"
fi

DEFAULT_REDIS_REPLICAS=2
if [ -z "${REDIS_REPLICAS}" ]; then
  export "REDIS_REPLICAS=$DEFAULT_REDIS_REPLICAS"
fi

REDIS_PORT_END=$((REDIS_PORT + REDIS_REPLICAS - 1))
REDIS_PORTS=$(shuf -i ${REDIS_PORT}-${REDIS_PORT_END})

# cleanup
docker-compose down
docker-compose rm

rm -rf ./redis-standby

echo "version: \"3\"" > ./docker-compose.yaml
echo "services:" >> ./docker-compose.yaml
# init redis config
for port in $REDIS_PORTS; do
  mkdir -p ./redis-standby/redis-standby-${port}
  IP=${REDIS_IP} PORT=${port} envsubst < ./redis-standby.tpl > ./redis-standby/redis-standby-${port}/redis.conf
  mkdir -p ./redis-standby/redis-standby-${port}/data

  PORT=${port} envsubst < ./docker-compose.tpl >> ./docker-compose.yaml
done

# Setup
docker-compose up -d

# Ping all redis nodes util they are up
echo -e "\n\nPING Redis>>>"
for port in $REDIS_PORTS; do
  while true; do
    echo "redis-cli -h ${REDIS_IP} -p ${port} PING"
    if [ "$(redis-cli -h ${REDIS_IP} -p ${port} PING)" == "PONG" ]; then
      break
    fi
    sleep 1
  done
done

# REPLICAOF, chose a master and replicate others to it
echo -e "\n\nREPLICAOF>>>"
master_port=$(shuf -i ${REDIS_PORT}-${REDIS_PORT_END} -n 1)
for port in $REDIS_PORTS; do
  if [ "$port" != "$master_port" ]; then
    echo "redis-cli -h ${REDIS_IP} -p ${port} REPLICAOF ${REDIS_IP} ${master_port}"
    redis-cli -h ${REDIS_IP} -p ${port} REPLICAOF ${REDIS_IP} ${master_port}
  fi
done
