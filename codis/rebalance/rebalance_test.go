package rebalance

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"testing"
)

func TestRebalance(t *testing.T) {
	ctx := &context{
		Slots: make([]*SlotMapping, MaxSlotNum),
		Group: make(map[int]*Group),
	}

	GroupNum := 10
	for i := 1; i <= GroupNum; i++ {
		ctx.Group[i] = &Group{
			Id: i,
		}
	}

	for i := 0; i < MaxSlotNum; i++ {
		ctx.Slots[i] = &SlotMapping{
			Id:      i,
			GroupId: (rand.Int() % len(ctx.Group)) + 1,
		}
	}

	plans, explains, err := SlotsRebalance(ctx)
	if err != nil {
		t.Fatal(err)
	}

	// print original ctx
	fmt.Println("original:")
	for i := 1; i <= GroupNum; i++ {
		fmt.Printf("%v:", ctx.Group[i].Id)
		count := 0
		for j := 0; j < MaxSlotNum; j++ {
			if ctx.Slots[j].GroupId == ctx.Group[i].Id {
				fmt.Printf(" %v", ctx.Slots[j].Id)
				count++
			}
		}
		fmt.Printf("\ntotal:%v\n\n", count)
	}
	fmt.Println()

	// print explains (gid -> move out/in slot count)
	explainsHint, _ := json.MarshalIndent(explains, "", "  ")
	fmt.Printf("explains:%v\n", string(explainsHint))

	// print plans (target gid -> slot id)
	gids := make(map[int][]int, len(plans))
	for slot, gid := range plans {
		if gids[gid] == nil {
			gids[gid] = make([]int, 0)
		}
		gids[gid] = append(gids[gid], slot)
	}
	plansHint, _ := json.MarshalIndent(gids, "", "  ")
	fmt.Printf("plans:%v\n", string(plansHint))
}
