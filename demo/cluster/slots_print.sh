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

# 获取 Redis Cluster 节点的信息
cluster_info=$(redis-cli -h "$REDIS_IP" -p "$REDIS_PORT" CLUSTER NODES)

# 从 cluster_info 中提取 Slots 0 和 16383 的 Master 节点信息
master_nodes=$(echo "$cluster_info" | awk '{if ($3 ~ /master/) print $0}')
echo -e "\n\nMaster nodes>>>"
echo "$master_nodes" | while read line
do
    ip=$(echo "$line" | awk '{print $2}' | awk -F: '{print $1}')
    port=$(echo "$line" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')
    echo "$ip:$port >>>"
    redis-cli -h $ip -p $port CLUSTER INFO
    redis-cli -h $ip -p $port CLUSTER NODES
done

# 从 cluster_info 中提取 Slots 0 和 16383 的 Master 节点信息
echo -e "\n\nSlave nodes>>>"
slave_nodes=$(echo "$cluster_info" | awk '{if ($3 ~ /slave/) print $0}')
echo "$slave_nodes" | while read line
do
    ip=$(echo "$line" | awk '{print $2}' | awk -F: '{print $1}')
    port=$(echo "$line" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')
    echo "$ip:$port >>>"
    redis-cli -h $ip -p $port CLUSTER INFO
    redis-cli -h $ip -p $port CLUSTER NODES
    echo ""
done
