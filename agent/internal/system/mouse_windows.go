//go:build windows

package system

import "fmt"

func (e *Executor) MoveMouse(dx int, dy int) error {
	position, err := currentCursorPosition()
	if err != nil {
		return err
	}

	nextX := position.X + int32(dx)
	nextY := position.Y + int32(dy)
	if err := setCursorPosition(nextX, nextY); err != nil {
		return err
	}

	e.logger.Printf("mouse move dx=%d dy=%d", dx, dy)
	return nil
}

func (e *Executor) ClickMouse(button string) error {
	switch button {
	case "", "left":
		if err := sendMouseClick(mouseeventfLeftDown, mouseeventfLeftUp); err != nil {
			return err
		}
	case "right":
		if err := sendMouseClick(mouseeventfRightDown, mouseeventfRightUp); err != nil {
			return err
		}
	case "middle":
		if err := sendMouseClick(mouseeventfMiddleDown, mouseeventfMiddleUp); err != nil {
			return err
		}
	default:
		return fmt.Errorf("unsupported mouse button %q", button)
	}

	e.logger.Printf("mouse click button=%s", fallback(button, "left"))
	return nil
}

func fallback(value string, alternative string) string {
	if value == "" {
		return alternative
	}

	return value
}
