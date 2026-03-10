//go:build windows

package system

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"
)

type systemInfoPayload struct {
	CPU       json.RawMessage `json:"cpu"`
	CPUCores  json.RawMessage `json:"cpu_cores"`
	Memory    json.RawMessage `json:"memory"`
	GPUs      json.RawMessage `json:"gpus"`
	GPUMemory json.RawMessage `json:"gpu_memory"`
	Thermals  json.RawMessage `json:"thermals"`
	Disks     json.RawMessage `json:"disks"`
}

type cpuRow struct {
	Name                      string  `json:"Name"`
	LoadPercentage            *int    `json:"LoadPercentage"`
	NumberOfCores             *int    `json:"NumberOfCores"`
	NumberOfLogicalProcessors *int    `json:"NumberOfLogicalProcessors"`
	MaxClockSpeed             *int    `json:"MaxClockSpeed"`
	Manufacturer              string  `json:"Manufacturer"`
	Architecture              *uint16 `json:"Architecture"`
}

type cpuCoreRow struct {
	Name                 string `json:"Name"`
	PercentProcessorTime *int   `json:"PercentProcessorTime"`
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

type gpuMemoryRow struct {
	DedicatedUsage *uint64 `json:"DedicatedUsage"`
	SharedUsage    *uint64 `json:"SharedUsage"`
	TotalCommitted *uint64 `json:"TotalCommitted"`
}

type diskRow struct {
	DeviceID   string  `json:"DeviceID"`
	VolumeName string  `json:"VolumeName"`
	FileSystem string  `json:"FileSystem"`
	Size       *uint64 `json:"Size"`
	FreeSpace  *uint64 `json:"FreeSpace"`
	DriveType  *uint32 `json:"DriveType"`
}

type thermalRow struct {
	InstanceName       string  `json:"InstanceName"`
	CurrentTemperature *uint32 `json:"CurrentTemperature"`
}

func (e *Executor) FetchSystemSnapshot() (SystemSnapshot, error) {
	script := strings.Join([]string{
		"$ErrorActionPreference='Stop'",
		"$cpu = Get-CimInstance Win32_Processor | Select-Object Name,LoadPercentage,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,Manufacturer,Architecture",
		"$cpuCores = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor | Select-Object Name,PercentProcessorTime",
		"$memory = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory",
		"$gpus = Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM",
		"$gpuMemory = @(); try { $gpuMemory = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory | Select-Object Name,DedicatedUsage,SharedUsage,TotalCommitted } catch { $gpuMemory = @() }",
		"$thermals = @(); try { $thermals = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop | Select-Object InstanceName,CurrentTemperature } catch { $thermals = @() }",
		"$disks = Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,VolumeName,FileSystem,Size,FreeSpace,DriveType",
		"[pscustomobject]@{ cpu=$cpu; cpu_cores=$cpuCores; memory=$memory; gpus=$gpus; gpu_memory=$gpuMemory; thermals=$thermals; disks=$disks } | ConvertTo-Json -Depth 4",
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

	cpuCoreRows, err := decodeSingleOrList[cpuCoreRow](payload.CPUCores)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("cpu cores decode failed: %w", err)
	}

	memoryRow, err := decodeSingle[memoryRow](payload.Memory)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("memory decode failed: %w", err)
	}

	gpuRows, err := decodeSingleOrList[gpuRow](payload.GPUs)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("gpu decode failed: %w", err)
	}

	gpuMemoryRows, err := decodeSingleOrList[gpuMemoryRow](payload.GPUMemory)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("gpu memory decode failed: %w", err)
	}

	thermalRows, err := decodeSingleOrList[thermalRow](payload.Thermals)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("thermal decode failed: %w", err)
	}

	diskRows, err := decodeSingleOrList[diskRow](payload.Disks)
	if err != nil {
		return SystemSnapshot{}, fmt.Errorf("disk decode failed: %w", err)
	}

	cpus := make([]CpuInfo, 0, len(cpuRows))
	for _, row := range cpuRows {
		cpus = append(cpus, CpuInfo{
			Name:         row.Name,
			Vendor:       strings.TrimSpace(row.Manufacturer),
			Architecture: cpuArchitectureLabel(row.Architecture),
			LoadPercent:  intFromPtr(row.LoadPercentage),
			Cores:        intFromPtr(row.NumberOfCores),
			LogicalCores: intFromPtr(row.NumberOfLogicalProcessors),
			MaxMHz:       intFromPtr(row.MaxClockSpeed),
		})
	}

	cpuCores := make([]CpuCoreInfo, 0, len(cpuCoreRows))
	for _, row := range cpuCoreRows {
		name := strings.TrimSpace(row.Name)
		if name == "" || strings.EqualFold(name, "_Total") {
			continue
		}
		cpuCores = append(cpuCores, CpuCoreInfo{
			ID:           name,
			UsagePercent: intFromPtr(row.PercentProcessorTime),
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

	var gpuMemory *GpuMemoryInfo
	if len(gpuMemoryRows) > 0 {
		var dedicatedUsage uint64
		var sharedUsage uint64
		var totalCommitted uint64
		for _, row := range gpuMemoryRows {
			dedicatedUsage += uint64FromPtr(row.DedicatedUsage)
			sharedUsage += uint64FromPtr(row.SharedUsage)
			totalCommitted += uint64FromPtr(row.TotalCommitted)
		}
		gpuMemory = &GpuMemoryInfo{
			DedicatedUsedBytes:  bytesFromKBValue(dedicatedUsage),
			SharedUsedBytes:     bytesFromKBValue(sharedUsage),
			TotalCommittedBytes: bytesFromKBValue(totalCommitted),
		}
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

	thermals := make([]ThermalZoneInfo, 0, len(thermalRows))
	for _, row := range thermalRows {
		tempC, ok := temperatureFromTenthsKelvin(row.CurrentTemperature)
		if !ok {
			continue
		}
		name := strings.TrimSpace(row.InstanceName)
		if name == "" {
			name = "Thermal"
		}
		thermals = append(thermals, ThermalZoneInfo{
			Name:         name,
			TemperatureC: tempC,
		})
	}

	return SystemSnapshot{
		CPUs:      cpus,
		CpuCores:  cpuCores,
		Memory:    memory,
		GPUs:      gpus,
		GpuMemory: gpuMemory,
		Disks:     disks,
		Thermals:  thermals,
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

func uint64FromPtr(value *uint64) uint64 {
	if value == nil {
		return 0
	}
	return *value
}

func bytesFromKB(value *uint64) int64 {
	if value == nil {
		return 0
	}
	return int64(*value * 1024)
}

func bytesFromKBValue(value uint64) int64 {
	return int64(value * 1024)
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

func cpuArchitectureLabel(value *uint16) string {
	if value == nil {
		return ""
	}
	switch *value {
	case 0:
		return "x86"
	case 1:
		return "MIPS"
	case 2:
		return "Alpha"
	case 3:
		return "PowerPC"
	case 5:
		return "ARM"
	case 6:
		return "Itanium"
	case 9:
		return "x64"
	case 12:
		return "ARM64"
	default:
		return "Unknown"
	}
}

func temperatureFromTenthsKelvin(value *uint32) (float64, bool) {
	if value == nil {
		return 0, false
	}
	return (float64(*value) / 10.0) - 273.15, true
}
