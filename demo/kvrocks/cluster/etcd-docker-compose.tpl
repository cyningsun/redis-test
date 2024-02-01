  etcd:
    image: "quay.io/coreos/etcd:v3.4.30-arm64"
    container_name: etcd
    ports:
      - "${PEER_PORT}:${PEER_PORT}"
      - "${CLIENT_PORT}:${CLIENT_PORT}"
    platform: linux/arm64/v8
    environment:
      - ALLOW_NONE_AUTHENTICATION=yes
      - ETCD_NAME=etcd
      - ETCD_LISTEN_PEER_URLS=http://0.0.0.0:${PEER_PORT}
      - ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:${CLIENT_PORT}
      - ETCD_ADVERTISE_CLIENT_URLS=http://127.0.0.1:${CLIENT_PORT}
      - ETCD_INITIAL_ADVERTISE_PEER_URLS=http://etcd:${PEER_PORT}
      - ETCD_INITIAL_CLUSTER_TOKEN=etcd-cluster
      - ETCD_INITIAL_CLUSTER=etcd=http://etcd:${PEER_PORT}
      - ETCD_INITIAL_CLUSTER_STATE=new
      - ETCD_UNSUPPORTED_ARCH=arm64
