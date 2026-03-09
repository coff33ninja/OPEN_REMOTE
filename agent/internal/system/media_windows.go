//go:build windows

package system

import "fmt"

func (e *Executor) MediaAction(action string) error {
	var (
		virtualKey uint16
		extended   bool
	)

	switch action {
	case "toggle":
		virtualKey = vkMediaPlayPause
		extended = true
	case "next":
		virtualKey = vkMediaNextTrack
		extended = true
	case "previous":
		virtualKey = vkMediaPrevTrack
		extended = true
	case "stop":
		virtualKey = vkMediaStop
		extended = true
	default:
		return fmt.Errorf("unsupported media action %q", action)
	}

	if err := sendVirtualKey(virtualKey, extended); err != nil {
		return err
	}

	e.logger.Printf("media action=%s", action)
	return nil
}
