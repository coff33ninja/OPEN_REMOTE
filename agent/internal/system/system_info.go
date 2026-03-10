package system

type CpuInfo struct {
	Name         string `json:"name"`
	Vendor       string `json:"vendor,omitempty"`
	Architecture string `json:"architecture,omitempty"`
	LoadPercent  int    `json:"load_percent,omitempty"`
	Cores        int    `json:"cores,omitempty"`
	LogicalCores int    `json:"logical_cores,omitempty"`
	MaxMHz       int    `json:"max_mhz,omitempty"`
}

type CpuCoreInfo struct {
	ID           string `json:"id"`
	UsagePercent int    `json:"usage_percent"`
	Kind         string `json:"kind,omitempty"`
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

type GpuMemoryInfo struct {
	DedicatedUsedBytes  int64 `json:"dedicated_used_bytes,omitempty"`
	SharedUsedBytes     int64 `json:"shared_used_bytes,omitempty"`
	TotalCommittedBytes int64 `json:"total_committed_bytes,omitempty"`
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

type ThermalZoneInfo struct {
	Name         string  `json:"name"`
	TemperatureC float64 `json:"temperature_c"`
}

type SystemSnapshot struct {
	CPUs      []CpuInfo         `json:"cpus"`
	CpuCores  []CpuCoreInfo     `json:"cpu_cores,omitempty"`
	Memory    *MemoryInfo       `json:"memory,omitempty"`
	GPUs      []GpuInfo         `json:"gpus,omitempty"`
	GpuMemory *GpuMemoryInfo    `json:"gpu_memory,omitempty"`
	Disks     []DiskInfo        `json:"disks,omitempty"`
	Thermals  []ThermalZoneInfo `json:"thermals,omitempty"`
}
