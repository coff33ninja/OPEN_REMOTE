package system

import "testing"

func TestClassifyInterface(t *testing.T) {
	testCases := []struct {
		name        string
		wantKind    string
		wantVirtual bool
	}{
		{name: "Wi-Fi", wantKind: "wifi", wantVirtual: false},
		{name: "Ethernet", wantKind: "ethernet", wantVirtual: false},
		{name: "Tailscale", wantKind: "vpn", wantVirtual: true},
		{name: "vEthernet (Default Switch)", wantKind: "virtual", wantVirtual: true},
		{name: "USB 10/100/1000 LAN", wantKind: "usb", wantVirtual: false},
		{name: "Unknown Adapter", wantKind: "unknown", wantVirtual: false},
	}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			gotKind, gotDescription, gotVirtual := classifyInterface(testCase.name)
			if gotKind != testCase.wantKind {
				t.Fatalf("classifyInterface(%q) kind = %q, want %q", testCase.name, gotKind, testCase.wantKind)
			}
			if gotVirtual != testCase.wantVirtual {
				t.Fatalf("classifyInterface(%q) virtual = %t, want %t", testCase.name, gotVirtual, testCase.wantVirtual)
			}
			if gotDescription == "" {
				t.Fatalf("classifyInterface(%q) description is empty", testCase.name)
			}
		})
	}
}
