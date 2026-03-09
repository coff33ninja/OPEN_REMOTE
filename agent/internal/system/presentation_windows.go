//go:build windows

package system

import "fmt"

func (e *Executor) PresentationAction(action string) error {
	switch action {
	case "next":
		if err := sendVirtualKey(vkRight, true); err != nil {
			return err
		}
	case "previous":
		if err := sendVirtualKey(vkLeft, true); err != nil {
			return err
		}
	case "blackout":
		if err := sendVirtualKey(uint16('B'), false); err != nil {
			return err
		}
	default:
		return fmt.Errorf("unsupported presentation action %q", action)
	}

	e.logger.Printf("presentation action=%s", action)
	return nil
}
