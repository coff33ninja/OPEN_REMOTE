package server

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"openremote/agent/internal/pairing"
)

type TrustedDevice struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Token     string    `json:"token"`
	LastSeen  time.Time `json:"last_seen"`
	CreatedAt time.Time `json:"created_at"`
}

type Authorizer struct {
	mu      sync.Mutex
	path    string
	devices map[string]TrustedDevice
}

func NewAuthorizer(path string) (*Authorizer, error) {
	authorizer := &Authorizer{
		path:    path,
		devices: make(map[string]TrustedDevice),
	}

	if err := authorizer.load(); err != nil {
		return nil, err
	}

	return authorizer, nil
}

func (a *Authorizer) ExchangePairingToken(pairingManager *pairing.Manager, pairingToken string, deviceName string) (TrustedDevice, error) {
	if deviceName == "" {
		return TrustedDevice{}, fmt.Errorf("device name is required")
	}

	if !pairingManager.Consume(pairingToken) {
		return TrustedDevice{}, fmt.Errorf("pairing token is invalid or expired")
	}

	deviceID, err := randomHex(8)
	if err != nil {
		return TrustedDevice{}, err
	}

	accessToken, err := randomHex(16)
	if err != nil {
		return TrustedDevice{}, err
	}

	now := time.Now().UTC()
	device := TrustedDevice{
		ID:        deviceID,
		Name:      deviceName,
		Token:     accessToken,
		LastSeen:  now,
		CreatedAt: now,
	}

	a.mu.Lock()
	defer a.mu.Unlock()

	a.devices[device.Token] = device
	if err := a.persistLocked(); err != nil {
		return TrustedDevice{}, err
	}

	return device, nil
}

func (a *Authorizer) Authenticate(request *http.Request) (TrustedDevice, bool) {
	token := bearerToken(request)
	if token == "" {
		return TrustedDevice{}, false
	}

	return a.AuthenticateToken(token)
}

func (a *Authorizer) AuthenticateWebSocket(request *http.Request) (TrustedDevice, bool) {
	queryToken := strings.TrimSpace(request.URL.Query().Get("access_token"))
	if queryToken != "" {
		return a.AuthenticateToken(queryToken)
	}

	return a.Authenticate(request)
}

func (a *Authorizer) AuthenticateToken(token string) (TrustedDevice, bool) {
	a.mu.Lock()
	defer a.mu.Unlock()

	device, ok := a.devices[token]
	if !ok {
		return TrustedDevice{}, false
	}

	device.LastSeen = time.Now().UTC()
	a.devices[token] = device
	_ = a.persistLocked()

	return device, true
}

func bearerToken(request *http.Request) string {
	header := strings.TrimSpace(request.Header.Get("Authorization"))
	if !strings.HasPrefix(header, "Bearer ") {
		return ""
	}

	return strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
}

func (a *Authorizer) ListDevices() []TrustedDevice {
	a.mu.Lock()
	defer a.mu.Unlock()

	devices := make([]TrustedDevice, 0, len(a.devices))
	for _, device := range a.devices {
		devices = append(devices, device)
	}

	return devices
}

func (a *Authorizer) load() error {
	if err := os.MkdirAll(filepath.Dir(a.path), 0o755); err != nil {
		return err
	}

	blob, err := os.ReadFile(a.path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}

		return err
	}

	var devices []TrustedDevice
	if err := json.Unmarshal(blob, &devices); err != nil {
		return err
	}

	for _, device := range devices {
		a.devices[device.Token] = device
	}

	return nil
}

func (a *Authorizer) persistLocked() error {
	devices := make([]TrustedDevice, 0, len(a.devices))
	for _, device := range a.devices {
		devices = append(devices, device)
	}

	blob, err := json.MarshalIndent(devices, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(a.path, blob, 0o644)
}

func randomHex(size int) (string, error) {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}

	return hex.EncodeToString(buf), nil
}
