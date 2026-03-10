package system

import (
	"context"
	"strings"
	"time"
)

func (e *Executor) StartServiceMonitor(ctx context.Context, interval time.Duration) {
	if interval <= 0 {
		interval = 15 * time.Second
	}

	if !e.refreshServiceCache() {
		return
	}

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if !e.refreshServiceCache() {
				return
			}
		}
	}
}

func (e *Executor) ServicesSnapshot() ([]ServiceInfo, time.Time, string, bool) {
	e.serviceMu.RLock()
	defer e.serviceMu.RUnlock()

	if len(e.serviceCache) == 0 && e.serviceAt.IsZero() && e.serviceErr == "" {
		return nil, time.Time{}, "", false
	}

	snapshot := make([]ServiceInfo, len(e.serviceCache))
	copy(snapshot, e.serviceCache)
	return snapshot, e.serviceAt, e.serviceErr, true
}

func (e *Executor) refreshServiceCache() bool {
	services, err := e.ListServices()
	if err != nil {
		e.serviceMu.Lock()
		e.serviceErr = err.Error()
		e.serviceMu.Unlock()

		if strings.Contains(strings.ToLower(err.Error()), "not supported") {
			if e.logger != nil {
				e.logger.Printf("service monitor disabled: %v", err)
			}
			return false
		}
		return true
	}

	e.serviceMu.Lock()
	e.serviceCache = services
	e.serviceAt = time.Now().UTC()
	e.serviceErr = ""
	e.serviceMu.Unlock()
	return true
}
