package system

import (
	"io"
	"log"
	"net"
	"testing"
	"time"
)

func TestMagicPacketRepeatsHardwareAddress(t *testing.T) {
	packet, err := magicPacket("01:23:45:67:89:ab")
	if err != nil {
		t.Fatalf("magicPacket() error = %v", err)
	}

	if len(packet) != 102 {
		t.Fatalf("len(packet) = %d, want 102", len(packet))
	}
	for index := range 6 {
		if packet[index] != 0xFF {
			t.Fatalf("packet[%d] = %d, want 255", index, packet[index])
		}
	}

	expectedMAC := []byte{0x01, 0x23, 0x45, 0x67, 0x89, 0xAB}
	for repeat := range 16 {
		offset := 6 + (repeat * len(expectedMAC))
		for index, value := range expectedMAC {
			if packet[offset+index] != value {
				t.Fatalf(
					"packet[%d] = %d, want %d",
					offset+index,
					packet[offset+index],
					value,
				)
			}
		}
	}
}

func TestWakeOnLANSendsMagicPacket(t *testing.T) {
	listener, err := net.ListenUDP("udp4", &net.UDPAddr{
		IP:   net.ParseIP("127.0.0.1"),
		Port: 0,
	})
	if err != nil {
		t.Fatalf("ListenUDP() error = %v", err)
	}
	defer listener.Close()

	packetCh := make(chan []byte, 1)
	errorCh := make(chan error, 1)
	go func() {
		buffer := make([]byte, 2048)
		if err := listener.SetReadDeadline(time.Now().Add(2 * time.Second)); err != nil {
			errorCh <- err
			return
		}
		count, _, err := listener.ReadFromUDP(buffer)
		if err != nil {
			errorCh <- err
			return
		}
		packetCh <- append([]byte(nil), buffer[:count]...)
	}()

	executor := NewExecutor(log.New(io.Discard, "", 0))
	if err := executor.WakeOnLAN(WakeTarget{
		MAC:       "01:23:45:67:89:AB",
		Broadcast: "127.0.0.1",
		Port:      listener.LocalAddr().(*net.UDPAddr).Port,
	}); err != nil {
		t.Fatalf("WakeOnLAN() error = %v", err)
	}

	select {
	case err := <-errorCh:
		t.Fatalf("listener error = %v", err)
	case packet := <-packetCh:
		expected, err := magicPacket("01:23:45:67:89:AB")
		if err != nil {
			t.Fatalf("magicPacket() error = %v", err)
		}
		if string(packet) != string(expected) {
			t.Fatalf("packet mismatch")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("timed out waiting for wake packet")
	}
}
