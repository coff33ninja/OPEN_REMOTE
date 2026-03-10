//go:build windows

package system

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"
)

type systemInfoPayload struct {
	CPU    json.RawMessage `json:"cpu"`
	Memory json.RawMessage `json:"memory"`
	GPUs   json.RawMessage `json:"gpus"`
	Disks  json.RawMessage `json:"disks"`
}

type cpuRow struct {
	Name                      string `json:"Name"`
	LoadPercentage            *int   `json:"LoadPercentage"`
	NumberOfCores             *int   `json:"NumberOfCores"`
	NumberOfLogicalProcessors *int   `json:"NumberOfLogicalProcessors"`
	MaxClockSpeed             *int   `json:"MaxClockSpeed"`
}

type memoryRow struct {
	TotalVisibleMemorySize *uint64 `json:"TotalVisibleMemorySize"`
	FreePhysicalMemory     *uint64 `json:"FreePhysicalMemory"`
}

type gpuRow struct {
	Name          string  `json:"Name"`
	DriverVersion string  `json:"DriverVersion"`
	AdapterRAM    *uint64 `json:"AdapterRAM"`
}

type diskRow struct {
	DeviceID   string  `json:"DeviceID"`
	VolumeName string  `json:"VolumeName"`
	FileSystem string  `json:"FileSystem"`
	Size       *uint64 `json:"Size"`
	FreeSpace  *uint64 `json:"FreeSpace"`
	DriveType  *uint32 `json:"DriveType"`
}

func (e *Executor) FetchSystemSnapshot() (SystemSnapshot, error) {
	script := strings.Join([]string{
		"$ErrorActionPreference='Stop'",
		"$cpu = Get-CimInstance Win32_Processor | Select-Object Name,LoadPercentage,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed",
		"$memory = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory",
		"$gpus = Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM",
		"$disks = Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,VolumeName,FileSystem,Size,FreeSpace,DriveType",
		"[pscustomobject]@{ cpu=$cpu; memory=$memory; gpus=$gpus; disks=$disks } | ConvertTo-Json -Depth 4",
	}, "; ")

	output, err := runPowerShell(script)
	if err != nil {
		return SystemSnapshot{}, err
	}

	var payload systemInfoPayload
	if err := json.Unmarshal(output, &payload); err != nil {
		return SystemSnapshot{}, fmt.Errorf("system info decode failed: %w", err)
	}

	cpuRows, err := decodeSingleOrList[cpuRow](payload.CPU)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("cpu decode failed: %w", err)
	}

	memoryRow, err := decodeSingle[memoryRow](payload.Memory)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("memory decode failed: %w", err)
	}

	gpuRows, err := decodeSingleOrList[gpuRow](payload.GPUs)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("gpu decode failed: %w", err)
	}

	diskRows, err := decodeSingleOrList[diskRow](payload.Disks)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("disk decode failed: %w", err)
	}

	cpus := make([]CpuInfo, 0, len(cpuRows))
	for _, row := range cpuRows {
		cpus = append(cpus, CpuInfo{
			Name:         row.Name,
			LoadPercent:  intFromPtr(row.LoadPercentage),
			Cores:        intFromPtr(row.NumberOfCores),
			LogicalCores: intFromPtr(row.NumberOfLogicalProcessors),
			MaxMHz:       intFromPtr(row.MaxClockSpeed),
		})
	}

	var memory *MemoryInfo
	if memoryRow != nil {
		totalBytes := bytesFromKB(memoryRow.TotalVisibleMemorySize)
		freeBytes := bytesFromKB(memoryRow.FreePhysicalMemory)
		usedBytes := totalBytes - freeBytes
		if usedBytes < 0 {
			usedBytes = 0
		}
		usedPercent := percentOf(usedBytes, totalBytes)
		memory = &MemoryInfo{
			TotalBytes:  totalBytes,
			FreeBytes:   freeBytes,
			UsedBytes:   usedBytes,
			UsedPercent: usedPercent,
		}
	}

	gpus := make([]GpuInfo, 0, len(gpuRows))
	for _, row := range gpuRows {
		gpus = append(gpus, GpuInfo{
			Name:         row.Name,
			Driver:       row.DriverVersion,
			AdapterBytes: int64FromPtr(row.AdapterRAM),
		})
	}

	disks := make([]DiskInfo, 0, len(diskRows))
	for _, row := range diskRows {
		totalBytes := int64FromPtr(row.Size)
		freeBytes := int64FromPtr(row.FreeSpace)
		usedBytes := totalBytes - freeBytes
		if usedBytes < 0 {
			usedBytes = 0
		}
		disks = append(disks, DiskInfo{
			Name:        row.DeviceID,
			Label:       row.VolumeName,
			FileSystem:  row.FileSystem,
			DriveType:   formatDriveType(row.DriveType),
			TotalBytes:  totalBytes,
			FreeBytes:   freeBytes,
			UsedBytes:   usedBytes,
			FreePercent: percentOf(freeBytes, totalBytes),
		})
	}

	return SystemSnapshot{
		CPUs:   cpus,
		Memory: memory,
		GPUs:   gpus,
		Disks:  disks,
	}, nil
}

func decodeSingleOrList[T any](raw json.RawMessage) ([]T, error) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		return nil, nil
	}
	if trimmed[0] == '[' {
		var list []T
		if err := json.Unmarshal(trimmed, &list); err != nil {
			return nil, err
		}
		return list, nil
	}

	var single T
	if err := json.Unmarshal(trimmed, &single); err != nil {
		return nil, err
	}
	return []T{single}, nil
}

func decodeSingle[T any](raw json.RawMessage) (*T, error) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		return nil, nil
	}
	if trimmed[0] == '[' {
		var list []T
		if err := json.Unmarshal(trimmed, &list); err != nil {
			return nil, err
		}
		if len(list) == 0 {
			return nil, nil
		}
		return &list[0], nil
	}

	var single T
	if err := json.Unmarshal(trimmed, &single); err != nil {
		return nil, err
	}
	return &single, nil
}

func intFromPtr(value *int) int {
	if value == nil {
		return 0
	}
	return *value
}

func int64FromPtr(value *uint64) int64 {
	if value == nil {
		return 0
	}
	return int64(*value)
}

func bytesFromKB(value *uint64) int64 {
	if value == nil {
		return 0
	}
	return int64(*value * 1024)
}

func percentOf(part int64, total int64) float64 {
	if total <= 0 {
		return 0
	}
	return (float64(part) / float64(total)) * 100
}

func formatDriveType(value *uint32) string {
	if value == nil {
		return ""
	}
	switch *value {
	case 2:
		return "Removable"
	case 3:
		return "Fixed"
	case 4:
		return "Network"
	case 5:
		return "CD-ROM"
	case 6:
		return "RAM"
	default:
		return "Unknown"
	}
}
