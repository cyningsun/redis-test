port ${PORT}
replica-announce-ip ${IP}
replica-announce-port ${PORT}
appendfilename appendonly.aof
client-output-buffer-limit slave 4294967296 4294967296 0
cluster-enabled no
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
loglevel debug
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
