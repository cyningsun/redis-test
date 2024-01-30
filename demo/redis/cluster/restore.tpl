type = "restore"

[source]
rdb_file_path = "./dump.rdb"

[target]
type = "cluster"
address = "${IP}:${PORT}" # 这里写集群中的任意一个节点的地址即可
