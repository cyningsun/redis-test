package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/go-redis/redis/v8"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("args error: slotcount  ip:port")
		return
	}

	// create Redis client
	client := redis.NewClient(&redis.Options{
		Addr: os.Args[1], // Redis 地址
	})

	// init context
	ctx, cancel := context.WithTimeout(context.Background(), 3000*time.Millisecond)
	defer cancel()

	// get slots info from CLUSTER SLOTS
	slots, err := client.ClusterSlots(ctx).Result()
	if err != nil {
		log.Fatal(err)
	}

	// group by node id
	nodeSlotsMap := make(map[string][]redis.ClusterSlot)
	for _, slot := range slots {
		nodeSlotsMap[slot.Nodes[0].ID] = append(nodeSlotsMap[slot.Nodes[0].ID], slot)
	}

	// nodeSlots map to slice
	nodeSlots := make([][]redis.ClusterSlot, 0, len(nodeSlotsMap))
	for _, slots := range nodeSlotsMap {
		nodeSlots = append(nodeSlots, slots)
	}

	// sort  slots by slot range in node
	for _, slots := range nodeSlots {
		sort.Slice(slots, func(i, j int) bool {
			return slots[i].Start < slots[j].Start
		})
	}

	// sort node by slot range in node
	sort.Slice(nodeSlots, func(i, j int) bool {
		return nodeSlots[i][0].Start < nodeSlots[j][0].Start
	})

	// calculate slot count by node id
	fmt.Println("node_id\tnode_addr\tslot_count\tslot_range")
	for _, slots := range nodeSlots {
		var slotCount int
		slotRanges := make([]string, 0, len(slots))
		for _, slot := range slots {
			slotCount += int(slot.End - slot.Start + 1)
			slotRanges = append(slotRanges, fmt.Sprintf("[%d-%d]", slot.Start, slot.End))
		}

		fmt.Printf("%s\t%s\t%d\t%s\n", slots[0].Nodes[0].ID, slots[0].Nodes[0].Addr, slotCount, strings.Join(slotRanges, " "))
	}
}
