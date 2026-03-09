package config

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	AppName       string
	DeviceName    string
	ListenAddress string
	PublicHost    string
	Port          int
	PairingTTL    time.Duration
	PairingScheme string
	WebSocketPath string
	ServiceType   string
	DataDir       string
	RemotesDir    string
	PluginsDir    string
	UploadsDir    string
	OpenPairingUI bool
	WakeMAC       string
	WakeBroadcast string
	WakePort      int
}

func Load() (Config, error) {
	hostname, err := os.Hostname()
	if err != nil || strings.TrimSpace(hostname) == "" {
		hostname = "OpenRemote-PC"
	}

	port, err := envInt("OPENREMOTE_PORT", 9876)
	if err != nil {
		return Config{}, err
	}

	pairingTTL, err := envDuration("OPENREMOTE_PAIRING_TTL", 2*time.Minute)
	if err != nil {
		return Config{}, err
	}

	wakePort, err := envInt("OPENREMOTE_WOL_PORT", 9)
	if err != nil {
		return Config{}, err
	}

	return Config{
		AppName:       "OpenRemote Agent",
		DeviceName:    envString("OPENREMOTE_DEVICE_NAME", hostname),
		ListenAddress: envString("OPENREMOTE_LISTEN_ADDRESS", "0.0.0.0"),
		PublicHost:    envString("OPENREMOTE_PUBLIC_HOST", defaultPublicHost(hostname)),
		Port:          port,
		PairingTTL:    pairingTTL,
		PairingScheme: envString("OPENREMOTE_PAIRING_SCHEME", "openremote"),
		WebSocketPath: envString("OPENREMOTE_WEBSOCKET_PATH", "/ws"),
		ServiceType:   envString("OPENREMOTE_SERVICE_TYPE", "_openremote._tcp"),
		DataDir:       envString("OPENREMOTE_DATA_DIR", "data"),
		RemotesDir:    resolveAssetDir("OPENREMOTE_REMOTES_DIR", "remotes"),
		PluginsDir:    resolveAssetDir("OPENREMOTE_PLUGINS_DIR", "plugins"),
		UploadsDir:    envString("OPENREMOTE_UPLOADS_DIR", filepath.Clean(filepath.Join("data", "uploads"))),
		OpenPairingUI: envBool("OPENREMOTE_OPEN_PAIRING_UI", false),
		WakeMAC:       envString("OPENREMOTE_WOL_MAC", ""),
		WakeBroadcast: envString("OPENREMOTE_WOL_BROADCAST", ""),
		WakePort:      wakePort,
	}, nil
}

func envString(name string, fallback string) string {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}

	return value
}

func envInt(name string, fallback int) (int, error) {
	raw := os.Getenv(name)
	if raw == "" {
		return fallback, nil
	}

	value, err := strconv.Atoi(raw)
	if err != nil {
		return 0, fmt.Errorf("%s must be an integer: %w", name, err)
	}

	return value, nil
}

func envDuration(name string, fallback time.Duration) (time.Duration, error) {
	raw := os.Getenv(name)
	if raw == "" {
		return fallback, nil
	}

	value, err := time.ParseDuration(raw)
	if err != nil {
		return 0, fmt.Errorf("%s must be a duration: %w", name, err)
	}

	return value, nil
}

func envBool(name string, fallback bool) bool {
	raw := os.Getenv(name)
	if raw == "" {
		return fallback
	}

	switch raw {
	case "1", "true", "TRUE", "yes", "YES", "on", "ON":
		return true
	case "0", "false", "FALSE", "no", "NO", "off", "OFF":
		return false
	default:
		return fallback
	}
}

func resolveAssetDir(envName string, assetName string) string {
	if value := os.Getenv(envName); value != "" {
		return filepath.Clean(value)
	}

	for _, candidate := range assetDirCandidates(assetName) {
		info, err := os.Stat(candidate)
		if err == nil && info.IsDir() {
			return candidate
		}
	}

	candidates := assetDirCandidates(assetName)
	if len(candidates) == 0 {
		return filepath.Clean(assetName)
	}

	return candidates[0]
}

func assetDirCandidates(assetName string) []string {
	candidates := make([]string, 0, 8)
	addBase := func(base string) {
		if strings.TrimSpace(base) == "" {
			return
		}

		candidates = append(
			candidates,
			filepath.Clean(filepath.Join(base, assetName)),
			filepath.Clean(filepath.Join(base, "..", assetName)),
			filepath.Clean(filepath.Join(base, "..", "..", assetName)),
		)
	}

	if workingDir, err := os.Getwd(); err == nil {
		addBase(workingDir)
	}
	if executablePath, err := os.Executable(); err == nil {
		addBase(filepath.Dir(executablePath))
	}

	seen := make(map[string]struct{}, len(candidates))
	unique := make([]string, 0, len(candidates))
	for _, candidate := range candidates {
		if _, ok := seen[candidate]; ok {
			continue
		}
		seen[candidate] = struct{}{}
		unique = append(unique, candidate)
	}

	return unique
}

func defaultPublicHost(hostname string) string {
	if ip := outboundIPv4(); ip != "" {
		return ip
	}
	if ip := firstActiveIPv4(); ip != "" {
		return ip
	}
	return hostname
}

func outboundIPv4() string {
	connection, err := net.Dial("udp4", "8.8.8.8:80")
	if err != nil {
		return ""
	}
	defer connection.Close()

	address, ok := connection.LocalAddr().(*net.UDPAddr)
	if !ok || address.IP == nil {
		return ""
	}

	ip := address.IP.To4()
	if ip == nil || ip.IsLoopback() || ip.IsUnspecified() {
		return ""
	}

	return ip.String()
}

func firstActiveIPv4() string {
	interfaces, err := net.Interfaces()
	if err != nil {
		return ""
	}

	var fallback string
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
			if isPrivateIPv4(ip) {
				return ip.String()
			}
			if fallback == "" {
				fallback = ip.String()
			}
		}
	}

	return fallback
}

func isPrivateIPv4(ip net.IP) bool {
	ipv4 := ip.To4()
	if ipv4 == nil {
		return false
	}

	switch {
	case ipv4[0] == 10:
		return true
	case ipv4[0] == 172 && ipv4[1] >= 16 && ipv4[1] <= 31:
		return true
	case ipv4[0] == 192 && ipv4[1] == 168:
		return true
	default:
		return false
	}
}
