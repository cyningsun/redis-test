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

# 创建一个临时文件来保存写入命令
temp_file=$(mktemp)

# 生成写入命令并保存到临时文件
for ((i=1; i<=163840; i++))
do
    echo "SET key$i value$i" >> "$temp_file"
done

# 使用Redis-cli的pipeline模式执行写入命令
cat "$temp_file" | redis-cli -c -h "$REDIS_HOST" -p "$REDIS_PORT" --pipe

# 删除临时文件
rm "$temp_file"

