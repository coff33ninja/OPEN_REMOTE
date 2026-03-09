//go:build windows

package system

import (
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

func (e *Executor) OpenPath(target string) error {
	if strings.TrimSpace(target) == "" {
		return syscall.EINVAL
	}

	command := exec.Command("cmd", "/c", "start", "", filepath.Clean(target))
	command.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	return command.Start()
}
