#! /bin/bash

DEFAULT_KVROCKS_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n 1 | awk '{print $2}')
if [ -z "${KVROCKS_IP}" ]; then
  export "KVROCKS_IP=$DEFAULT_KVROCKS_IP"
fi

DEFAULT_KVROCKS_PORT=6379
if [ -z "${KVROCKS_PORT}" ]; then
  export "KVROCKS_PORT=$DEFAULT_KVROCKS_PORT"
fi

# load data
echo -e "\n\nLoad data >>>"
IP=${KVROCKS_IP} PORT=${KVROCKS_PORT} envsubst < ./restore.tpl > ./restore.toml
#go install github.com/alibaba/RedisShake/cmd/redis-shake@latest
redis-shake ./restore.toml
