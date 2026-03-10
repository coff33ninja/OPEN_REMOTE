package system

import (
	"testing"
	"time"
)

func TestSystemSnapshotReturnsCopy(t *testing.T) {
	executor := NewExecutor(nil)
	now := time.Now().UTC()
	executor.systemSnapshot = &SystemSnapshot{
		CPUs: []CpuInfo{
			{Name: "CPU-1", LoadPercent: 25},
		},
		Memory: &MemoryInfo{
			TotalBytes:  100,
			FreeBytes:   40,
			UsedBytes:   60,
			UsedPercent: 60,
		},
		GPUs: []GpuInfo{
			{Name: "GPU-1", AdapterBytes: 2048},
		},
		Disks: []DiskInfo{
			{Name: "C:", TotalBytes: 1000, FreeBytes: 500, UsedBytes: 500},
		},
	}
	executor.systemAt = now
	executor.systemErr = "cached error"

	snapshot, observedAt, cacheErr, ok := executor.SystemSnapshot()
	if !ok {
		t.Fatalf("SystemSnapshot() ok = false, want true")
	}
	if observedAt != now {
		t.Fatalf("SystemSnapshot() observedAt = %v, want %v", observedAt, now)
	}
	if cacheErr != "cached error" {
		t.Fatalf("SystemSnapshot() cacheErr = %q, want %q", cacheErr, "cached error")
	}
	if snapshot == nil || len(snapshot.CPUs) != 1 {
		t.Fatalf("SystemSnapshot() snapshot = %#v, want cpu entry", snapshot)
	}

	snapshot.CPUs[0].Name = "changed"
	snapshot.GPUs[0].Name = "changed"
	snapshot.Disks[0].Name = "changed"
	if snapshot.Memory != nil {
		snapshot.Memory.TotalBytes = 999
	}

	if executor.systemSnapshot.CPUs[0].Name != "CPU-1" {
		t.Fatalf("SystemSnapshot() returned cpu slice alias")
	}
	if executor.systemSnapshot.GPUs[0].Name != "GPU-1" {
		t.Fatalf("SystemSnapshot() returned gpu slice alias")
	}
	if executor.systemSnapshot.Disks[0].Name != "C:" {
		t.Fatalf("SystemSnapshot() returned disk slice alias")
	}
	if executor.systemSnapshot.Memory == nil || executor.systemSnapshot.Memory.TotalBytes != 100 {
		t.Fatalf("SystemSnapshot() returned memory alias")
	}
}

func TestServicesSnapshotReturnsCopy(t *testing.T) {
	executor := NewExecutor(nil)
	now := time.Now().UTC()
	executor.serviceCache = []ServiceInfo{
		{Name: "svc", Status: "Running"},
	}
	executor.serviceAt = now
	executor.serviceErr = "cached error"

	services, observedAt, cacheErr, ok := executor.ServicesSnapshot()
	if !ok {
		t.Fatalf("ServicesSnapshot() ok = false, want true")
	}
	if observedAt != now {
		t.Fatalf("ServicesSnapshot() observedAt = %v, want %v", observedAt, now)
	}
	if cacheErr != "cached error" {
		t.Fatalf("ServicesSnapshot() cacheErr = %q, want %q", cacheErr, "cached error")
	}
	if len(services) != 1 {
		t.Fatalf("ServicesSnapshot() services = %#v, want entry", services)
	}

	services[0].Name = "changed"
	if executor.serviceCache[0].Name != "svc" {
		t.Fatalf("ServicesSnapshot() returned slice alias")
	}
}
