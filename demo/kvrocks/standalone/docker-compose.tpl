# 定义服务，可以多个
services:
  kvrocks-standalone-${PORT}: # 服务名称
    image: apache/kvrocks:2.7.0 # 创建容器时所需的镜像
    container_name: kvrocks-standalone-${PORT} # 容器名称
    restart: always # 容器总是重新启动
    volumes: # 数据卷，目录挂载
      - ./kvrocks-standalone/kvrocks-standalone-${PORT}:/var/lib/kvrocks:rw
      - ./kvrocks-standalone/kvrocks-standalone-${PORT}/data:/var/lib/kvrocks/db:rw
    ports:
      - ${PORT}:${PORT}
    entrypoint: 
      kvrocks -c /var/lib/kvrocks/kvrocks.conf