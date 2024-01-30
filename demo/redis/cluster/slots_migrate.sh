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

# 获取 Master 节点 A 和 B 的 IP 和端口
A=$(echo "$master_nodes" | grep -E ' 0-[0-9]*$')
B=$(echo "$master_nodes" | grep -E ' [0-9]*-16383$')

# 获取 Master 节点 C 和 D 的 IP 和端口
C=$(echo "$master_nodes" | grep -v -E ' 0-[0-9]*$' | grep -v -E ' [0-9]*-16383$' | awk 'NR==1')
D=$(echo "$master_nodes" | grep -v -E ' 0-[0-9]*$' | grep -v -E ' [0-9]*-16383$' | awk 'NR==2')


slot0_srcid=$(echo "$A" | awk '{print $1}')
slot0_srcip=$(echo "$A" | awk '{print $2}' | awk -F: '{print $1}')
slot0_srcport=$(echo "$A" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')

slot0_dstid=$(echo "$C" | awk '{print $1}')
slot0_dstip=$(echo "$C" | awk '{print $2}' | awk -F: '{print $1}')
slot0_dstport=$(echo "$C" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')

slot16383_srcid=$(echo "$B" | awk '{print $1}')
slot16383_srcip=$(echo "$B" | awk '{print $2}' | awk -F: '{print $1}')
slot16383_srcport=$(echo "$B" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')

slot16383_dstid=$(echo "$D" | awk '{print $1}')
slot16383_dstip=$(echo "$D" | awk '{print $2}' | awk -F: '{print $1}')
slot16383_dstport=$(echo "$D" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')


IFS=$'\n' read -r -d '' -a slaves_nodes <<< "$(echo "$cluster_info" | awk '{if ($3 ~ /slave/) print $0}' |grep -E "$slot0_srcid|$slot16383_srcid")"

num_lines=${#slaves_nodes[@]}
index=$(( RANDOM % $num_lines ))
echo $num_lines $index
E=${slaves_nodes[$index]}

echo "节点 A: $A"
echo "节点 B: $B"
echo "节点 C: $C"
echo "节点 D: $D"
echo "节点 E: $E"

slave_ip=$(echo "$E" | awk '{print $2}' | awk -F: '{print $1}')
slave_port=$(echo "$E" | awk '{print $2}' | awk -F: '{print $2}' | awk -F@ '{print $1}')

echo "slots 0 的源节点信息: $slot0_srcid $slot0_srcip $slot0_srcport"
echo "slots 0 的目标节点信息: $slot0_dstid $slot0_dstip $slot0_dstport"
echo "slots 16383 的源节点信息: $slot16383_srcid $slot16383_srcip $slot16383_srcport"
echo "slots 16383 的目标节点信息: $slot16383_dstid $slot16383_dstip $slot16383_dstport"
echo "failover node $slave_ip $slave_port"

migrate(){
    local slot=$1
    local srcip=$2
    local srcport=$3
    local srcid=$4
    local dstip=$5
    local dstport=$6
    local dstid=$7
    echo "开始迁移 Slot $slot 的 Key 从节点$srcip:$srcport 到节点 $dstip:$dstport"
    redis-cli -h $dstip -p $dstport CLUSTER SETSLOT $slot IMPORTING $srcid
    redis-cli -h $srcip -p $srcport CLUSTER SETSLOT $slot MIGRATING $dstid
    keys_in_slot=$(redis-cli -h $srcip -p $srcport CLUSTER GETKEYSINSLOT $slot 1000)
    redis-cli -h $srcip -p $srcport MIGRATE $dstip $dstport "" 0 5000 KEYS $keys_in_slot
    redis-cli -h $dstip -p $dstport CLUSTER SETSLOT $slot NODE $dstid
    redis-cli -h $srcip -p $srcport CLUSTER SETSLOT $slot NODE $dstid
}

redis-cli -h $slave_ip -p $slave_port CLUSTER NODES

echo "启动迁移"

# 并发执行 Shell 命令
migrate 16383 $slot16383_srcip $slot16383_srcport $slot16383_srcid $slot16383_dstip $slot16383_dstport $slot16383_dstid &
migrate 0 $slot0_srcip $slot0_srcport $slot0_srcid $slot0_dstip $slot0_dstport $slot0_dstid &
redis-cli -h $slave_ip -p $slave_port CLUSTER FAILOVER &
wait

echo "迁移完成"
