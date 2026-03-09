package system

import (
	"net"
	"slices"
	"strings"
)

type NetworkPath struct {
	Name       string
	Host       string
	WakeTarget *WakeTarget
}

func LocalNetworkPaths(preferredHost string, explicit WakeTarget) ([]NetworkPath, error) {
	normalizedExplicit, err := normalizeWakeTarget(explicit)
	if err != nil {
		return nil, err
	}

	interfaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}

	paths := make([]NetworkPath, 0, len(interfaces))
	seenHosts := make(map[string]struct{}, len(interfaces))
	for _, iface := range interfaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		addresses, err := iface.Addrs()
		if err != nil {
			continue
		}

		for _, address := range addresses {
			network, ok := address.(*net.IPNet)
			if !ok {
				continue
			}

			ip := network.IP.To4()
			if ip == nil || ip.IsLoopback() || ip.IsUnspecified() || ip.IsLinkLocalUnicast() {
				continue
			}

			host := ip.String()
			dedupeKey := strings.ToLower(strings.TrimSpace(host))
			if _, exists := seenHosts[dedupeKey]; exists {
				continue
			}
			seenHosts[dedupeKey] = struct{}{}

			path := NetworkPath{
				Name: iface.Name,
				Host: host,
			}
			if wakeTarget, ok := wakeTargetForInterface(iface, network, normalizedExplicit); ok {
				copy := wakeTarget
				path.WakeTarget = &copy
			}

			paths = append(paths, path)
		}
	}

	slices.SortFunc(paths, func(left NetworkPath, right NetworkPath) int {
		leftPreferred := equalFoldTrimmed(left.Host, preferredHost)
		rightPreferred := equalFoldTrimmed(right.Host, preferredHost)
		if leftPreferred != rightPreferred {
			if leftPreferred {
				return -1
			}
			return 1
		}

		leftWake := left.WakeTarget != nil && left.WakeTarget.Valid()
		rightWake := right.WakeTarget != nil && right.WakeTarget.Valid()
		if leftWake != rightWake {
			if leftWake {
				return -1
			}
			return 1
		}

		if nameCompare := strings.Compare(strings.ToLower(left.Name), strings.ToLower(right.Name)); nameCompare != 0 {
			return nameCompare
		}

		return strings.Compare(left.Host, right.Host)
	})

	return paths, nil
}

func wakeTargetForInterface(iface net.Interface, network *net.IPNet, explicit WakeTarget) (WakeTarget, bool) {
	ip := network.IP.To4()
	if ip == nil {
		return WakeTarget{}, false
	}
	if len(iface.HardwareAddr) == 0 || iface.Flags&net.FlagBroadcast == 0 {
		return WakeTarget{}, false
	}

	target := WakeTarget{
		MAC:       strings.ToUpper(iface.HardwareAddr.String()),
		Broadcast: directedBroadcast(ip, network.Mask),
		Port:      defaultWakePort,
	}
	if explicit.Valid() {
		target.MAC = explicit.MAC
	}
	if explicit.Broadcast != "" {
		target.Broadcast = explicit.Broadcast
	}
	if explicit.Port > 0 {
		target.Port = explicit.Port
	}

	normalized, err := normalizeWakeTarget(target)
	if err != nil || !normalized.Valid() {
		return WakeTarget{}, false
	}

	return normalized, true
}

func equalFoldTrimmed(left string, right string) bool {
	return strings.EqualFold(strings.TrimSpace(left), strings.TrimSpace(right))
}
