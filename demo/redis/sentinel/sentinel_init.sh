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


DEFAULT_SENTINEL_PORT=26379
if [ -z "${SENTINEL_PORT}" ]; then
  export "SENTINEL_PORT=$DEFAULT_SENTINEL_PORT"
fi

DEFAULT_SENTINEL_REPLICAS=3
if [ -z "${SENTINEL_REPLICAS}" ]; then
  export "SENTINEL_REPLICAS=$DEFAULT_SENTINEL_REPLICAS"
fi

SENTINEL_PORT_END=$((SENTINEL_PORT + SENTINEL_REPLICAS - 1))
SENTINEL_PORTS=$(shuf -i ${SENTINEL_PORT}-${SENTINEL_PORT_END})

# cleanup
docker-compose down
docker-compose rm

rm -rf ./redis-standby
rm -rf ./redis-sentinel

echo "version: \"3\"" > ./docker-compose.yaml
echo "services:" >> ./docker-compose.yaml
# init redis config
for port in $REDIS_PORTS; do
  mkdir -p ./redis-standby/redis-standby-${port}
  IP=${REDIS_IP} PORT=${port} envsubst < ./redis-standby.tpl > ./redis-standby/redis-standby-${port}/redis.conf
  mkdir -p ./redis-standby/redis-standby-${port}/data

  PORT=${port} envsubst < ./docker-compose-redis.tpl >> ./docker-compose.yaml
done

# init sentinel config
for port in $SENTINEL_PORTS; do
  mkdir -p ./redis-sentinel/redis-sentinel-${port}
  IP=${REDIS_IP} PORT=${port} envsubst < ./redis-sentinel.tpl > ./redis-sentinel/redis-sentinel-${port}/redis.conf
  mkdir -p ./redis-sentinel/redis-sentinel-${port}/data

  PORT=${port} envsubst < ./docker-compose-sentinel.tpl >> ./docker-compose.yaml
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

# Ping all sentinel node util they are up
echo -e "\n\nPING Sentinel>>>"
for port in $SENTINEL_PORTS; do
  while true; do
    echo "redis-cli -h ${REDIS_IP} -p ${port} PING"
    if [ "$(redis-cli -h ${REDIS_IP} -p ${port} PING)" == "PONG" ]; then
      break
    fi
    sleep 1
  done
done

# SENTINEL MONITOR
echo -e "\n\nSENTINEL MONITOR>>>"
for port in $SENTINEL_PORTS; do
  echo "redis-cli -h ${REDIS_IP} -p ${port} SENTINEL MONITOR mymaster ${REDIS_IP} ${master_port} ${#SENTINEL_PORTS[@]}"
  redis-cli -h ${REDIS_IP} -p ${port} SENTINEL MONITOR mymaster ${REDIS_IP} ${master_port} ${#SENTINEL_PORTS[@]}
done
