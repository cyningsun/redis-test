  redis-sentinel-${PORT}: # 服务名称
    image: redis:6.2 # 创建容器时所需的镜像
    container_name: redis-sentinel-${PORT} # 容器名称
    restart: always # 容器总是重新启动
    volumes: # 数据卷，目录挂载
      - ./redis-sentinel/redis-sentinel-${PORT}/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-sentinel/redis-sentinel-${PORT}/data:/data
    ports:
      - ${PORT}:${PORT}
    command:
      redis-server /usr/local/etc/redis/redis.conf --sentinel
