port ${PORT}
cluster-announce-ip ${IP}
cluster-announce-port ${PORT}
cluster-announce-bus-port 1${PORT}
appendfilename appendonly.aof
client-output-buffer-limit slave 4294967296 4294967296 0
cluster-config-file nodes.conf
cluster-enabled yes
cluster-migration-barrier 999
cluster-node-timeout 15000
cluster-require-full-coverage no
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
loglevel verbose
maxmemory 3145728000
maxmemory-policy allkeys-lru
protected-mode no
repl-backlog-size 256000000
repl-backlog-ttl 86400
repl-diskless-sync yes
repl-timeout 300
replica-lazy-flush yes
save
slowlog-log-slower-than 100000
tcp-backlog 1024
