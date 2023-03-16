// Copyright 2016 CodisLabs. All Rights Reserved.
// Licensed under the MIT (MIT-LICENSE.txt) license.

package rebalance

import (
	"fmt"
	"sort"

	rbtree "github.com/emirpasic/gods/trees/redblacktree"
)

func SlotsRebalance(ctx *context) (map[int]int, map[int]int, error) {
	var groupIds []int
	for _, g := range ctx.Group {
		groupIds = append(groupIds, g.Id)
	}

	sort.Ints(groupIds)

	if len(groupIds) == 0 {
		return nil, nil, fmt.Errorf("no valid group could be found")
	}

	/* 每个 group 都拥有 3 个属性:
	 *     assigned: 当前 group 已分配的 slots 的数量
	 *     pendings: 当前 group 潜在移出的 slots 列表（仅考虑 lowerbound）。键值：group id -> [] slotid
	 *     moveout:  当前 group 实际移出/入(为负数时代表移入) slots 数（考虑 upperbound）。键值：group id -> +/- slot count
	 *
	 *     docking:   最终操作的slots的列表
	 */
	var (
		assigned = make(map[int]int)
		pendings = make(map[int][]int)
		moveout  = make(map[int]int)
		docking  []int

		// deepcopy of moveout, make plans more readable
		explains = make(map[int]int)
	)
	groupSize := func(gid int) int {
		return assigned[gid] + len(pendings[gid]) - moveout[gid]
	}

	// don't migrate slot if it's being migrated
	// 迁移中的 slot 不继续迁移。因此，优先计入已分配 slots 的数量
	for _, m := range ctx.Slots {
		if m.Action.State != ActionNothing {
			assigned[m.Action.TargetId]++
		}
	}

	// 计算每个 group 的最小 slot 数量
	lowerBound := MaxSlotNum / len(groupIds)

	// don't migrate slot if groupSize < lowerBound
	// 如果 groupSize < lowerBound，那么该 slot 不迁移。否则，加入潜在迁移列表
	for _, m := range ctx.Slots {
		if m.Action.State != ActionNothing {
			continue
		}
		if m.GroupId != 0 {
			if groupSize(m.GroupId) < lowerBound {
				assigned[m.GroupId]++
			} else {
				pendings[m.GroupId] = append(pendings[m.GroupId], m.Id)
			}
		}
	}

	// 构建红黑树，按照 groupSize 从小到大排序所有 group
	tree := rbtree.NewWith(func(x, y interface{}) int {
		gid1 := x.(int)
		gid2 := y.(int)
		if gid1 != gid2 {
			if d := groupSize(gid1) - groupSize(gid2); d != 0 {
				return d
			}
			return gid1 - gid2
		}
		return 0
	})
	for _, gid := range groupIds {
		tree.Put(gid, nil)
	}

	// assign offline slots to the smallest group
	// 将离线的 slot 分配给 groupSize 最小的 group
	for _, m := range ctx.Slots {
		if m.Action.State != ActionNothing {
			continue
		}
		if m.GroupId != 0 {
			continue
		}
		dest := tree.Left().Key.(int)
		tree.Remove(dest)

		docking = append(docking, m.Id)
		moveout[dest]--

		tree.Put(dest, nil)
	}

	// 计算每个 group 的最大 slot 数量
	upperBound := (MaxSlotNum + len(groupIds) - 1) / len(groupIds)

	// rebalance between different server groups
	// 根据 upperBound，计算每个 group 的实际迁移数量
	// 从 groupSize 最大的 group 开始，迁移 slot 到 groupSize 最小的 group
	for tree.Size() >= 2 {
		from := tree.Right().Key.(int)
		tree.Remove(from)

		// 如果该 group 的潜在迁移数量已全部迁出，那么从红黑树中移除
		if len(pendings[from]) == moveout[from] {
			continue
		}

		dest := tree.Left().Key.(int)
		tree.Remove(dest)

		// 循环退出的四种条件
		// 1. 需要迁入和迁出的 group 总数小于 2
		// 2. from group 的潜在迁移数量已全部迁出
		// 3. dest group 的潜在迁移数量已全部迁入
		// 4. from group 的潜在迁移数量与 dest group 的潜在迁移数量相差不大于 1
		var (
			fromSize = groupSize(from)
			destSize = groupSize(dest)
		)
		if fromSize <= lowerBound {
			break
		}
		if destSize >= upperBound {
			break
		}
		if d := fromSize - destSize; d <= 1 {
			break
		}

		// 增减迁入和迁出的 slot 数量
		moveout[from]++
		moveout[dest]--

		// 重新加入红黑树，继续计算直至平衡
		tree.Put(from, nil)
		tree.Put(dest, nil)
	}

	for gid, n := range moveout {
		explains[gid] = n
	}

	// 将需要迁出的 slot 加入 docking 列表，并将相关 group 从 moveout 中移除
	for gid, n := range moveout {
		if n < 0 {
			continue
		}
		if n > 0 {
			sids := pendings[gid]
			sort.Sort(sort.Reverse(sort.IntSlice(sids)))

			docking = append(docking, sids[0:n]...)
			pendings[gid] = sids[n:]
		}
		delete(moveout, gid)
	}
	sort.Ints(docking)

	plans := make(map[int]int)

	for _, gid := range groupIds {
		in := -moveout[gid]
		for i := 0; i < in && len(docking) != 0; i++ {
			plans[docking[0]] = gid
			docking = docking[1:]
		}
	}

	var slotIds []int
	for sid := range plans {
		slotIds = append(slotIds, sid)
	}
	sort.Ints(slotIds)

	for _, sid := range slotIds {
		m, err := ctx.getSlotMapping(sid)
		if err != nil {
			return nil, nil, err
		}

		m.Action.State = ActionPending
		m.Action.Index = ctx.maxSlotActionIndex() + 1
		m.Action.TargetId = plans[sid]
	}
	return plans, explains, nil
}
