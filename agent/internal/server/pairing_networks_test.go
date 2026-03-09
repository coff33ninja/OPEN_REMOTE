package server

import (
	"testing"

	"openremote/agent/internal/system"
)

func TestBuildPairingNetworksAddsConfiguredHostAndPerRouteWakeTargets(t *testing.T) {
	networks := buildPairingNetworks("100.64.0.10", []system.NetworkPath{
		{
			Name:         "Wi-Fi",
			FriendlyName: "Wi-Fi",
			Description:  "Wi-Fi adapter",
			Kind:         "wifi",
			Host:         "192.168.1.50",
			WakeTarget: &system.WakeTarget{
				MAC:       "AA:BB:CC:DD:EE:FF",
				Broadcast: "192.168.1.255",
				Port:      9,
			},
		},
		{
			Name:         "Tailscale",
			FriendlyName: "Tailscale",
			Description:  "Tailscale VPN tunnel",
			Kind:         "vpn",
			Host:         "100.64.0.10",
			IsVirtual:    true,
			Preferred:    true,
		},
	})

	if len(networks) != 2 {
		t.Fatalf("len(networks) = %d, want %d", len(networks), 2)
	}
	if networks[0].Host != "100.64.0.10" {
		t.Fatalf("networks[0].Host = %q, want %q", networks[0].Host, "100.64.0.10")
	}
	if networks[0].WakeMAC != "" {
		t.Fatalf("networks[0].WakeMAC = %q, want empty", networks[0].WakeMAC)
	}
	if networks[0].Kind != "vpn" {
		t.Fatalf("networks[0].Kind = %q, want %q", networks[0].Kind, "vpn")
	}
	if !networks[0].Preferred {
		t.Fatal("networks[0].Preferred = false, want true")
	}
	if networks[1].Host != "192.168.1.50" {
		t.Fatalf("networks[1].Host = %q, want %q", networks[1].Host, "192.168.1.50")
	}
	if networks[1].WakeBroadcast != "192.168.1.255" {
		t.Fatalf(
			"networks[1].WakeBroadcast = %q, want %q",
			networks[1].WakeBroadcast,
			"192.168.1.255",
		)
	}
	if networks[1].Kind != "wifi" {
		t.Fatalf("networks[1].Kind = %q, want %q", networks[1].Kind, "wifi")
	}
}
