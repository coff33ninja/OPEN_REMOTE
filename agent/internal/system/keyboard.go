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
