package server

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"net/url"
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

	session, err := pairManager.CreateSession(
		"127.0.0.1",
		9876,
		"Agent",
		"_openremote._tcp",
		"/ws",
		"",
		"",
		0,
		nil,
	)
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

func TestRootRedirectsToPairPage(t *testing.T) {
	app, _ := newTestApplication(t)

	request := httptest.NewRequest(http.MethodGet, "/", nil)
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, request)

	if response.Code != http.StatusTemporaryRedirect {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusTemporaryRedirect)
	}
	if location := response.Header().Get("Location"); location != "/pair" {
		t.Fatalf("location = %q, want %q", location, "/pair")
	}
}

func TestPairingPageRendersHTML(t *testing.T) {
	app, _ := newTestApplication(t)

	request := httptest.NewRequest(http.MethodGet, "/pair", nil)
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", response.Code, http.StatusOK, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "Pair Test Agent") {
		t.Fatalf("body = %s, want pairing heading", response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "Device Manager") {
		t.Fatalf("body = %s, want updated pairing instructions", response.Body.String())
	}
	if !strings.Contains(response.Header().Get("Content-Type"), "text/html") {
		t.Fatalf("content-type = %s, want text/html", response.Header().Get("Content-Type"))
	}
}

func TestPairingPageTrailingSlashRendersHTML(t *testing.T) {
	app, _ := newTestApplication(t)

	request := httptest.NewRequest(http.MethodGet, "/pair/", nil)
	response := httptest.NewRecorder()
	app.routes().ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d body=%s", response.Code, http.StatusOK, response.Body.String())
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

func TestFileUploadSupportsTargetDirectoryAndFilesystemActions(t *testing.T) {
	app, _ := newTestApplication(t)
	token := authorizeTestToken(t, app.authorizer)

	workspace := filepath.Join(filepath.Dir(app.config.UploadsDir), "workspace")
	if err := os.MkdirAll(workspace, 0o755); err != nil {
		t.Fatalf("MkdirAll(workspace) error = %v", err)
	}

	createFolderBody := jsonBody(t, map[string]any{
		"parent_path": workspace,
		"name":        "docs",
	})
	createFolderRequest := httptest.NewRequest(http.MethodPost, "/api/v1/filesystem/folder", createFolderBody)
	createFolderRequest.Header.Set("Authorization", "Bearer "+token)
	createFolderResponse := httptest.NewRecorder()
	app.routes().ServeHTTP(createFolderResponse, createFolderRequest)

	if createFolderResponse.Code != http.StatusCreated {
		t.Fatalf("create folder status = %d, want %d body=%s", createFolderResponse.Code, http.StatusCreated, createFolderResponse.Body.String())
	}

	docsPath := filepath.Join(workspace, "docs")
	uploadBody := jsonBody(t, map[string]any{
		"name":        "notes.txt",
		"base64_data": base64.StdEncoding.EncodeToString([]byte("alpha file")),
		"target_dir":  docsPath,
	})
	uploadRequest := httptest.NewRequest(http.MethodPost, "/api/v1/files/upload", uploadBody)
	uploadRequest.Header.Set("Authorization", "Bearer "+token)
	uploadResponse := httptest.NewRecorder()
	app.routes().ServeHTTP(uploadResponse, uploadRequest)

	if uploadResponse.Code != http.StatusCreated {
		t.Fatalf("target upload status = %d, want %d body=%s", uploadResponse.Code, http.StatusCreated, uploadResponse.Body.String())
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/api/v1/filesystem?path="+url.QueryEscape(docsPath), nil)
	listRequest.Header.Set("Authorization", "Bearer "+token)
	listResponse := httptest.NewRecorder()
	app.routes().ServeHTTP(listResponse, listRequest)

	if listResponse.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d body=%s", listResponse.Code, http.StatusOK, listResponse.Body.String())
	}
	if !strings.Contains(listResponse.Body.String(), "notes.txt") {
		t.Fatalf("list body = %s, want uploaded file name", listResponse.Body.String())
	}

	downloadRequest := httptest.NewRequest(http.MethodGet, "/api/v1/filesystem/download?path="+url.QueryEscape(filepath.Join(docsPath, "notes.txt")), nil)
	downloadRequest.Header.Set("Authorization", "Bearer "+token)
	downloadResponse := httptest.NewRecorder()
	app.routes().ServeHTTP(downloadResponse, downloadRequest)

	if downloadResponse.Code != http.StatusOK {
		t.Fatalf("download status = %d, want %d body=%s", downloadResponse.Code, http.StatusOK, downloadResponse.Body.String())
	}
	if body := downloadResponse.Body.String(); body != "alpha file" {
		t.Fatalf("download body = %q, want %q", body, "alpha file")
	}

	copyBody := jsonBody(t, map[string]any{
		"source_path":      filepath.Join(docsPath, "notes.txt"),
		"destination_path": filepath.Join(docsPath, "notes-copy.txt"),
	})
	copyRequest := httptest.NewRequest(http.MethodPost, "/api/v1/filesystem/copy", copyBody)
	copyRequest.Header.Set("Authorization", "Bearer "+token)
	copyResponse := httptest.NewRecorder()
	app.routes().ServeHTTP(copyResponse, copyRequest)

	if copyResponse.Code != http.StatusCreated {
		t.Fatalf("copy status = %d, want %d body=%s", copyResponse.Code, http.StatusCreated, copyResponse.Body.String())
	}

	moveBody := jsonBody(t, map[string]any{
		"source_path":      filepath.Join(docsPath, "notes-copy.txt"),
		"destination_path": filepath.Join(workspace, "notes-moved.txt"),
	})
	moveRequest := httptest.NewRequest(http.MethodPost, "/api/v1/filesystem/move", moveBody)
	moveRequest.Header.Set("Authorization", "Bearer "+token)
	moveResponse := httptest.NewRecorder()
	app.routes().ServeHTTP(moveResponse, moveRequest)

	if moveResponse.Code != http.StatusOK {
		t.Fatalf("move status = %d, want %d body=%s", moveResponse.Code, http.StatusOK, moveResponse.Body.String())
	}

	renameBody := jsonBody(t, map[string]any{
		"path":     filepath.Join(workspace, "notes-moved.txt"),
		"new_name": "notes-final.txt",
	})
	renameRequest := httptest.NewRequest(http.MethodPost, "/api/v1/filesystem/rename", renameBody)
	renameRequest.Header.Set("Authorization", "Bearer "+token)
	renameResponse := httptest.NewRecorder()
	app.routes().ServeHTTP(renameResponse, renameRequest)

	if renameResponse.Code != http.StatusOK {
		t.Fatalf("rename status = %d, want %d body=%s", renameResponse.Code, http.StatusOK, renameResponse.Body.String())
	}

	deleteBody := jsonBody(t, map[string]any{
		"path": filepath.Join(workspace, "notes-final.txt"),
	})
	deleteRequest := httptest.NewRequest(http.MethodPost, "/api/v1/filesystem/delete", deleteBody)
	deleteRequest.Header.Set("Authorization", "Bearer "+token)
	deleteResponse := httptest.NewRecorder()
	app.routes().ServeHTTP(deleteResponse, deleteRequest)

	if deleteResponse.Code != http.StatusOK {
		t.Fatalf("delete status = %d, want %d body=%s", deleteResponse.Code, http.StatusOK, deleteResponse.Body.String())
	}

	if _, err := os.Stat(filepath.Join(workspace, "notes-final.txt")); !os.IsNotExist(err) {
		t.Fatalf("Stat(notes-final.txt) error = %v, want not exists", err)
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
	executor.ConfigureWakeTarget("127.0.0.1", system.WakeTarget{
		MAC:       "AA:BB:CC:DD:EE:FF",
		Broadcast: "127.0.0.1",
		Port:      9,
	})
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
		discovery.NewService(cfg, logger, executor.WakeTarget()),
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
