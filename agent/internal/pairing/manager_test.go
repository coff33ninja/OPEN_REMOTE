package pairing

import (
	"encoding/base64"
	"encoding/json"
	"net/url"
	"reflect"
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
		[]Network{
			{
				Name:          "Wi-Fi",
				Host:          "192.168.1.50",
				WakeMAC:       "AA:BB:CC:DD:EE:FF",
				WakeBroadcast: "192.168.1.255",
				WakePort:      9,
			},
			{
				Name: "Tailscale",
				Host: "100.64.0.10",
			},
		},
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
	if len(session.Networks) != 2 {
		t.Fatalf("len(Networks) = %d, want %d", len(session.Networks), 2)
	}

	uri, err := url.Parse(session.URI)
	if err != nil {
		t.Fatalf("url.Parse() error = %v", err)
	}
	encoded := uri.Query().Get("data")
	decoded, err := base64.RawURLEncoding.DecodeString(encoded)
	if err != nil {
		t.Fatalf("DecodeString() error = %v", err)
	}

	var payload struct {
		Networks []Network `json:"networks"`
	}
	if err := json.Unmarshal(decoded, &payload); err != nil {
		t.Fatalf("Unmarshal() error = %v", err)
	}
	if !reflect.DeepEqual(payload.Networks, session.Networks) {
		t.Fatalf("payload networks = %#v, want %#v", payload.Networks, session.Networks)
	}
	if !manager.Consume(session.Token) {
		t.Fatal("Consume() = false, want true on first use")
	}
	if manager.Consume(session.Token) {
		t.Fatal("Consume() = true, want false on reused token")
	}
}
