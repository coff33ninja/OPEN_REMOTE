package pairing

import (
	"testing"
	"time"
)

func TestCreateAndConsumeSession(t *testing.T) {
	manager := NewManager(2*time.Minute, "openremote")

	session, err := manager.CreateSession("127.0.0.1", 9876, "Workstation", "_openremote._tcp", "/ws")
	if err != nil {
		t.Fatalf("CreateSession() error = %v", err)
	}

	if session.Token == "" || session.URI == "" {
		t.Fatalf("CreateSession() returned empty token or uri: %#v", session)
	}
	if !manager.Consume(session.Token) {
		t.Fatal("Consume() = false, want true on first use")
	}
	if manager.Consume(session.Token) {
		t.Fatal("Consume() = true, want false on reused token")
	}
}
