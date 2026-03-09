//go:build !windows

package system

import "fmt"

func (e *Executor) PresentationAction(action string) error {
	return fmt.Errorf("presentation actions are not implemented on this platform: %s", action)
}
