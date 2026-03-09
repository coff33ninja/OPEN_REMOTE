//go:build !windows

package system

type adapterMetadata struct {
	FriendlyName string
	Description  string
	Kind         string
	IsVirtual    bool
}

func loadAdapterMetadata() (map[int]adapterMetadata, error) {
	return map[int]adapterMetadata{}, nil
}
