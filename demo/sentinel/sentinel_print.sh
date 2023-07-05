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


# Print all masters
echo -e "\n\nSENTINEL MASTER>>>"
echo "redis-cli -h ${REDIS_IP} -p ${SENTINEL_PORT} SENTINEL MASTERS"
redis-cli -h ${REDIS_IP} -p ${SENTINEL_PORT} SENTINEL MASTERS

# Print all sentinels for each master based on result of SENTINEL MASTERS
echo -e "\n\nSENTINEL SENTINELS>>>"
masters=$(redis-cli -h ${REDIS_IP} -p ${SENTINEL_PORT} --raw -d ":" SENTINEL MASTERS) 
for master in $masters; do
if [[ $master =~ ^name.* ]]; then
    master_name=$(echo $master | awk -F':' '{print $2}')
    echo "redis-cli -h ${REDIS_IP} -p ${SENTINEL_PORT} SENTINEL SENTINELS $master_name"
    redis-cli -h ${REDIS_IP} -p ${SENTINEL_PORT} SENTINEL SENTINELS $master_name
fi
done

# Print all slaves for each master based on raw result of SENTINEL MASTERS
echo -e "\n\nSENTINEL SLAVES>>>"
masters=$(redis-cli -h ${REDIS_IP} -p ${SENTINEL_PORT} --raw -d ":" SENTINEL MASTERS) 
for master in $masters; do
if [[ $master =~ ^name.* ]]; then
    master_name=$(echo $master | awk -F':' '{print $2}')
    echo "redis-cli -h ${REDIS_IP} -p ${SENTINEL_PORT} SENTINEL SLAVES $master_name"
    redis-cli -h ${REDIS_IP} -p ${SENTINEL_PORT} SENTINEL SLAVES $master_name
fi
done
