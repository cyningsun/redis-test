// Copyright 2016 CodisLabs. All Rights Reserved.
// Licensed under the MIT (MIT-LICENSE.txt) license.

package rebalance

import (
	"fmt"
)

const MaxSlotNum = 1024

const (
	ActionNothing   = ""
	ActionPending   = "pending"
	ActionPreparing = "preparing"
	ActionPrepared  = "prepared"
	ActionMigrating = "migrating"
	ActionFinished  = "finished"
	ActionSyncing   = "syncing"
)

type Group struct {
	Id int `json:"id"`
}

type Slot struct {
	Id int `json:"id"`
}

type SlotMapping struct {
	Id      int `json:"id"`
	GroupId int `json:"group_id"`

	Action struct {
		Index    int    `json:"index,omitempty"`
		State    string `json:"state,omitempty"`
		TargetId int    `json:"target_id,omitempty"`
	} `json:"action"`
}

type context struct {
	Slots []*SlotMapping `json:"slots"`
	Group map[int]*Group `json:"group"`
}

func (ctx *context) getSlotMapping(sid int) (*SlotMapping, error) {
	if len(ctx.Slots) != MaxSlotNum {
		return nil, fmt.Errorf("invalid number of slots = %d/%d", len(ctx.Slots), MaxSlotNum)
	}
	if sid >= 0 && sid < MaxSlotNum {
		return ctx.Slots[sid], nil
	}
	return nil, fmt.Errorf("slot-[%d] doesn't exist", sid)
}

func (ctx *context) maxSlotActionIndex() (maxIndex int) {
	for _, m := range ctx.Slots {
		if m.Action.State != ActionNothing {
			maxIndex = MaxInt(maxIndex, m.Action.Index)
		}
	}
	return maxIndex
}

func MaxInt(a, b int) int {
	if a > b {
		return a
	} else {
		return b
	}
}
