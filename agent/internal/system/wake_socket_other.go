//go:build !windows

package system

import (
	"net"
	"syscall"
)

func enableBroadcast(connection *net.UDPConn) error {
	rawConnection, err := connection.SyscallConn()
	if err != nil {
		return err
	}

	var controlErr error
	if err := rawConnection.Control(func(fd uintptr) {
		controlErr = syscall.SetsockoptInt(
			int(fd),
			syscall.SOL_SOCKET,
			syscall.SO_BROADCAST,
			1,
		)
	}); err != nil {
		return err
	}
	return controlErr
}
