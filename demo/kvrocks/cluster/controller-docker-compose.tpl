  kvrocks-controller-${PORT}: # 服务名称
    image: cyningsun/kvrocks-controller:0.3.1
    container_name: kvrocks-controller-${PORT} # 容器名称
    restart: always # 容器总是重新启动
    volumes: # 数据卷，目录挂载
      - ./kvrocks-cluster/kvrocks-controller-${PORT}:/var/lib/kvctl:rw
    ports:
      - "${PORT}:${PORT}"
    entrypoint: 
      kvctl-server -c /var/lib/kvctl/config.yaml
