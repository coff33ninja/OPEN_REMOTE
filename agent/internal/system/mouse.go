//go:build !windows

package system

import "fmt"

func (e *Executor) MoveMouse(dx int, dy int) error {
	e.logger.Printf("mouse move dx=%d dy=%d", dx, dy)
	return nil
}

func (e *Executor) ClickMouse(button string) error {
	switch button {
	case "", "left", "right", "middle":
		e.logger.Printf("mouse click button=%s", fallback(button, "left"))
		return nil
	default:
		return fmt.Errorf("unsupported mouse button %q", button)
	}
}

func fallback(value string, alternative string) string {
	if value == "" {
		return alternative
	}

	return value
}
