//go:build !windows

package system

import "fmt"

func (e *Executor) MediaAction(action string) error {
	switch action {
	case "toggle", "next", "previous", "stop":
		e.logger.Printf("media action=%s", action)
		return nil
	default:
		return fmt.Errorf("unsupported media action %q", action)
	}
}
