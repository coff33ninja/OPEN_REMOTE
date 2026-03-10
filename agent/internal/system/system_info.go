package system

type CpuInfo struct {
	Name         string `json:"name"`
	LoadPercent  int    `json:"load_percent,omitempty"`
	Cores        int    `json:"cores,omitempty"`
	LogicalCores int    `json:"logical_cores,omitempty"`
	MaxMHz       int    `json:"max_mhz,omitempty"`
}

type MemoryInfo struct {
	TotalBytes  int64   `json:"total_bytes"`
	FreeBytes   int64   `json:"free_bytes"`
	UsedBytes   int64   `json:"used_bytes"`
	UsedPercent float64 `json:"used_percent"`
}

type GpuInfo struct {
	Name         string `json:"name"`
	Driver       string `json:"driver,omitempty"`
	AdapterBytes int64  `json:"adapter_bytes,omitempty"`
}

type DiskInfo struct {
	Name        string  `json:"name"`
	Label       string  `json:"label,omitempty"`
	FileSystem  string  `json:"file_system,omitempty"`
	DriveType   string  `json:"drive_type,omitempty"`
	TotalBytes  int64   `json:"total_bytes"`
	FreeBytes   int64   `json:"free_bytes"`
	UsedBytes   int64   `json:"used_bytes"`
	FreePercent float64 `json:"free_percent"`
}

type SystemSnapshot struct {
	CPUs   []CpuInfo   `json:"cpus"`
	Memory *MemoryInfo `json:"memory,omitempty"`
	GPUs   []GpuInfo   `json:"gpus,omitempty"`
	Disks  []DiskInfo  `json:"disks,omitempty"`
}
