//go:build !windows

package system

import "fmt"

func (e *Executor) SetVolume(level int) error {
	if level < 0 || level > 100 {
		return fmt.Errorf("volume must be between 0 and 100")
	}

	e.logger.Printf("volume set=%d", level)
	return nil
}
