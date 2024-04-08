#! /bin/bash

DEFAULT_PIKA_PORT=6379
if [ -z "${PIKA_PORT}" ]; then
  export "PIKA_PORT=$DEFAULT_PIKA_PORT"
fi

DEFAULT_PIKA_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n 1 | awk '{print $2}')
if [ -z "${PIKA_IP}" ]; then
  export "PIKA_IP=$DEFAULT_PIKA_IP"
fi

echo ${PIKA_IP}:${PIKA_PORT}

# Cleanup
docker-compose down
docker-compose rm
rm -rf ./pika-standalone
rm -rf ./docker-compose.yaml

# Create config
mkdir -p ./pika-standalone/pika-standalone-${PIKA_PORT} \
 && IP=${PIKA_IP} PORT=${PIKA_PORT} envsubst < ./pika-standalone.tpl > ./pika-standalone/pika-standalone-${PIKA_PORT}/pika.conf \
 && mkdir -p ./pika-standalone/pika-standalone-${PIKA_PORT}/data/db \
 && mkdir -p ./pika-standalone/pika-standalone-${PIKA_PORT}/data/dbsync \
 && mkdir -p ./pika-standalone/pika-standalone-${PIKA_PORT}/data/dump \
 && mkdir -p ./pika-standalone/pika-standalone-${PIKA_PORT}/data/log \
 && chmod -R 755 ./pika-standalone/pika-standalone-${PIKA_PORT}/data

# Create docker compose
 echo "version: \"3\"" > ./docker-compose.yaml
PORT=${PIKA_PORT} envsubst < ./docker-compose.tpl >> ./docker-compose.yaml

docker-compose up -d
