//go:build windows

package system

import (
	"fmt"
	"os/exec"
)

func (e *Executor) PowerAction(action string) error {
	var command *exec.Cmd

	switch action {
	case "sleep":
		command = exec.Command("rundll32.exe", "powrprof.dll,SetSuspendState", "0,1,0")
	case "shutdown":
		command = exec.Command("shutdown.exe", "/s", "/t", "0")
	case "restart":
		command = exec.Command("shutdown.exe", "/r", "/t", "0")
	default:
		return fmt.Errorf("unsupported power action %q", action)
	}

	if err := command.Run(); err != nil {
		return err
	}

	e.logger.Printf("power action=%s", action)
	return nil
}
