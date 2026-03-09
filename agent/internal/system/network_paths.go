package system

import (
	"net"
	"slices"
	"strings"
)

type NetworkPath struct {
	Name         string
	FriendlyName string
	Description  string
	Kind         string
	Host         string
	IsVirtual    bool
	Preferred    bool
	WakeTarget   *WakeTarget
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

	adapterMetadataByIndex, err := loadAdapterMetadata()
	if err != nil {
		adapterMetadataByIndex = map[int]adapterMetadata{}
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

			metadata := adapterMetadataByIndex[iface.Index]
			kind, description, isVirtual := describeInterface(iface.Name, metadata)
			path := NetworkPath{
				Name:         iface.Name,
				FriendlyName: firstNonEmpty(metadata.FriendlyName, strings.TrimSpace(iface.Name)),
				Description:  description,
				Kind:         kind,
				Host:         host,
				IsVirtual:    isVirtual,
				Preferred:    equalFoldTrimmed(host, preferredHost),
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

func classifyInterface(name string) (kind string, description string, isVirtual bool) {
	return classifyInterfaceWithSignals(name, "", false)
}

func describeInterface(name string, metadata adapterMetadata) (kind string, description string, isVirtual bool) {
	if metadata.Kind != "" {
		return metadata.Kind, firstNonEmpty(metadata.Description, "Network adapter"), metadata.IsVirtual
	}

	return classifyInterfaceWithSignals(name, metadata.Description, metadata.IsVirtual)
}

func classifyInterfaceWithSignals(name string, details string, isVirtualHint bool) (kind string, description string, isVirtual bool) {
	normalized := strings.ToLower(strings.TrimSpace(strings.Join([]string{name, details}, " ")))

	switch {
	case containsAny(normalized, "tailscale"):
		return "vpn", "Tailscale VPN tunnel", true
	case containsAny(
		normalized,
		"wireguard",
		"wintun",
		"zerotier",
		"vpn",
		"openvpn",
		"tun",
		"tap",
		"ppp",
		"ipsec",
		"hamachi",
		"cisco anyconnect",
	):
		return "vpn", "VPN or overlay tunnel", true
	case containsAny(normalized, "wi-fi", "wifi", "wlan", "wireless", "802.11"):
		return "wifi", "Wi-Fi adapter", false
	case containsAny(normalized, "wwan", "cellular", "mobile broadband"),
		strings.Contains(normalized, " lte "),
		strings.HasPrefix(normalized, "lte "),
		strings.Contains(normalized, "(lte)"):
		return "wifi", "Wireless network adapter", false
	case containsAny(normalized, "usb"):
		return "usb", "USB network adapter", false
	case isVirtualHint:
		return "virtual", "Virtual network adapter", true
	case containsAny(
		normalized,
		"docker",
		"hyper-v",
		"vethernet",
		"vmware",
		"virtualbox",
		"vbox",
		"bridge",
		"virtual",
		"loopback",
	):
		return "virtual", "Virtual network adapter", true
	case strings.HasPrefix(normalized, "eth"), containsAny(normalized, "ethernet", "gigabit", "lan", "802.3"):
		return "ethernet", "Ethernet adapter", false
	default:
		return "unknown", "Network adapter", false
	}
}

func containsAny(value string, needles ...string) bool {
	for _, needle := range needles {
		if strings.Contains(value, needle) {
			return true
		}
	}

	return false
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
