#! /bin/bash

DEFAULT_REDIS_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n 1 | awk '{print $2}')
if [ -z "${REDIS_IP}" ]; then
  export "REDIS_IP=$DEFAULT_REDIS_IP"
fi

DEFAULT_REDIS_PORT=6379
if [ -z "${REDIS_PORT}" ]; then
  export "REDIS_PORT=$DEFAULT_REDIS_PORT"
fi

DEFAULT_REDIS_SHARDS=5
if [ -z "${REDIS_SHARDS}" ]; then
  export "REDIS_SHARDS=$DEFAULT_REDIS_SHARDS"
fi

REDIS_PORT_END=$((REDIS_PORT + REDIS_SHARDS*2 - 1))
REDIS_PORTS=$(shuf -i ${REDIS_PORT}-${REDIS_PORT_END})
SLOTS_NUM=16384  # 总的 slot 数量
MAX_INT=2147483647

# Wait util master slots consistent
for ((fn = 0;$fn < 9;)); do
    sleep 2
    mfn=${MAX_INT}

    IFS=$'\n' read -r -d '' -a cluster_info <<< "$(redis-cli -h "${REDIS_IP}" -p "${REDIS_PORT}" CLUSTER NODES)"
    length=${#cluster_info[@]}
    for ((i = 0; i < length; i += 1)); do
        dstip=$(echo "${cluster_info[i]}" | awk '{print $2}' | awk -F: '{print $1}')
        dstport=$(echo "${cluster_info[i]}" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')

        ms=$(redis-cli -h "$dstip" -p "$dstport" CLUSTER NODES | grep master)
        while read line; do
            array=($line)
            lms=${#array[@]}
            if [ ${lms} -lt ${mfn} ]; then
                mfn=$lms
            fi
        done <<< "$ms"
    done

    fn=$mfn
done


# load data
echo -e "\n\nLoad data >>>"
IP=${REDIS_IP} PORT=${REDIS_PORT} envsubst < ./restore.tpl > ./restore.toml
#go install github.com/alibaba/RedisShake/cmd/redis-shake@latest
redis-shake ./restore.toml
