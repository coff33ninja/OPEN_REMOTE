//go:build windows

package system

import "fmt"

func (e *Executor) TypeText(text string) error {
	if text == "" {
		return fmt.Errorf("text is required")
	}

	if err := sendUnicodeText(text); err != nil {
		return err
	}

	e.logger.Printf("keyboard type text=%q", text)
	return nil
}

func (e *Executor) PressKey(key string) error {
	normalized, spec, err := resolveKeyboardKey(key)
	if err != nil {
		return err
	}

	if err := sendVirtualKey(spec.VirtualKey, spec.Extended); err != nil {
		return err
	}

	e.logger.Printf("keyboard press key=%s", normalized)
	return nil
}

func (e *Executor) KeyDown(key string) error {
	normalized, spec, err := resolveKeyboardKey(key)
	if err != nil {
		return err
	}

	if err := sendVirtualKeyDown(spec.VirtualKey, spec.Extended); err != nil {
		return err
	}

	e.logger.Printf("keyboard key down key=%s", normalized)
	return nil
}

func (e *Executor) KeyUp(key string) error {
	normalized, spec, err := resolveKeyboardKey(key)
	if err != nil {
		return err
	}

	if err := sendVirtualKeyUp(spec.VirtualKey, spec.Extended); err != nil {
		return err
	}

	e.logger.Printf("keyboard key up key=%s", normalized)
	return nil
}

func (e *Executor) Shortcut(keys []string) error {
	if len(keys) == 0 {
		return fmt.Errorf("shortcut keys are required")
	}

	inputs := make([]input, 0, len(keys)*2)
	normalizedKeys := make([]string, 0, len(keys))
	resolved := make([]keyboardKeySpec, 0, len(keys))
	for _, key := range keys {
		normalized, spec, err := resolveKeyboardKey(key)
		if err != nil {
			return err
		}
		normalizedKeys = append(normalizedKeys, normalized)
		resolved = append(resolved, spec)
		inputs = append(inputs, newKeyboardInput(spec.VirtualKey, spec.Extended, false))
	}
	for index := len(resolved) - 1; index >= 0; index-- {
		spec := resolved[index]
		inputs = append(inputs, newKeyboardInput(spec.VirtualKey, spec.Extended, true))
	}

	if err := sendInputs(inputs); err != nil {
		return err
	}

	e.logger.Printf("keyboard shortcut keys=%v", normalizedKeys)
	return nil
}
