//go:build windows

package system

import "testing"

func TestParseAdapterMetadataJSONParsesArray(t *testing.T) {
	metadata, err := parseAdapterMetadataJSON([]byte(`[
		{
			"ifIndex": 7,
			"Name": "Wi-Fi",
			"InterfaceAlias": "Wi-Fi",
			"InterfaceDescription": "Intel(R) Wi-Fi 6 AX201 160MHz",
			"Virtual": false,
			"HardwareInterface": true,
			"MediaType": "Native 802.11",
			"PhysicalMediaType": "Native 802.11"
		},
		{
			"ifIndex": 12,
			"Name": "Tailscale",
			"InterfaceAlias": "Tailscale",
			"InterfaceDescription": "Tailscale Tunnel",
			"Virtual": true,
			"HardwareInterface": false,
			"MediaType": "802.3",
			"PhysicalMediaType": "Unspecified"
		}
	]`))
	if err != nil {
		t.Fatalf("parseAdapterMetadataJSON() error = %v", err)
	}

	if got := metadata[7]; got.Kind != "wifi" || got.FriendlyName != "Wi-Fi" || got.IsVirtual {
		t.Fatalf("metadata[7] = %#v, want wifi non-virtual adapter metadata", got)
	}
	if got := metadata[12]; got.Kind != "vpn" || !got.IsVirtual {
		t.Fatalf("metadata[12] = %#v, want vpn virtual adapter metadata", got)
	}
}

func TestParseAdapterMetadataJSONParsesSingleObject(t *testing.T) {
	metadata, err := parseAdapterMetadataJSON([]byte(`{
		"ifIndex": 21,
		"Name": "Ethernet",
		"InterfaceAlias": "Ethernet 2",
		"InterfaceDescription": "Realtek PCIe GbE Family Controller",
		"Virtual": false,
		"HardwareInterface": true,
		"MediaType": "802.3",
		"PhysicalMediaType": "802.3"
	}`))
	if err != nil {
		t.Fatalf("parseAdapterMetadataJSON() error = %v", err)
	}

	got := metadata[21]
	if got.Kind != "ethernet" {
		t.Fatalf("metadata[21].Kind = %q, want %q", got.Kind, "ethernet")
	}
	if got.FriendlyName != "Ethernet 2" {
		t.Fatalf("metadata[21].FriendlyName = %q, want %q", got.FriendlyName, "Ethernet 2")
	}
	if got.Description == "" {
		t.Fatalf("metadata[21].Description is empty")
	}
}
