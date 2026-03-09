package server

import (
	"strings"

	"openremote/agent/internal/pairing"
	"openremote/agent/internal/system"
)

func buildPairingNetworks(primaryHost string, paths []system.NetworkPath) []pairing.Network {
	networks := make([]pairing.Network, 0, len(paths)+1)
	seenHosts := make(map[string]struct{}, len(paths)+1)

	addNetwork := func(path system.NetworkPath) {
		trimmedHost := strings.TrimSpace(path.Host)
		if trimmedHost == "" {
			return
		}

		dedupeKey := strings.ToLower(trimmedHost)
		if _, exists := seenHosts[dedupeKey]; exists {
			return
		}
		seenHosts[dedupeKey] = struct{}{}

		network := pairing.Network{
			Name:         path.Name,
			FriendlyName: firstNonEmpty(path.FriendlyName, path.Name),
			Description:  path.Description,
			Kind:         path.Kind,
			Host:         trimmedHost,
			IsVirtual:    path.IsVirtual,
			Preferred:    path.Preferred,
		}
		if path.WakeTarget != nil && path.WakeTarget.Valid() {
			network.WakeMAC = path.WakeTarget.MAC
			network.WakeBroadcast = path.WakeTarget.Broadcast
			network.WakePort = path.WakeTarget.Port
		}
		networks = append(networks, network)
	}

	addConfiguredHost := func(host string) {
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
			Name:         "Configured host",
			FriendlyName: "Configured host",
			Description:  "Fallback host configured on the desktop agent",
			Kind:         "configured",
			Host:         trimmedHost,
			Preferred:    true,
		}
		networks = append(networks, network)
	}

	for _, path := range paths {
		if strings.EqualFold(strings.TrimSpace(path.Host), strings.TrimSpace(primaryHost)) {
			addNetwork(path)
		}
	}
	for _, path := range paths {
		if strings.EqualFold(strings.TrimSpace(path.Host), strings.TrimSpace(primaryHost)) {
			continue
		}
		addNetwork(path)
	}

	addConfiguredHost(primaryHost)
	return networks
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed != "" {
			return trimmed
		}
	}

	return ""
}
