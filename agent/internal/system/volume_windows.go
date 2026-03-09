//go:build windows

package system

import "fmt"

func (e *Executor) SetVolume(level int) error {
	if level < 0 || level > 100 {
		return fmt.Errorf("volume must be between 0 and 100")
	}

	current := e.rememberVolume(level)
	if current == level {
		return nil
	}

	virtualKey := uint16(vkVolumeUp)
	delta := level - current
	if delta < 0 {
		virtualKey = uint16(vkVolumeDown)
		delta = -delta
	}

	presses := delta / 2
	if delta%2 != 0 {
		presses++
	}
	if presses == 0 {
		presses = 1
	}

	for i := 0; i < presses; i++ {
		if err := sendVirtualKey(virtualKey, true); err != nil {
			return err
		}
	}

	e.logger.Printf("volume set=%d", level)
	return nil
}
