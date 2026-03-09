package pairing

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

type Session struct {
	Token         string    `json:"token"`
	URI           string    `json:"uri"`
	Host          string    `json:"host"`
	Port          int       `json:"port"`
	DeviceName    string    `json:"device"`
	Service       string    `json:"service"`
	WebSocketPath string    `json:"ws_path"`
	ExpiresAt     time.Time `json:"expires_at"`
}

type Manager struct {
	mu       sync.Mutex
	ttl      time.Duration
	scheme   string
	sessions map[string]time.Time
}

func NewManager(ttl time.Duration, scheme string) *Manager {
	return &Manager{
		ttl:      ttl,
		scheme:   scheme,
		sessions: make(map[string]time.Time),
	}
}

func (m *Manager) CreateSession(host string, port int, deviceName string, service string, wsPath string) (Session, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	token, err := randomHex(8)
	if err != nil {
		return Session{}, err
	}

	expiresAt := time.Now().UTC().Add(m.ttl)
	payload := map[string]any{
		"host":    host,
		"port":    port,
		"token":   token,
		"device":  deviceName,
		"service": service,
		"ws_path": wsPath,
	}

	encoded, err := encodePayload(payload)
	if err != nil {
		return Session{}, err
	}

	m.sessions[token] = expiresAt

	return Session{
		Token:         token,
		URI:           fmt.Sprintf("%s://pair?data=%s", m.scheme, encoded),
		Host:          host,
		Port:          port,
		DeviceName:    deviceName,
		Service:       service,
		WebSocketPath: wsPath,
		ExpiresAt:     expiresAt,
	}, nil
}

func (m *Manager) Consume(token string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	expiresAt, ok := m.sessions[token]
	if !ok {
		return false
	}

	delete(m.sessions, token)
	if time.Now().UTC().After(expiresAt) {
		return false
	}

	return true
}

func (m *Manager) PurgeExpired() int {
	m.mu.Lock()
	defer m.mu.Unlock()

	now := time.Now().UTC()
	removed := 0
	for token, expiresAt := range m.sessions {
		if now.After(expiresAt) {
			delete(m.sessions, token)
			removed++
		}
	}

	return removed
}

func encodePayload(payload map[string]any) (string, error) {
	blob, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	return base64.RawURLEncoding.EncodeToString(blob), nil
}

func randomHex(size int) (string, error) {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}

	return hex.EncodeToString(buf), nil
}
