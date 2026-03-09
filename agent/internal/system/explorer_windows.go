//go:build windows

package system

import (
	"os"
	"path/filepath"
	"sort"
	"syscall"
	"time"
)

var (
	kernel32             = syscall.NewLazyDLL("kernel32.dll")
	procGetLogicalDrives = kernel32.NewProc("GetLogicalDrives")
)

func (e *Executor) ListDirectory(target string) ([]FileEntry, error) {
	if target == "" {
		return listWindowsDrives()
	}

	entries, err := os.ReadDir(target)
	if err != nil {
		return nil, err
	}

	items := make([]FileEntry, 0, len(entries))
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			continue
		}
		items = append(items, FileEntry{
			Name:     entry.Name(),
			Path:     filepath.Join(target, entry.Name()),
			IsDir:    entry.IsDir(),
			Size:     info.Size(),
			Modified: info.ModTime().UTC().Format(time.RFC3339),
		})
	}

	sort.Slice(items, func(i int, j int) bool {
		if items[i].IsDir != items[j].IsDir {
			return items[i].IsDir
		}
		return items[i].Name < items[j].Name
	})

	return items, nil
}

func listWindowsDrives() ([]FileEntry, error) {
	mask, _, err := procGetLogicalDrives.Call()
	if mask == 0 {
		return nil, err
	}

	items := make([]FileEntry, 0, 8)
	for i := 0; i < 26; i++ {
		if mask&(1<<i) == 0 {
			continue
		}
		drive := string(rune('A'+i)) + ":\\"
		items = append(items, FileEntry{
			Name:    drive,
			Path:    drive,
			IsDir:   true,
			IsDrive: true,
		})
	}

	return items, nil
}
