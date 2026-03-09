//go:build !windows

package system

import "fmt"

func (e *Executor) TypeText(text string) error {
	if text == "" {
		return fmt.Errorf("text is required")
	}

	e.logger.Printf("keyboard type text=%q", text)
	return nil
}

func (e *Executor) PressKey(key string) error {
	normalized, _, err := resolveKeyboardKey(key)
	if err != nil {
		return err
	}

	e.logger.Printf("keyboard press key=%s", normalized)
	return nil
}

func (e *Executor) KeyDown(key string) error {
	normalized, _, err := resolveKeyboardKey(key)
	if err != nil {
		return err
	}

	e.logger.Printf("keyboard key down key=%s", normalized)
	return nil
}

func (e *Executor) KeyUp(key string) error {
	normalized, _, err := resolveKeyboardKey(key)
	if err != nil {
		return err
	}

	e.logger.Printf("keyboard key up key=%s", normalized)
	return nil
}

func (e *Executor) Shortcut(keys []string) error {
	if len(keys) == 0 {
		return fmt.Errorf("shortcut keys are required")
	}

	for _, key := range keys {
		if _, _, err := resolveKeyboardKey(key); err != nil {
			return err
		}
	}

	e.logger.Printf("keyboard shortcut keys=%v", keys)
	return nil
}
