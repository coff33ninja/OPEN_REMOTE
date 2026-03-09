package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
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
}

func Load() (Config, error) {
	hostname, err := os.Hostname()
	if err != nil || hostname == "" {
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

	return Config{
		AppName:       "OpenRemote Agent",
		DeviceName:    hostname,
		ListenAddress: envString("OPENREMOTE_LISTEN_ADDRESS", "0.0.0.0"),
		PublicHost:    envString("OPENREMOTE_PUBLIC_HOST", hostname),
		Port:          port,
		PairingTTL:    pairingTTL,
		PairingScheme: envString("OPENREMOTE_PAIRING_SCHEME", "openremote"),
		WebSocketPath: envString("OPENREMOTE_WEBSOCKET_PATH", "/ws"),
		ServiceType:   envString("OPENREMOTE_SERVICE_TYPE", "_openremote._tcp"),
		DataDir:       envString("OPENREMOTE_DATA_DIR", "data"),
		RemotesDir:    envString("OPENREMOTE_REMOTES_DIR", filepath.Clean(filepath.Join("..", "remotes"))),
		PluginsDir:    envString("OPENREMOTE_PLUGINS_DIR", filepath.Clean(filepath.Join("..", "plugins"))),
		UploadsDir:    envString("OPENREMOTE_UPLOADS_DIR", filepath.Clean(filepath.Join("data", "uploads"))),
		OpenPairingUI: envBool("OPENREMOTE_OPEN_PAIRING_UI", false),
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
