
# 定义服务，可以多个
services:
  redis-standalone-${PORT}: # 服务名称
    image: redis:6.2 # 创建容器时所需的镜像
    container_name: redis-standalone-${PORT} # 容器名称
    restart: always # 容器总是重新启动
    volumes: # 数据卷，目录挂载
      - ./redis-standalone/redis-standalone-${PORT}/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis-standalone/redis-standalone-${PORT}/data:/data
    ports:
      - ${PORT}:${PORT}
    command:
      redis-server /usr/local/etc/redis/redis.conf
