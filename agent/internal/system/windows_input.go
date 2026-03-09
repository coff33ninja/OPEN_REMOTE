//go:build windows

package system

import (
	"fmt"
	"syscall"
	"time"
	"unicode/utf16"
	"unsafe"
)

const (
	inputKeyboard        = 1
	keyeventfExtendedKey = 0x0001
	keyeventfKeyUp       = 0x0002
	keyeventfUnicode     = 0x0004

	mouseeventfLeftDown   = 0x0002
	mouseeventfLeftUp     = 0x0004
	mouseeventfRightDown  = 0x0008
	mouseeventfRightUp    = 0x0010
	mouseeventfMiddleDown = 0x0020
	mouseeventfMiddleUp   = 0x0040

	vkLeft           = 0x25
	vkRight          = 0x27
	vkVolumeMute     = 0xAD
	vkVolumeDown     = 0xAE
	vkVolumeUp       = 0xAF
	vkMediaNextTrack = 0xB0
	vkMediaPrevTrack = 0xB1
	vkMediaStop      = 0xB2
	vkMediaPlayPause = 0xB3
)

var (
	user32           = syscall.NewLazyDLL("user32.dll")
	procGetCursorPos = user32.NewProc("GetCursorPos")
	procSetCursorPos = user32.NewProc("SetCursorPos")
	procMouseEvent   = user32.NewProc("mouse_event")
	procSendInput    = user32.NewProc("SendInput")
)

type point struct {
	X int32
	Y int32
}

type keyboardInput struct {
	VirtualKey uint16
	ScanCode   uint16
	Flags      uint32
	Time       uint32
	ExtraInfo  uintptr
}

type input struct {
	Type    uint32
	Padding uint32
	Ki      keyboardInput
	_       [8]byte
}

func currentCursorPosition() (point, error) {
	var pt point
	result, _, err := procGetCursorPos.Call(uintptr(unsafe.Pointer(&pt)))
	if result == 0 {
		if err != syscall.Errno(0) {
			return point{}, err
		}
		return point{}, fmt.Errorf("GetCursorPos failed")
	}

	return pt, nil
}

func setCursorPosition(x int32, y int32) error {
	result, _, err := procSetCursorPos.Call(uintptr(int(x)), uintptr(int(y)))
	if result == 0 {
		if err != syscall.Errno(0) {
			return err
		}
		return fmt.Errorf("SetCursorPos failed")
	}

	return nil
}

func sendMouseClick(downFlag uintptr, upFlag uintptr) error {
	procMouseEvent.Call(downFlag, 0, 0, 0, 0)
	procMouseEvent.Call(upFlag, 0, 0, 0, 0)
	return nil
}

func sendVirtualKey(virtualKey uint16, extended bool) error {
	flags := uint32(0)
	if extended {
		flags |= keyeventfExtendedKey
	}

	inputs := []input{
		{
			Type: inputKeyboard,
			Ki: keyboardInput{
				VirtualKey: virtualKey,
				Flags:      flags,
			},
		},
		{
			Type: inputKeyboard,
			Ki: keyboardInput{
				VirtualKey: virtualKey,
				Flags:      flags | keyeventfKeyUp,
			},
		},
	}

	return sendInputs(inputs)
}

func sendUnicodeText(text string) error {
	for _, runeValue := range text {
		codes := utf16.Encode([]rune{runeValue})
		for _, code := range codes {
			inputs := []input{
				{
					Type: inputKeyboard,
					Ki: keyboardInput{
						ScanCode: code,
						Flags:    keyeventfUnicode,
					},
				},
				{
					Type: inputKeyboard,
					Ki: keyboardInput{
						ScanCode: code,
						Flags:    keyeventfUnicode | keyeventfKeyUp,
					},
				},
			}

			if err := sendInputs(inputs); err != nil {
				return err
			}
		}
	}

	return nil
}

func sendInputs(inputs []input) error {
	if len(inputs) == 0 {
		return nil
	}

	result, _, err := procSendInput.Call(
		uintptr(len(inputs)),
		uintptr(unsafe.Pointer(&inputs[0])),
		unsafe.Sizeof(inputs[0]),
	)
	if result != uintptr(len(inputs)) {
		if err != syscall.Errno(0) {
			return err
		}
		return fmt.Errorf("SendInput sent %d of %d events", result, len(inputs))
	}

	time.Sleep(8 * time.Millisecond)
	return nil
}
