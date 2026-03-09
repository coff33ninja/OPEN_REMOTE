package server

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"openremote/agent/internal/config"
	"openremote/agent/internal/discovery"
	"openremote/agent/internal/pairing"
	internalplugins "openremote/agent/internal/plugins"
	"openremote/agent/internal/system"
	pluginkeyboard "openremote/agent/plugins/keyboard"
	pluginmacro "openremote/agent/plugins/macro"
	pluginmedia "openremote/agent/plugins/media"
	pluginmouse "openremote/agent/plugins/mouse"
	pluginpresentation "openremote/agent/plugins/presentation"
	pluginvolume "openremote/agent/plugins/volume"
)

func TestPairingCompleteIssuesToken(t *testing.T) {
	app, pairManager := newTestApplication(t)

	session, err := pairManager.CreateSession("127.0.0.1", 9876, "Agent", "_openremote._tcp", "/ws")
	if err != nil {
		t.Fatalf("CreateSession() error = %v", err)
	}

	body := jsonBody(t, map[string]any{
		"device_name":   "Test Phone",
		"pairing_token": session.Token,
	})

	request := httptest.NewRequest(http.MethodPost, "/api/v1/pairing/complete", body)
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("status = %d, want %d body=%s", response.Code, http.StatusCreated, response.Body.String())
	}

	var payload map[string]any
	if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil {
		t.Fatalf("Unmarshal() error = %v", err)
	}
	if payload["access_token"] == "" {
		t.Fatalf("payload access_token = %#v, want non-empty", payload["access_token"])
	}
}

func TestFileUploadStoresBytesAndListsFiles(t *testing.T) {
	app, _ := newTestApplication(t)
	token := authorizeTestToken(t, app.authorizer)

	body := jsonBody(t, map[string]any{
		"name":        "hello.txt",
		"base64_data": base64.StdEncoding.EncodeToString([]byte("hello world")),
	})
	request := httptest.NewRequest(http.MethodPost, "/api/v1/files/upload", body)
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("upload status = %d, want %d body=%s", response.Code, http.StatusCreated, response.Body.String())
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/api/v1/files", nil)
	listRequest.Header.Set("Authorization", "Bearer "+token)
	listResponse := httptest.NewRecorder()
	app.routes().ServeHTTP(listResponse, listRequest)

	if listResponse.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d body=%s", listResponse.Code, http.StatusOK, listResponse.Body.String())
	}
	if !strings.Contains(listResponse.Body.String(), "hello.txt") {
		t.Fatalf("list body = %s, want uploaded file name", listResponse.Body.String())
	}
}

func TestFilesystemEndpointListsEntries(t *testing.T) {
	app, _ := newTestApplication(t)
	token := authorizeTestToken(t, app.authorizer)

	request := httptest.NewRequest(http.MethodGet, "/api/v1/filesystem", nil)
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", response.Code, http.StatusOK, response.Body.String())
	}
}

func TestProcessesEndpointListsProcesses(t *testing.T) {
	app, _ := newTestApplication(t)
	token := authorizeTestToken(t, app.authorizer)

	request := httptest.NewRequest(http.MethodGet, "/api/v1/processes", nil)
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", response.Code, http.StatusOK, response.Body.String())
	}
}

func TestCommandsEndpointExecutesMacro(t *testing.T) {
	app, _ := newTestApplication(t)
	token := authorizeTestToken(t, app.authorizer)

	body := jsonBody(t, map[string]any{
		"name": "macro_run",
		"arguments": map[string]any{
			"steps": []any{
				map[string]any{
					"name": "mouse_move",
					"arguments": map[string]any{
						"dx": 0,
						"dy": 0,
					},
				},
				map[string]any{
					"name": "mouse_move",
					"arguments": map[string]any{
						"dx": 0,
						"dy": 0,
					},
				},
			},
		},
	})

	request := httptest.NewRequest(http.MethodPost, "/api/v1/commands", body)
	request.Header.Set("Authorization", "Bearer "+token)
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, request)

	if response.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want %d body=%s", response.Code, http.StatusAccepted, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "macro_run") {
		t.Fatalf("body = %s, want macro ack", response.Body.String())
	}
}

func newTestApplication(t *testing.T) (*Application, *pairing.Manager) {
	t.Helper()

	root := t.TempDir()
	cfg := config.Config{
		AppName:       "OpenRemote Test",
		DeviceName:    "Test Agent",
		ListenAddress: "127.0.0.1",
		PublicHost:    "127.0.0.1",
		Port:          9876,
		PairingTTL:    2 * time.Minute,
		PairingScheme: "openremote",
		WebSocketPath: "/ws",
		ServiceType:   "_openremote._tcp",
		DataDir:       filepath.Join(root, "data"),
		RemotesDir:    filepath.Join(root, "remotes"),
		UploadsDir:    filepath.Join(root, "uploads"),
	}

	if err := os.MkdirAll(cfg.RemotesDir, 0o755); err != nil {
		t.Fatalf("MkdirAll(remotes) error = %v", err)
	}
	if err := os.WriteFile(filepath.Join(cfg.RemotesDir, "media.json"), []byte(`{"id":"media","name":"Media","category":"media","layout":[]}`), 0o644); err != nil {
		t.Fatalf("WriteFile(remote) error = %v", err)
	}

	logger := log.New(io.Discard, "", 0)
	executor := system.NewExecutor(logger)
	registry := internalplugins.NewRegistry(
		pluginmouse.New(executor),
		pluginkeyboard.New(executor),
		pluginmedia.New(executor),
		pluginvolume.New(executor),
		pluginpresentation.New(executor),
	)
	registry.Register(pluginmacro.New(registry.Execute))

	pairManager := pairing.NewManager(2*time.Minute, "openremote")
	authorizer, err := NewAuthorizer(filepath.Join(cfg.DataDir, "trusted-devices.json"))
	if err != nil {
		t.Fatalf("NewAuthorizer() error = %v", err)
	}

	return NewApplication(
		logger,
		cfg,
		registry,
		pairManager,
		authorizer,
		discovery.NewService(cfg, logger),
		executor,
	), pairManager
}

func authorizeTestToken(t *testing.T, authorizer *Authorizer) string {
	t.Helper()

	authorizer.mu.Lock()
	defer authorizer.mu.Unlock()

	device := TrustedDevice{
		ID:        "device-1",
		Name:      "Device 1",
		Token:     "token-1",
		LastSeen:  time.Now().UTC(),
		CreatedAt: time.Now().UTC(),
	}
	authorizer.devices[device.Token] = device
	if err := authorizer.persistLocked(); err != nil {
		t.Fatalf("persistLocked() error = %v", err)
	}
	return device.Token
}

func jsonBody(t *testing.T, value any) *bytes.Reader {
	t.Helper()

	blob, err := json.Marshal(value)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	return bytes.NewReader(blob)
}
