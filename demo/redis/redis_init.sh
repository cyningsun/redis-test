#! /bin/bash

DEFAULT_REDIS_PORT=6379
if [ -z "${REDIS_PORT}" ]; then
  export "REDIS_PORT=$DEFAULT_REDIS_PORT"
fi

DEFAULT_REDIS_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n 1 | awk '{print $2}')
if [ -z "${REDIS_IP}" ]; then
  export "REDIS_IP=$DEFAULT_REDIS_IP"
fi

echo ${REDIS_IP}:${REDIS_PORT}

# Cleanup
docker-compose down
docker-compose rm
rm -rf ./redis-standalone
rm -rf ./docker-compose.yaml

# Create config
mkdir -p ./redis-standalone/redis-standalone-${REDIS_PORT} \
 && IP=${REDIS_IP} PORT=${REDIS_PORT} envsubst < ./redis-standalone.tpl > ./redis-standalone/redis-standalone-${REDIS_PORT}/redis.conf \
 && mkdir -p ./redis-standalone/redis-standalone-${REDIS_PORT}/data; \

# Create docker compose
 echo "version: \"3\"" > ./docker-compose.yaml
PORT=${REDIS_PORT} envsubst < ./docker-compose.tpl >> ./docker-compose.yaml

docker-compose up -d
