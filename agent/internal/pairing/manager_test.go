package pairing

import (
	"testing"
	"time"
)

func TestCreateAndConsumeSession(t *testing.T) {
	manager := NewManager(2*time.Minute, "openremote")

	session, err := manager.CreateSession(
		"127.0.0.1",
		9876,
		"Workstation",
		"_openremote._tcp",
		"/ws",
		"AA:BB:CC:DD:EE:FF",
		"192.168.1.255",
		9,
	)
	if err != nil {
		t.Fatalf("CreateSession() error = %v", err)
	}

	if session.Token == "" || session.URI == "" {
		t.Fatalf("CreateSession() returned empty token or uri: %#v", session)
	}
	if session.WakeMAC != "AA:BB:CC:DD:EE:FF" {
		t.Fatalf("WakeMAC = %q, want %q", session.WakeMAC, "AA:BB:CC:DD:EE:FF")
	}
	if !manager.Consume(session.Token) {
		t.Fatal("Consume() = false, want true on first use")
	}
	if manager.Consume(session.Token) {
		t.Fatal("Consume() = true, want false on reused token")
	}
}
