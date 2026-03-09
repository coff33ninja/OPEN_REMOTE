package server

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/skip2/go-qrcode"
	"openremote/agent/internal/config"
	"openremote/agent/internal/discovery"
	"openremote/agent/internal/pairing"
	"openremote/agent/internal/plugins"
	"openremote/agent/internal/system"
)

type Application struct {
	logger     *log.Logger
	config     config.Config
	registry   *plugins.Registry
	pairing    *pairing.Manager
	authorizer *Authorizer
	discovery  *discovery.Service
	executor   *system.Executor
}

func NewApplication(
	logger *log.Logger,
	cfg config.Config,
	registry *plugins.Registry,
	pairingManager *pairing.Manager,
	authorizer *Authorizer,
	discoveryService *discovery.Service,
	executor *system.Executor,
) *Application {
	return &Application{
		logger:     logger,
		config:     cfg,
		registry:   registry,
		pairing:    pairingManager,
		authorizer: authorizer,
		discovery:  discoveryService,
		executor:   executor,
	}
}

func (a *Application) ListenAndServe(ctx context.Context) error {
	go func() {
		if err := a.discovery.Start(ctx); err != nil {
			a.logger.Printf("discovery error: %v", err)
		}
	}()

	server := &http.Server{
		Addr:              net.JoinHostPort(a.config.ListenAddress, strconv.Itoa(a.config.Port)),
		Handler:           a.routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
	}()

	if a.config.OpenPairingUI {
		go func() {
			time.Sleep(900 * time.Millisecond)
			if err := openBrowser(pairingPageURL(a.config.Port)); err != nil {
				a.logger.Printf("pairing ui open error: %v", err)
			}
		}()
	}

	a.logger.Printf("http server listening on %s", server.Addr)
	return server.ListenAndServe()
}

func (a *Application) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/", a.handleIndex)
	mux.HandleFunc("/healthz", a.handleHealth)
	mux.HandleFunc("/pair", a.handlePairingPage)
	mux.HandleFunc("/pair/", a.handlePairingPage)
	mux.HandleFunc("/api/v1/meta", a.handleMeta)
	mux.HandleFunc("/api/v1/plugins", a.handlePlugins)
	mux.HandleFunc("/api/v1/remotes/catalog", a.handleRemotes)
	mux.HandleFunc("/api/v1/remotes/", a.handleRemoteDocument)
	mux.HandleFunc("/api/v1/filesystem", a.handleFilesystem)
	mux.HandleFunc("/api/v1/filesystem/download", a.handleFileDownload)
	mux.HandleFunc("/api/v1/filesystem/open", a.handleFilesystemOpen)
	mux.HandleFunc("/api/v1/filesystem/folder", a.handleCreateFolder)
	mux.HandleFunc("/api/v1/filesystem/rename", a.handleRenameEntry)
	mux.HandleFunc("/api/v1/filesystem/delete", a.handleDeleteEntry)
	mux.HandleFunc("/api/v1/filesystem/move", a.handleMoveEntry)
	mux.HandleFunc("/api/v1/filesystem/copy", a.handleCopyEntry)
	mux.HandleFunc("/api/v1/pairing/session", a.handlePairingSession)
	mux.HandleFunc("/api/v1/pairing/qr.png", a.handlePairingQRCode)
	mux.HandleFunc("/api/v1/pairing/complete", a.handlePairingComplete)
	mux.HandleFunc("/api/v1/files/upload", a.handleFileUpload)
	mux.HandleFunc("/api/v1/files", a.handleFilesList)
	mux.HandleFunc("/api/v1/processes", a.handleProcesses)
	mux.HandleFunc("/api/v1/processes/terminate", a.handleTerminateProcess)
	mux.HandleFunc("/api/v1/commands", a.handleCommands)
	mux.HandleFunc(a.config.WebSocketPath, a.handleWebSocket)

	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		mux.ServeHTTP(writer, request)
	})
}

func (a *Application) handleIndex(writer http.ResponseWriter, request *http.Request) {
	if request.URL.Path != "/" {
		http.NotFound(writer, request)
		return
	}

	http.Redirect(writer, request, "/pair", http.StatusTemporaryRedirect)
}

func (a *Application) handleHealth(writer http.ResponseWriter, _ *http.Request) {
	writeJSON(writer, http.StatusOK, map[string]any{
		"status":     "ok",
		"service":    a.config.AppName,
		"device":     a.config.DeviceName,
		"checked_at": time.Now().UTC(),
	})
}

