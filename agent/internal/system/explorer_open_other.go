//go:build !windows

package system

import (
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

func (e *Executor) OpenPath(target string) error {
	if strings.TrimSpace(target) == "" {
		return exec.ErrNotFound
	}

	opener := "xdg-open"
	if runtime.GOOS == "darwin" {
		opener = "open"
	}

	return exec.Command(opener, filepath.Clean(target)).Start()
}
