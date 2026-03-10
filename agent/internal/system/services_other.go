//go:build !windows

package system

import "errors"

func (e *Executor) ListServices() ([]ServiceInfo, error) {
	return nil, errors.New("services are not supported on this platform")
}

func (e *Executor) StartService(name string) error {
	return errors.New("services are not supported on this platform")
}

func (e *Executor) StopService(name string) error {
	return errors.New("services are not supported on this platform")
}

func (e *Executor) RestartService(name string) error {
	return errors.New("services are not supported on this platform")
}
