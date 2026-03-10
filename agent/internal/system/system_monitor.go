package system

import (
	"context"
	"strings"
	"time"
)

func (e *Executor) StartSystemMonitor(ctx context.Context, interval time.Duration) {
	if interval <= 0 {
		interval = 5 * time.Second
	}

	if !e.refreshSystemSnapshot() {
		return
	}

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if !e.refreshSystemSnapshot() {
				return
			}
		}
	}
}

func (e *Executor) SystemSnapshot() (*SystemSnapshot, time.Time, string, bool) {
	e.systemMu.RLock()
	defer e.systemMu.RUnlock()

	if e.systemSnapshot == nil && e.systemAt.IsZero() && e.systemErr == "" {
		return nil, time.Time{}, "", false
	}

	if e.systemSnapshot == nil {
		return nil, e.systemAt, e.systemErr, true
	}

	snapshot := *e.systemSnapshot
	snapshot.CPUs = append([]CpuInfo(nil), snapshot.CPUs...)
	snapshot.GPUs = append([]GpuInfo(nil), snapshot.GPUs...)
	snapshot.Disks = append([]DiskInfo(nil), snapshot.Disks...)
	if snapshot.Memory != nil {
		memCopy := *snapshot.Memory
		snapshot.Memory = &memCopy
	}

	return &snapshot, e.systemAt, e.systemErr, true
}

func (e *Executor) refreshSystemSnapshot() bool {
	snapshot, err := e.FetchSystemSnapshot()
	if err != nil {
		e.systemMu.Lock()
		e.systemErr = err.Error()
		e.systemMu.Unlock()

		if strings.Contains(strings.ToLower(err.Error()), "not supported") {
			if e.logger != nil {
				e.logger.Printf("system monitor disabled: %v", err)
			}
			return false
		}
		return true
	}

	e.systemMu.Lock()
	e.systemSnapshot = &snapshot
	e.systemAt = time.Now().UTC()
	e.systemErr = ""
	e.systemMu.Unlock()
	return true
}
