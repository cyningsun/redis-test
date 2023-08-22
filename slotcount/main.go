package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"sort"
	"time"

	"github.com/go-redis/redis/v8"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("args error: slotcount  ip:port")
		return
	}

	// 创建 Redis 客户端
	client := redis.NewClient(&redis.Options{
		Addr: os.Args[1], // Redis 地址
	})

	// 创建上下文
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Millisecond)
	defer cancel()

	// 调用 CLUSTER SLOTS 命令
	slots, err := client.ClusterSlots(ctx).Result()
	if err != nil {
		log.Fatal(err)
	}

	sort.Slice(slots, func(i, j int) bool {
		return slots[i].Start < slots[j].Start
	})

	// 计算每个分片的 SLOTS 数量
	fmt.Println("slot_range\tnode_id\tnode_addr\tslot_count")
	for _, slotRange := range slots {
		slotsCount := slotRange.End - slotRange.Start + 1

		fmt.Printf("%d-%d\t%s\t%s\t%d\n", slotRange.Start, slotRange.End, slotRange.Nodes[0].ID, slotRange.Nodes[0].Addr, slotsCount)
	}
}
