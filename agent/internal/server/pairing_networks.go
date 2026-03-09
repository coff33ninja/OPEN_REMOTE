package server

import (
	"strings"

	"openremote/agent/internal/pairing"
	"openremote/agent/internal/system"
)

func buildPairingNetworks(primaryHost string, paths []system.NetworkPath) []pairing.Network {
	networks := make([]pairing.Network, 0, len(paths)+1)
	seenHosts := make(map[string]struct{}, len(paths)+1)

	addNetwork := func(name string, host string, wakeTarget *system.WakeTarget) {
		trimmedHost := strings.TrimSpace(host)
		if trimmedHost == "" {
			return
		}

		dedupeKey := strings.ToLower(trimmedHost)
		if _, exists := seenHosts[dedupeKey]; exists {
			return
		}
		seenHosts[dedupeKey] = struct{}{}

		network := pairing.Network{
			Name: name,
			Host: trimmedHost,
		}
		if wakeTarget != nil && wakeTarget.Valid() {
			network.WakeMAC = wakeTarget.MAC
			network.WakeBroadcast = wakeTarget.Broadcast
			network.WakePort = wakeTarget.Port
		}
		networks = append(networks, network)
	}

	for _, path := range paths {
		if strings.EqualFold(strings.TrimSpace(path.Host), strings.TrimSpace(primaryHost)) {
			addNetwork(path.Name, path.Host, path.WakeTarget)
		}
	}
	for _, path := range paths {
		if strings.EqualFold(strings.TrimSpace(path.Host), strings.TrimSpace(primaryHost)) {
			continue
		}
		addNetwork(path.Name, path.Host, path.WakeTarget)
	}

	addNetwork("Configured host", primaryHost, nil)
	return networks
}
