package rebalance

const (
	CLUSTER_SLOTS_NUMBER = 16384

	FLAG_MYSELF = 1 << 0
	FLAG_SLAVE  = 1 << 1
)

// ClusterNode is a node in cluster
type ClusterNode struct {
	ID         string // Node ID
	Flags      int
	Replicate  string  // Master ID if node is a slave
	SlotsCount int     // Slots count
	Slots      []int   // Slots
	Balance    int     // Used by rebalance
	Weight     float64 // Weight used by rebalance
}

type MovedSlot struct {
	Source ClusterNode
	Slot   int
}
