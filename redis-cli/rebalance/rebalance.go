package rebalance

import (
	"log"
	"math"
	"sort"
)

func Rebalance(nodes LinkList[ClusterNode], opt Option) (new LinkList[ClusterNode]) {
	involved := NewLinkList[ClusterNode]()
	iter := nodes.Iterator()
	totalWeight := float64(0)
	nodesInvolved := 0
	// Compuate total cluster weight and nodes involved
	for iter.Next() {
		n := iter.Value()
		if (n.Flags&FLAG_SLAVE) > 0 || n.Replicate != "" {
			continue
		}

		if n.Weight == 0 {
			continue
		}

		totalWeight += n.Weight
		nodesInvolved++
		involved.PushBack(n)
	}

	weightedNodes := make([]ClusterNode, 0, nodesInvolved)
	/* Calculate the slots balance for each node. It's the number of
	 * slots the node should lose(if positive) or gain(if negative)
	 * in order to be balanced.
	 */
	thresholdReached := false
	totalBalance := 0
	threshold := opt.Threshold
	iter = involved.Iterator()
	for iter.Next() {
		n := iter.Value()
		weightedNodes = append(weightedNodes, n)
		expected := int((CLUSTER_SLOTS_NUMBER * n.Weight) / totalWeight)
		n.Balance = n.SlotsCount - expected
		totalBalance += n.Balance

		/* Compute the percentage of difference between the
		 * expected number of slots and the real one, to see
		 * if it's over the threshold specified by the user.
		 */
		if threshold == 0 {
			continue
		}

		switch {
		case n.SlotsCount == 0:
			if expected > 1 {
				thresholdReached = true
			}
		case n.SlotsCount > 0:
			errPerc := Abs(100 - float64(100.0*expected)/float64(n.SlotsCount))
			if errPerc > threshold {
				thresholdReached = true
			}
		}
	}

	if !thresholdReached {
		log.Printf(`*** No rebalancing needed! 
		All nodes are within the %.2f%% threshold.`, opt.Threshold)
		return
	}

	/* Because of rounding, it is possible that the balance of all nodes
	 * summed does not give 0. Make sure that nodes that have to provide
	 * slots are always matched by nodes receiving slots.
	 */
	for totalBalance > 0 {
		iter = involved.Iterator()
		for iter.Next() {
			n := iter.Value()
			if n.Balance > 0 || totalBalance == 0 {
				continue
			}

			n.Balance--
			totalBalance--
		}
	}

	/* Sort nodes by their slots balance. */
	sort.Slice(weightedNodes, func(i, j int) bool {
		return weightedNodes[i].Balance < weightedNodes[j].Balance
	})

	log.Printf(`>>> Rebalancing across %d nodes. 
	Total weight = %.2f\n`,
		nodesInvolved, totalWeight)

	if opt.Verbose {
		for _, n := range weightedNodes {
			log.Printf("%v balance is %d slots\n", n.ID, n.Balance)
		}
	}

	/* Now we have at the start of the 'sn' array nodes that should get
	 * slots, at the end nodes that must give slots.
	 * We take two indexes, one at the start, and one at the end,
	 * incrementing or decrementing the indexes accordingly til we
	 * find nodes that need to get/provide slots.
	 */
	dstIdx := 0
	srcIdx := nodesInvolved - 1
	simulate := opt.Flags&CMD_FLAG_SIMULATE > 0
	for dstIdx < srcIdx {
		dst := weightedNodes[dstIdx]
		src := weightedNodes[srcIdx]
		db := Abs(dst.Balance)
		sb := Abs(src.Balance)

		numslots := Min(db, sb)
		if numslots > 0 {
			log.Printf(`Moving %d slots from %v to %v\n`, numslots,
				src.ID,
				dst.ID)

			lsrc := NewLinkList[ClusterNode]()
			lsrc.PushBack(src)
			table := compuateReshardTable(lsrc, numslots)
			tableLen := table.Length()
			if tableLen != numslots {
				log.Printf(`"*** Assertion failed: Reshard table "
				"!= number of slots"`)
				goto endMove
			}
			if simulate {
				for i := 0; i < tableLen; i++ {
					log.Print("#")
				}
			}
			log.Print("\n")
		endMove:
		}
		dst.Balance += numslots
		src.Balance -= numslots
		if dst.Balance == 0 {
			dstIdx++
		}
		if src.Balance == 0 {
			srcIdx--
		}
	}
	return nodes
}

func compuateReshardTable(sources *LinkList[ClusterNode], numslots int) *LinkList[MovedSlot] {
	moved := NewLinkList[MovedSlot]()
	srcCount := sources.Length()
	totalSlots := 0
	sorted := make([]ClusterNode, 0, srcCount)

	iter := sources.Iterator()
	for iter.Next() {
		n := iter.Value()
		sorted = append(sorted, n)
		totalSlots += n.SlotsCount
	}

	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].SlotsCount < sorted[j].SlotsCount
	})

	for i := 0; i < srcCount; i++ {
		node := sorted[i]
		n := float64(numslots) / float64(totalSlots) * float64(node.SlotsCount)
		if i == 0 {
			n = math.Ceil(n)
		} else {
			n = math.Floor(n)
		}

		max, count := int(n), 0
		for j := 0; j < CLUSTER_SLOTS_NUMBER; j++ {
			slot := node.Slots[j]
			if slot == 0 {
				continue
			}

			if count >= max || moved.Length() >= numslots {
				break
			}

			item := MovedSlot{
				Source: node,
				Slot:   j,
			}

			moved.PushBack(item)
			count++
		}
	}

	return moved
}
