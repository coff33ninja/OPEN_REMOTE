package system

import (
	"fmt"
	"strings"
)

func normalizeMouseButton(button string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(button)) {
	case "", "left":
		return "left", nil
	case "right":
		return "right", nil
	case "middle":
		return "middle", nil
	default:
		return "", fmt.Errorf("unsupported mouse button %q", button)
	}
}
