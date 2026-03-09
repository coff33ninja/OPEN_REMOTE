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
