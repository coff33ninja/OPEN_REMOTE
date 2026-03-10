//go:build !windows

package system

import "errors"

func (e *Executor) FetchSystemSnapshot() (SystemSnapshot, error) {
	return SystemSnapshot{}, errors.New("system info is not supported on this platform")
}
