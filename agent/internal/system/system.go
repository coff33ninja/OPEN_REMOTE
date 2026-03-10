package system

import (
	"log"
	"sync"
	"time"
)

type FileEntry struct {
	Name     string `json:"name"`
	Path     string `json:"path"`
	IsDir    bool   `json:"is_dir"`
	Size     int64  `json:"size"`
	Modified string `json:"modified"`
	IsDrive  bool   `json:"is_drive,omitempty"`
}

type ProcessInfo struct {
	PID        int    `json:"pid"`
	Name       string `json:"name"`
	Session    string `json:"session,omitempty"`
	SessionNum string `json:"session_num,omitempty"`
	Memory     string `json:"memory,omitempty"`
}

type ServiceInfo struct {
	Name         string `json:"name"`
	DisplayName  string `json:"display_name"`
	Status       string `json:"status"`
	StatusReason string `json:"status_reason,omitempty"`
	StartType    string `json:"start_type,omitempty"`
}

type Executor struct {
	logger         *log.Logger
	mu             sync.Mutex
	cachedVolume   int
	wakeTarget     WakeTarget
	serviceMu      sync.RWMutex
	serviceCache   []ServiceInfo
	serviceAt      time.Time
	serviceErr     string
	systemMu       sync.RWMutex
	systemSnapshot *SystemSnapshot
	systemAt       time.Time
	systemErr      string
}

func NewExecutor(logger *log.Logger) *Executor {
	return &Executor{
		logger:       logger,
		cachedVolume: 50,
	}
}

func (e *Executor) rememberVolume(target int) int {
	e.mu.Lock()
	defer e.mu.Unlock()

	current := e.cachedVolume
	e.cachedVolume = target
	return current
}
