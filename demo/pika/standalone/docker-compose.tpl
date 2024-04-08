
# 定义服务，可以多个
services:
  pika-standalone-${PORT}: # 服务名称
    image: pikadb/pika:latest # 创建容器时所需的镜像
    container_name: pika-standalone-${PORT} # 容器名称
    restart: always # 容器总是重新启动
    volumes: # 数据卷，目录挂载
      - ./pika-standalone/pika-standalone-${PORT}/data/log:/pika/log
      - ./pika-standalone/pika-standalone-${PORT}/data/db:/pika/db
      - ./pika-standalone/pika-standalone-${PORT}/data/dump:/pika/dump
      - ./pika-standalone/pika-standalone-${PORT}/data/dbsync:/pika/dbsync
      - ./pika-standalone/pika-standalone-${PORT}/pika.conf:/pika/conf/pika.conf
    ports:
      - ${PORT}:${PORT}