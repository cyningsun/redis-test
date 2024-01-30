# Background

In production environments, it is often found that the memory usage of different shards in Redis clusters is uneven. This is because the data distribution of Redis clusters is based on hash slot. If the hash slot is not evenly distributed, the memory usage of different shards will be likely uneven. 

# Function

This tool can be used to calculate and print the number of slots in each shard. 

# Usage

```sh
make build

./build/slotcount <ip:port>
```