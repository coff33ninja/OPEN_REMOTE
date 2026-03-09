//go:build !windows

package system

import "fmt"

func (e *Executor) PowerAction(action string) error {
	switch action {
	case "sleep", "shutdown":
		e.logger.Printf("power action=%s", action)
		return nil
	default:
		return fmt.Errorf("unsupported power action %q", action)
	}
}
