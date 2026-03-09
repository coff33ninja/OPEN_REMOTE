package system

import (
	"fmt"
	"strconv"
	"strings"
)

type keyboardKeySpec struct {
	VirtualKey uint16
	Extended   bool
}

func resolveKeyboardKey(key string) (string, keyboardKeySpec, error) {
	normalized := strings.ToLower(strings.TrimSpace(key))
	if normalized == "" {
		return "", keyboardKeySpec{}, fmt.Errorf("key is required")
	}

	if spec, ok := keyboardNamedKeys[normalized]; ok {
		return normalized, spec, nil
	}

	if len(normalized) == 1 {
		runeValue := normalized[0]
		switch {
		case runeValue >= 'a' && runeValue <= 'z':
			return normalized, keyboardKeySpec{VirtualKey: uint16(strings.ToUpper(normalized)[0])}, nil
		case runeValue >= '0' && runeValue <= '9':
			return normalized, keyboardKeySpec{VirtualKey: uint16(runeValue)}, nil
		}
	}

	if strings.HasPrefix(normalized, "f") {
		index, err := strconv.Atoi(strings.TrimPrefix(normalized, "f"))
		if err == nil && index >= 1 && index <= 12 {
			return normalized, keyboardKeySpec{VirtualKey: uint16(vkF1 + index - 1)}, nil
		}
	}

	return "", keyboardKeySpec{}, fmt.Errorf("unsupported keyboard key %q", key)
}

var keyboardNamedKeys = map[string]keyboardKeySpec{
	"backspace":   {VirtualKey: vkBack},
	"bksp":        {VirtualKey: vkBack},
	"tab":         {VirtualKey: vkTab},
	"enter":       {VirtualKey: vkReturn},
	"return":      {VirtualKey: vkReturn},
	"shift":       {VirtualKey: vkShift},
	"ctrl":        {VirtualKey: vkControl},
	"control":     {VirtualKey: vkControl},
	"alt":         {VirtualKey: vkMenu},
	"option":      {VirtualKey: vkMenu},
	"pause":       {VirtualKey: vkPause},
	"capslock":    {VirtualKey: vkCapital},
	"esc":         {VirtualKey: vkEscape},
	"escape":      {VirtualKey: vkEscape},
	"space":       {VirtualKey: vkSpace},
	"spacebar":    {VirtualKey: vkSpace},
	"pageup":      {VirtualKey: vkPageUp, Extended: true},
	"pgup":        {VirtualKey: vkPageUp, Extended: true},
	"prior":       {VirtualKey: vkPageUp, Extended: true},
	"pagedown":    {VirtualKey: vkPageDown, Extended: true},
	"pgdn":        {VirtualKey: vkPageDown, Extended: true},
	"next":        {VirtualKey: vkPageDown, Extended: true},
	"end":         {VirtualKey: vkEnd, Extended: true},
	"home":        {VirtualKey: vkHome, Extended: true},
	"left":        {VirtualKey: vkLeft, Extended: true},
	"arrowleft":   {VirtualKey: vkLeft, Extended: true},
	"up":          {VirtualKey: vkUp, Extended: true},
	"arrowup":     {VirtualKey: vkUp, Extended: true},
	"right":       {VirtualKey: vkRight, Extended: true},
	"arrowright":  {VirtualKey: vkRight, Extended: true},
	"down":        {VirtualKey: vkDown, Extended: true},
	"arrowdown":   {VirtualKey: vkDown, Extended: true},
	"select":      {VirtualKey: vkSelect},
	"print":       {VirtualKey: vkPrint},
	"snapshot":    {VirtualKey: vkSnapshot, Extended: true},
	"printscreen": {VirtualKey: vkSnapshot, Extended: true},
	"insert":      {VirtualKey: vkInsert, Extended: true},
	"ins":         {VirtualKey: vkInsert, Extended: true},
	"delete":      {VirtualKey: vkDelete, Extended: true},
	"del":         {VirtualKey: vkDelete, Extended: true},
	"meta":        {VirtualKey: vkLeftWin},
	"win":         {VirtualKey: vkLeftWin},
	"super":       {VirtualKey: vkLeftWin},
	"command":     {VirtualKey: vkLeftWin},
	"cmd":         {VirtualKey: vkLeftWin},
}
