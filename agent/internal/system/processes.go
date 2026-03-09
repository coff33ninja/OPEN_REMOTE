//go:build !windows

package system

import (
	"fmt"
	"os/exec"
)

func (e *Executor) ListProcesses() ([]ProcessInfo, error) {
	return nil, fmt.Errorf("process listing is not implemented on this platform")
}

func (e *Executor) TerminateProcess(pid int) error {
	return exec.Command("kill", "-TERM", fmt.Sprintf("%d", pid)).Run()
}
