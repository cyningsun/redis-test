  redis-cluster-${PORT}: # 服务名称
    image: redis:6.0
    container_name: redis-cluster-${PORT} # 容器名称
    restart: always # 容器总是重新启动
    volumes: # 数据卷，目录挂载
      - ./redis-cluster/redis-cluster-${PORT}/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-cluster/redis-cluster-${PORT}/data:/data
    ports:
      - ${PORT}:${PORT}
      - 1${PORT}:1${PORT}
    command:
      redis-server /usr/local/etc/redis/redis.conf
