//go:build !windows

package system

func (e *Executor) MoveMouse(dx int, dy int) error {
	e.logger.Printf("mouse move dx=%d dy=%d", dx, dy)
	return nil
}

func (e *Executor) ClickMouse(button string) error {
	normalized, err := normalizeMouseButton(button)
	if err != nil {
		return err
	}

	e.logger.Printf("mouse click button=%s", normalized)
	return nil
}

func (e *Executor) MouseButtonDown(button string) error {
	normalized, err := normalizeMouseButton(button)
	if err != nil {
		return err
	}

	e.logger.Printf("mouse button down button=%s", normalized)
	return nil
}

func (e *Executor) MouseButtonUp(button string) error {
	normalized, err := normalizeMouseButton(button)
	if err != nil {
		return err
	}

	e.logger.Printf("mouse button up button=%s", normalized)
	return nil
}

func (e *Executor) ScrollMouse(vertical int) error {
	e.logger.Printf("mouse scroll vertical=%d", vertical)
	return nil
}
