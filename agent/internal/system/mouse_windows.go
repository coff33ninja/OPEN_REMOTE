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
	downFlag, upFlag, normalized, err := mouseFlags(button)
	if err != nil {
		return err
	}

	if err := sendMouseClick(downFlag, upFlag); err != nil {
		return err
	}

	e.logger.Printf("mouse click button=%s", normalized)
	return nil
}

func (e *Executor) MouseButtonDown(button string) error {
	downFlag, _, normalized, err := mouseFlags(button)
	if err != nil {
		return err
	}

	if err := sendMouseButton(downFlag); err != nil {
		return err
	}

	e.logger.Printf("mouse button down button=%s", normalized)
	return nil
}

func (e *Executor) MouseButtonUp(button string) error {
	_, upFlag, normalized, err := mouseFlags(button)
	if err != nil {
		return err
	}

	if err := sendMouseButton(upFlag); err != nil {
		return err
	}

	e.logger.Printf("mouse button up button=%s", normalized)
	return nil
}

func (e *Executor) ScrollMouse(vertical int) error {
	if vertical == 0 {
		return nil
	}

	if err := sendMouseWheel(int32(vertical * wheelDelta)); err != nil {
		return err
	}

	e.logger.Printf("mouse scroll vertical=%d", vertical)
	return nil
}

func mouseFlags(button string) (uintptr, uintptr, string, error) {
	normalized, err := normalizeMouseButton(button)
	if err != nil {
		return 0, 0, "", err
	}

	switch normalized {
	case "left":
		return mouseeventfLeftDown, mouseeventfLeftUp, normalized, nil
	case "right":
		return mouseeventfRightDown, mouseeventfRightUp, normalized, nil
	case "middle":
		return mouseeventfMiddleDown, mouseeventfMiddleUp, normalized, nil
	default:
		return 0, 0, "", fmt.Errorf("unsupported mouse button %q", button)
	}
}