func (a *Application) handleMeta(writer http.ResponseWriter, _ *http.Request) {
	networks := a.availablePairingNetworks()

	payload := map[string]any{
		"app_name":       a.config.AppName,
		"device_name":    a.config.DeviceName,
		"host":           a.config.PublicHost,
		"public_host":    a.config.PublicHost,
		"port":           a.config.Port,
		"websocket_path": a.config.WebSocketPath,
		"service_type":   a.config.ServiceType,
		"discovery":      a.discovery.Descriptor(),
		"networks":       networks,
	}
	if wakeTarget := a.executor.WakeTarget(); wakeTarget.Valid() {
		payload["wake_target"] = map[string]any{
			"mac":       wakeTarget.MAC,
			"broadcast": wakeTarget.Broadcast,
			"port":      wakeTarget.Port,
		}
	}

	writeJSON(writer, http.StatusOK, payload)
}

func (a *Application) handlePlugins(writer http.ResponseWriter, _ *http.Request) {
	writeJSON(writer, http.StatusOK, map[string]any{
		"plugins": a.registry.Manifests(),
	})
}

func (a *Application) handleRemotes(writer http.ResponseWriter, _ *http.Request) {
	entries, err := os.ReadDir(a.config.RemotesDir)
	if err != nil {
		writeJSON(writer, http.StatusInternalServerError, map[string]any{
			"error": err.Error(),
		})
		return
	}

	remotes := make([]map[string]string, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}

		summary, err := a.readRemoteSummary(entry.Name())
		if err != nil {
			continue
		}

		remotes = append(remotes, summary)
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"remotes": remotes,
	})
}

func (a *Application) handleRemoteDocument(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	name := filepath.Base(strings.TrimPrefix(request.URL.Path, "/api/v1/remotes/"))
	if name == "." || name == "" || name == "catalog" {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "remote name is required",
		})
		return
	}

	if !strings.HasSuffix(name, ".json") {
		name += ".json"
	}

	fullPath := filepath.Join(a.config.RemotesDir, name)
	blob, err := os.ReadFile(fullPath)
	if err != nil {
		writeJSON(writer, http.StatusNotFound, map[string]any{
			"error": "remote not found",
		})
		return
	}

	writer.Header().Set("Content-Type", "application/json")
	writer.WriteHeader(http.StatusOK)
	_, _ = writer.Write(blob)
}

