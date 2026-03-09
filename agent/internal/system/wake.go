package system

import (
	"bytes"
	"fmt"
	"net"
	"slices"
	"strings"
)

const defaultWakePort = 9

type WakeTarget struct {
	MAC       string `json:"mac"`
	Broadcast string `json:"broadcast"`
	Port      int    `json:"port"`
}

type wakeCandidate struct {
	ip     string
	target WakeTarget
}

func (t WakeTarget) Valid() bool {
	return strings.TrimSpace(t.MAC) != ""
}

func (e *Executor) ConfigureWakeTarget(preferredHost string, explicit WakeTarget) {
	target, err := resolveWakeTarget(preferredHost, explicit)
	if err != nil {
		e.logger.Printf("wake target unavailable: %v", err)
		return
	}

	e.mu.Lock()
	e.wakeTarget = target
	e.mu.Unlock()
	e.logger.Printf(
		"wake target configured mac=%s broadcast=%s port=%d",
		target.MAC,
		target.Broadcast,
		target.Port,
	)
}

func (e *Executor) WakeTarget() WakeTarget {
	e.mu.Lock()
	defer e.mu.Unlock()

	return e.wakeTarget
}

func (e *Executor) WakeOnLAN(target WakeTarget) error {
	effectiveTarget, err := e.effectiveWakeTarget(target)
	if err != nil {
		return err
	}

	packet, err := magicPacket(effectiveTarget.MAC)
	if err != nil {
		return err
	}

	address := net.ParseIP(effectiveTarget.Broadcast)
	if address == nil {
		return fmt.Errorf("invalid wake broadcast %q", effectiveTarget.Broadcast)
	}

	connection, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4zero, Port: 0})
	if err != nil {
		return err
	}
	defer connection.Close()

	if err := enableBroadcast(connection); err != nil {
		return err
	}

	if _, err := connection.WriteToUDP(packet, &net.UDPAddr{
		IP:   address,
		Port: effectiveTarget.Port,
	}); err != nil {
		return err
	}

	e.logger.Printf(
		"wake-on-lan sent mac=%s broadcast=%s port=%d",
		effectiveTarget.MAC,
		effectiveTarget.Broadcast,
		effectiveTarget.Port,
	)
	return nil
}

func (e *Executor) effectiveWakeTarget(requested WakeTarget) (WakeTarget, error) {
	if requested.Valid() {
		return normalizeWakeTarget(requested)
	}

	e.mu.Lock()
	defaultTarget := e.wakeTarget
	e.mu.Unlock()

	if !defaultTarget.Valid() {
		return WakeTarget{}, fmt.Errorf("wake target is not configured")
	}
	return normalizeWakeTarget(defaultTarget)
}

func resolveWakeTarget(preferredHost string, explicit WakeTarget) (WakeTarget, error) {
	normalizedExplicit, err := normalizeWakeTarget(explicit)
	if err != nil {
		return WakeTarget{}, err
	}
	if normalizedExplicit.Valid() && normalizedExplicit.Broadcast != "" {
		return normalizedExplicit, nil
	}

	candidates, err := localWakeCandidates()
	if err != nil {
		return WakeTarget{}, err
	}
	if len(candidates) == 0 {
		if normalizedExplicit.Valid() {
			normalizedExplicit.Broadcast = fallbackBroadcast(normalizedExplicit.Broadcast)
			return normalizedExplicit, nil
		}
		return WakeTarget{}, fmt.Errorf("no active interface with a hardware address was found")
	}

	selected := chooseWakeCandidate(candidates, preferredHost, normalizedExplicit.MAC)
	target := selected.target
	if normalizedExplicit.Valid() {
		target.MAC = normalizedExplicit.MAC
	}
	if normalizedExplicit.Broadcast != "" {
		target.Broadcast = normalizedExplicit.Broadcast
	}
	if normalizedExplicit.Port != 0 {
		target.Port = normalizedExplicit.Port
	}

	return normalizeWakeTarget(target)
}

func normalizeWakeTarget(target WakeTarget) (WakeTarget, error) {
	normalized := WakeTarget{
		MAC:       normalizeMAC(target.MAC),
		Broadcast: strings.TrimSpace(target.Broadcast),
		Port:      target.Port,
	}
	if normalized.Port <= 0 {
		normalized.Port = defaultWakePort
	}
	if normalized.MAC != "" {
		if _, err := net.ParseMAC(normalized.MAC); err != nil {
			return WakeTarget{}, fmt.Errorf("invalid wake mac %q: %w", target.MAC, err)
		}
	}
	normalized.Broadcast = fallbackBroadcast(normalized.Broadcast)
	return normalized, nil
}

func chooseWakeCandidate(candidates []wakeCandidate, preferredHost string, preferredMAC string) wakeCandidate {
	if normalizedMAC := normalizeMAC(preferredMAC); normalizedMAC != "" {
		for _, candidate := range candidates {
			if candidate.target.MAC == normalizedMAC {
				return candidate
			}
		}
	}

	if preferredIP := net.ParseIP(strings.TrimSpace(preferredHost)); preferredIP != nil {
		for _, candidate := range candidates {
			if candidate.ip == preferredIP.String() {
				return candidate
			}
		}
	}

	return candidates[0]
}

func localWakeCandidates() ([]wakeCandidate, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}

	candidates := make([]wakeCandidate, 0, len(interfaces))
	for _, iface := range interfaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		if len(iface.HardwareAddr) == 0 {
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
			if ip == nil || ip.IsLoopback() {
				continue
			}

			candidates = append(candidates, wakeCandidate{
				ip: ip.String(),
				target: WakeTarget{
					MAC:       strings.ToUpper(iface.HardwareAddr.String()),
					Broadcast: directedBroadcast(ip, network.Mask),
					Port:      defaultWakePort,
				},
			})
		}
	}

	slices.SortFunc(candidates, func(left wakeCandidate, right wakeCandidate) int {
		return strings.Compare(left.ip, right.ip)
	})
	return candidates, nil
}

func directedBroadcast(ip net.IP, mask net.IPMask) string {
	ipv4 := ip.To4()
	if ipv4 == nil || len(mask) < 4 {
		return "255.255.255.255"
	}

	broadcast := make(net.IP, len(ipv4))
	for i := range ipv4 {
		broadcast[i] = ipv4[i] | ^mask[i]
	}
	return broadcast.String()
}

func normalizeMAC(raw string) string {
	trimmed := strings.TrimSpace(strings.ToUpper(raw))
	if trimmed == "" {
		return ""
	}

	condensed := strings.NewReplacer("-", "", ":", "", ".", "").Replace(trimmed)
	if len(condensed) != 12 {
		return trimmed
	}

	var builder strings.Builder
	for index := 0; index < len(condensed); index += 2 {
		if index > 0 {
			builder.WriteByte(':')
		}
		builder.WriteString(condensed[index : index+2])
	}
	return builder.String()
}

func fallbackBroadcast(value string) string {
	if strings.TrimSpace(value) == "" {
		return "255.255.255.255"
	}
	return strings.TrimSpace(value)
}

func magicPacket(mac string) ([]byte, error) {
	hardwareAddress, err := net.ParseMAC(normalizeMAC(mac))
	if err != nil {
		return nil, err
	}
	if len(hardwareAddress) != 6 {
		return nil, fmt.Errorf("wake mac must be 6 bytes, got %d", len(hardwareAddress))
	}

	packet := bytes.Repeat([]byte{0xFF}, 6)
	for range 16 {
		packet = append(packet, hardwareAddress...)
	}
	return packet, nil
}
