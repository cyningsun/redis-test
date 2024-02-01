#! /bin/bash

DEFAULT_KVROCKS_PORT=6666
if [ -z "${KVROCKS_PORT}" ]; then
  export "KVROCKS_PORT=$DEFAULT_KVROCKS_PORT"
fi

DEFAULT_KVROCKS_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n 1 | awk '{print $2}')
if [ -z "${KVROCKS_IP}" ]; then
  export "KVROCKS_IP=$DEFAULT_KVROCKS_IP"
fi

echo ${KVROCKS_IP}:${KVROCKS_PORT}

# Cleanup
docker-compose down
docker-compose rm
rm -rf ./kvrocks-standalone
rm -rf ./docker-compose.yaml

# Create config
mkdir -p ./kvrocks-standalone/kvrocks-standalone-${KVROCKS_PORT} \
 && IP=${KVROCKS_IP} PORT=${KVROCKS_PORT} envsubst < ./kvrocks-standalone.tpl > ./kvrocks-standalone/kvrocks-standalone-${KVROCKS_PORT}/kvrocks.conf \
 && mkdir -p ./kvrocks-standalone/kvrocks-standalone-${KVROCKS_PORT}/data; \

# Create docker compose
 echo "version: \"3\"" > ./docker-compose.yaml
PORT=${KVROCKS_PORT} envsubst < ./docker-compose.tpl >> ./docker-compose.yaml

docker-compose up -d
