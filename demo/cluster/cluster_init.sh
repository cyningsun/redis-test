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

# cleanup
docker-compose down
docker-compose rm
rm -rf ./redis-cluster

# init redis config
echo "version: \"3\"" > ./docker-compose.yaml
echo "services:" >> ./docker-compose.yaml
for port in $REDIS_PORTS; do
  mkdir -p ./redis-cluster/redis-cluster-${port}
  IP=${REDIS_IP} PORT=${port} envsubst < ./redis-cluster.tpl > ./redis-cluster/redis-cluster-${port}/redis.conf
  mkdir -p ./redis-cluster/redis-cluster-${port}/data

  PORT=${port} envsubst < ./docker-compose.tpl >> ./docker-compose.yaml
done

# setup
docker-compose up -d


# CLUSTER MEET
echo -e "\n\nCLUSTER MEET>>>"
for sport in ${REDIS_PORTS}; do
   for dport in ${REDIS_PORTS}; do
       if [ "$sport" != "$dport" ]; then
          echo "${REDIS_IP}:${sport} CLUSTER MEET ${REDIS_IP}:${dport}"
          redis-cli -h ${REDIS_IP} -p ${sport} CLUSTER MEET ${REDIS_IP} ${dport}
       fi
   done
done

# Wait util nodes meet expectation
for ((tn=0; $tn != 2*$REDIS_SHARDS;)); do
    sleep 2
    IFS=$'\n' read -r -d '' -a ns <<< "$(redis-cli -h "$REDIS_IP" -p "$REDIS_PORT" CLUSTER NODES)"
    tn=${#ns[@]}
done

# CLUSTER REPLICATE
echo -e "\n\nCLUSTER REPLICATE>>>"
IFS=$'\n' read -r -d '' -a cluster_info <<< "$(redis-cli -h "${REDIS_IP}" -p "${REDIS_PORT}" CLUSTER NODES)"
length=${#cluster_info[@]}
for ((i = 0; i < length; i += 2)); do
    srcip=$(echo "${cluster_info[i]}" | awk '{print $2}' | awk -F: '{print $1}')
    srcport=$(echo "${cluster_info[i]}" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')
    srcid=$(echo "${cluster_info[i]}" | awk '{print $1}')
    dstip=$(echo "${cluster_info[i+1]}" | awk '{print $2}' | awk -F: '{print $1}')
    dstport=$(echo "${cluster_info[i+1]}" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')
    echo "${dstip}:${dstport} CLUSTER REPLICATE ${srcip}:${srcport}"
    redis-cli -h ${dstip} -p ${dstport} CLUSTER REPLICATE $srcid
done

# Wait util master-slave meet expectation
for ((tm=0; $tm != $REDIS_SHARDS;)); do
    sleep 2
    IFS=$'\n' read -r -d '' -a ms <<< "$(redis-cli -h "$REDIS_IP" -p "$REDIS_PORT" CLUSTER NODES | grep master)"
    tm=${#ms[@]}
done

# CLUSTER ADDSLOTS
echo -e "\n\nCLUSTER ADDSLOTS>>>"
IFS=$'\n' read -r -d '' -a master_info <<< "$(redis-cli -h "$REDIS_IP" -p "$REDIS_PORT" CLUSTER NODES | grep master)"
slots_per_master=$((SLOTS_NUM / REDIS_SHARDS))  # 每个主节点的 slot 数量
remainder=$((SLOTS_NUM % REDIS_SHARDS))

# 初始化起始 slot 值
start_slot=0

# 设置每个主节点的 slot 范围
for ((i = 0; i < REDIS_SHARDS; i++)); do
    # 计算当前主节点的 slot 数量
    slots_count=$((slots_per_master + (i < remainder ? 1 : 0)))

    # 计算结束 slot 值
    end_slot=$((start_slot + slots_count - 1))

    dstip=$(echo "${master_info[i]}" | awk '{print $2}' | awk -F: '{print $1}')
    dstport=$(echo "${master_info[i]}" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')
    echo "$dstip:$dstport CLUSTER ADDSLOTS $start_slot-$end_slot"
    redis-cli -h $dstip -p $dstport CLUSTER ADDSLOTS $(seq $start_slot $end_slot)

    # 更新起始 slot 值
    start_slot=$((end_slot + 1))
done