func (a *Application) handlePairingSession(writer http.ResponseWriter, _ *http.Request) {
	session, err := a.newPairingSession()
	if err != nil {
		writeJSON(writer, http.StatusInternalServerError, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusOK, session)
}

func (a *Application) handlePairingQRCode(writer http.ResponseWriter, request *http.Request) {
	size := 256
	if raw := request.URL.Query().Get("size"); raw != "" {
		parsed, parseErr := strconv.Atoi(raw)
		if parseErr == nil && parsed >= 128 && parsed <= 1024 {
			size = parsed
		}
	}

	session, png, err := a.newPairingQRCode(size)
	if err != nil {
		writeJSON(writer, http.StatusInternalServerError, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writer.Header().Set("Content-Type", "image/png")
	writer.Header().Set("X-OpenRemote-Pairing-URI", session.URI)
	writer.Header().Set("X-OpenRemote-Pairing-Token", session.Token)
	writer.Header().Set("X-OpenRemote-Expires-At", session.ExpiresAt.Format(time.RFC3339))
	writer.WriteHeader(http.StatusOK)
	_, _ = writer.Write(png)
}

func (a *Application) handlePairingPage(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	session, png, err := a.newPairingQRCode(320)
	if err != nil {
		writeJSON(writer, http.StatusInternalServerError, map[string]any{
			"error": err.Error(),
		})
		return
	}

	const pairingPage = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OpenRemote Pairing</title>
  <style>
    :root { color-scheme: light; }
    body {
      margin: 0;
      font-family: "Segoe UI", sans-serif;
      background: linear-gradient(180deg, #f7f3ea 0%, #efe1bf 100%);
      color: #1b1f23;
    }
    .shell {
      max-width: 780px;
      margin: 0 auto;
      padding: 32px 20px 48px;
    }
    .card {
      background: rgba(255,255,255,0.92);
      border-radius: 28px;
      padding: 24px;
      box-shadow: 0 20px 60px rgba(27, 31, 35, 0.12);
    }
    h1 { margin: 0 0 12px; font-size: 36px; }
    p { line-height: 1.5; }
    .grid {
      display: grid;
      grid-template-columns: minmax(240px, 320px) 1fr;
      gap: 24px;
      align-items: start;
    }
    img {
      width: 100%;
      display: block;
      border-radius: 24px;
      background: white;
      padding: 16px;
      box-sizing: border-box;
    }
    code {
      display: block;
      padding: 14px 16px;
      background: #111827;
      color: #f9fafb;
      border-radius: 16px;
      overflow-wrap: anywhere;
    }
    .meta { color: #6b7280; font-size: 14px; margin-top: 12px; }
    .actions { margin-top: 20px; display: flex; gap: 12px; flex-wrap: wrap; }
    button, a.button {
      appearance: none;
      border: none;
      background: #b45309;
      color: white;
      padding: 12px 18px;
      border-radius: 999px;
      font: inherit;
      cursor: pointer;
      text-decoration: none;
    }
    a.secondary {
      background: transparent;
      color: #1b1f23;
      border: 1px solid #d1d5db;
    }
    ol { padding-left: 18px; }
    @media (max-width: 720px) {
      .grid { grid-template-columns: 1fr; }
      h1 { font-size: 28px; }
    }
  </style>
</head>
<body>
  <div class="shell">
    <div class="card">
      <h1>Pair {{.DeviceName}}</h1>
      <p>Scan this code from the OpenRemote Android app or paste the URI manually. The session expires at {{.ExpiresAt}}.</p>
      <div class="grid">
        <div>
          <img alt="OpenRemote pairing QR code" src="data:image/png;base64,{{.QRCodeBase64}}">
        </div>
        <div>
          <p><strong>Pair URI</strong></p>
          <code>{{.URI}}</code>
          <div class="meta">Host: {{.Host}}:{{.Port}} • WebSocket: {{.WebSocketPath}}</div>
          <div class="actions">
            <button onclick="window.location.reload()">Refresh QR</button>
            <a class="button secondary" href="/api/v1/pairing/session">View session JSON</a>
          </div>
          <ol>
            <li>Open the Android app.</li>
            <li>Open the menu, then go to <strong>Device Manager</strong>.</li>
            <li>Tap <strong>Scan and pair</strong> or paste the pairing URI manually.</li>
            <li>Scan this pairing code to trust the desktop and connect.</li>
          </ol>
        </div>
      </div>
    </div>
  </div>
</body>
</html>`

	view := struct {
		DeviceName    string
		URI           string
		ExpiresAt     string
		QRCodeBase64  string
		Host          string
		Port          int
		WebSocketPath string
	}{
		DeviceName:    a.config.DeviceName,
		URI:           session.URI,
		ExpiresAt:     session.ExpiresAt.Format(time.RFC1123),
		QRCodeBase64:  base64.StdEncoding.EncodeToString(png),
		Host:          a.config.PublicHost,
		Port:          a.config.Port,
		WebSocketPath: a.config.WebSocketPath,
	}

	writer.Header().Set("Content-Type", "text/html; charset=utf-8")
	writer.WriteHeader(http.StatusOK)
	_ = template.Must(template.New("pairing-page").Parse(pairingPage)).Execute(writer, view)
}

func (a *Application) newPairingSession() (pairing.Session, error) {
	wakeTarget := a.executor.WakeTarget()

	return a.pairing.CreateSession(
		a.config.PublicHost,
		a.config.Port,
		a.config.DeviceName,
		a.config.ServiceType,
		a.config.WebSocketPath,
		wakeTarget.MAC,
		wakeTarget.Broadcast,
		wakeTarget.Port,
		a.availablePairingNetworks(),
	)
}

func (a *Application) newPairingQRCode(size int) (pairing.Session, []byte, error) {
	session, err := a.newPairingSession()
	if err != nil {
		return pairing.Session{}, nil, err
	}

	png, err := qrcode.Encode(session.URI, qrcode.Medium, size)
	if err != nil {
		return pairing.Session{}, nil, err
	}

	return session, png, nil
}

func (a *Application) handlePairingComplete(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	var input struct {
		DeviceName   string `json:"device_name"`
		PairingToken string `json:"pairing_token"`
	}

	if err := json.NewDecoder(request.Body).Decode(&input); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid pairing payload",
		})
		return
	}

	device, err := a.authorizer.ExchangePairingToken(a.pairing, input.PairingToken, input.DeviceName)
	if err != nil {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusCreated, map[string]any{
		"device_id":    device.ID,
		"device_name":  device.Name,
		"access_token": device.Token,
		"created_at":   device.CreatedAt,
	})
}

func (a *Application) handleCommands(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	device, ok := a.authorizer.Authenticate(request)
	if !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	var command plugins.Command
	decoder := json.NewDecoder(request.Body)
	decoder.UseNumber()
	if err := decoder.Decode(&command); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid command payload",
		})
		return
	}

	if command.Type == "" && command.Name == "" {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "command type or name is required",
		})
		return
	}

	if err := a.registry.Execute(request.Context(), command); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusAccepted, map[string]any{
		"status":    "accepted",
		"device_id": device.ID,
		"command":   command.CommandName(),
	})
}

func (a *Application) handleFilesystem(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	target := request.URL.Query().Get("path")
	entries, err := a.executor.ListDirectory(target)
	if err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"path":    target,
		"entries": entries,
	})
}

func (a *Application) handleFileDownload(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	target := request.URL.Query().Get("path")
	blob, entry, err := a.executor.ReadFile(target)
	if err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	contentType := http.DetectContentType(blob)
	if contentType == "application/octet-stream" {
		contentType = "application/octet-stream"
	}

	writer.Header().Set("Content-Type", contentType)
	writer.Header().Set(
		"Content-Disposition",
		fmt.Sprintf("attachment; filename=%q", entry.Name),
	)
	writer.Header().Set("Content-Length", strconv.Itoa(len(blob)))
	writer.WriteHeader(http.StatusOK)
	_, _ = writer.Write(blob)
}

func (a *Application) handleFilesystemOpen(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	var input struct {
		Path string `json:"path"`
	}
	if err := json.NewDecoder(request.Body).Decode(&input); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid open payload",
		})
		return
	}
	if strings.TrimSpace(input.Path) == "" {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "path is required",
		})
		return
	}

	if err := a.executor.OpenPath(input.Path); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusAccepted, map[string]any{
		"status": "accepted",
		"path":   filepath.Clean(input.Path),
	})
}

func (a *Application) handleCreateFolder(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	var input struct {
		ParentPath string `json:"parent_path"`
		Name       string `json:"name"`
	}
	if err := json.NewDecoder(request.Body).Decode(&input); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid folder payload",
		})
		return
	}

	entry, err := a.executor.CreateDirectory(input.ParentPath, input.Name)
	if err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusCreated, map[string]any{
		"entry": entry,
	})
}

func (a *Application) handleRenameEntry(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	var input struct {
		Path    string `json:"path"`
		NewName string `json:"new_name"`
	}
	if err := json.NewDecoder(request.Body).Decode(&input); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid rename payload",
		})
		return
	}

	entry, err := a.executor.RenameEntry(input.Path, input.NewName)
	if err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"entry": entry,
	})
}

func (a *Application) handleDeleteEntry(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	var input struct {
		Path string `json:"path"`
	}
	if err := json.NewDecoder(request.Body).Decode(&input); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid delete payload",
		})
		return
	}
	if strings.TrimSpace(input.Path) == "" {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "path is required",
		})
		return
	}

	if err := a.executor.DeleteEntry(input.Path); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"status": "deleted",
		"path":   filepath.Clean(input.Path),
	})
}

func (a *Application) handleMoveEntry(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	var input struct {
		SourcePath      string `json:"source_path"`
		DestinationPath string `json:"destination_path"`
	}
	if err := json.NewDecoder(request.Body).Decode(&input); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid move payload",
		})
		return
	}

	entry, err := a.executor.MoveEntry(input.SourcePath, input.DestinationPath)
	if err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"entry": entry,
	})
}

func (a *Application) handleCopyEntry(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	var input struct {
		SourcePath      string `json:"source_path"`
		DestinationPath string `json:"destination_path"`
	}
	if err := json.NewDecoder(request.Body).Decode(&input); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid copy payload",
		})
		return
	}

	entry, err := a.executor.CopyEntry(input.SourcePath, input.DestinationPath)
	if err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusCreated, map[string]any{
		"entry": entry,
	})
}

func (a *Application) handleFilesList(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	entries, err := os.ReadDir(a.config.UploadsDir)
	if err != nil {
		if os.IsNotExist(err) {
			writeJSON(writer, http.StatusOK, map[string]any{"files": []any{}})
			return
		}
		writeJSON(writer, http.StatusInternalServerError, map[string]any{
			"error": err.Error(),
		})
		return
	}

	files := make([]map[string]any, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		files = append(files, map[string]any{
			"name":      entry.Name(),
			"size":      info.Size(),
			"modified":  info.ModTime().UTC(),
			"localPath": filepath.Join(a.config.UploadsDir, entry.Name()),
		})
	}

	writeJSON(writer, http.StatusOK, map[string]any{"files": files})
}

func (a *Application) handleFileUpload(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	var input struct {
		Name       string `json:"name"`
		Base64Data string `json:"base64_data"`
		TargetDir  string `json:"target_dir"`
	}
	if err := json.NewDecoder(request.Body).Decode(&input); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid upload payload",
		})
		return
	}
	if input.Name == "" || input.Base64Data == "" {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "name and base64_data are required",
		})
		return
	}

	blob, err := base64.StdEncoding.DecodeString(input.Base64Data)
	if err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "base64_data is invalid",
		})
		return
	}
	uploadRoot := a.config.UploadsDir
	if strings.TrimSpace(input.TargetDir) != "" {
		uploadRoot = filepath.Clean(input.TargetDir)
	}

	if err := os.MkdirAll(uploadRoot, 0o755); err != nil {
		writeJSON(writer, http.StatusInternalServerError, map[string]any{
			"error": err.Error(),
		})
		return
	}

	safeName := filepath.Base(input.Name)
	if safeName == "." || safeName == "" {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid file name",
		})
		return
	}

	targetPath := uniqueUploadPath(uploadRoot, safeName)
	if err := os.WriteFile(targetPath, blob, 0o644); err != nil {
		writeJSON(writer, http.StatusInternalServerError, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusCreated, map[string]any{
		"name":       filepath.Base(targetPath),
		"size":       len(blob),
		"saved_to":   targetPath,
		"created_at": time.Now().UTC(),
	})
}

func (a *Application) handleProcesses(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	processes, err := a.executor.ListProcesses()
	if err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"processes": processes,
	})
}

func (a *Application) handleTerminateProcess(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeJSON(writer, http.StatusMethodNotAllowed, map[string]any{
			"error": "method not allowed",
		})
		return
	}

	if _, ok := a.authorizer.Authenticate(request); !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid bearer token",
		})
		return
	}

	var input struct {
		PID int `json:"pid"`
	}
	if err := json.NewDecoder(request.Body).Decode(&input); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid process payload",
		})
		return
	}
	if input.PID <= 0 {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "pid must be greater than zero",
		})
		return
	}

	if err := a.executor.TerminateProcess(input.PID); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": err.Error(),
		})
		return
	}

	writeJSON(writer, http.StatusAccepted, map[string]any{
		"status": "accepted",
		"pid":    input.PID,
	})
}

func writeJSON(writer http.ResponseWriter, status int, value any) {
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(value)
}

func (a *Application) readRemoteSummary(name string) (map[string]string, error) {
	fullPath := filepath.Join(a.config.RemotesDir, name)
	blob, err := os.ReadFile(fullPath)
	if err != nil {
		return nil, err
	}

	var document struct {
		ID       string `json:"id"`
		Name     string `json:"name"`
		Category string `json:"category"`
	}
	if err := json.Unmarshal(blob, &document); err != nil {
		return nil, err
	}

	return map[string]string{
		"id":       document.ID,
		"name":     document.Name,
		"category": document.Category,
		"path":     "/api/v1/remotes/" + name,
	}, nil
}

func uniqueUploadPath(root string, fileName string) string {
	base := strings.TrimSuffix(fileName, filepath.Ext(fileName))
	ext := filepath.Ext(fileName)
	target := filepath.Join(root, fileName)
	if _, err := os.Stat(target); os.IsNotExist(err) {
		return target
	}

	for i := 1; ; i++ {
		candidate := filepath.Join(root, fmt.Sprintf("%s-%d%s", base, i, ext))
		if _, err := os.Stat(candidate); os.IsNotExist(err) {
			return candidate
		}
	}
}

func (a *Application) availablePairingNetworks() []pairing.Network {
	paths, err := system.LocalNetworkPaths(a.config.PublicHost, system.WakeTarget{
		MAC:       a.config.WakeMAC,
		Broadcast: a.config.WakeBroadcast,
		Port:      a.config.WakePort,
	})
	if err != nil {
		a.logger.Printf("pairing network discovery error: %v", err)
	}

	return buildPairingNetworks(a.config.PublicHost, paths)
}
