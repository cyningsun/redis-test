package rebalance

const (
	CMD_FLAG_EMPTYMASTER = 1 << 4
	CMD_FLAG_SIMULATE    = 1 << 5
)

type Option struct {
	Flags     int
	Threshold float64
	Verbose   bool
}
