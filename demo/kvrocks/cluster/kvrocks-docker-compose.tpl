  kvrocks-cluster-${PORT}: # 服务名称
    image: apache/kvrocks:2.7.0
    container_name: kvrocks-cluster-${PORT} # 容器名称
    restart: always # 容器总是重新启动
    volumes: # 数据卷，目录挂载
      - ./kvrocks-cluster/kvrocks-cluster-${PORT}:/var/lib/kvrocks:rw
      - ./kvrocks-cluster/kvrocks-cluster-${PORT}/data:/var/lib/kvrocks/db:rw
    ports:
      - "${PORT}:${PORT}"
    entrypoint: 
      kvrocks -c /var/lib/kvrocks/kvrocks.conf
