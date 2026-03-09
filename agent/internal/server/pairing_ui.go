package server

import (
	"fmt"
	"os/exec"
	"runtime"
)

func openBrowser(url string) error {
	switch runtime.GOOS {
	case "windows":
		return exec.Command("cmd", "/c", "start", "", url).Start()
	case "darwin":
		return exec.Command("open", url).Start()
	default:
		return exec.Command("xdg-open", url).Start()
	}
}

func pairingPageURL(port int) string {
	return fmt.Sprintf("http://127.0.0.1:%d/pair", port)
}
