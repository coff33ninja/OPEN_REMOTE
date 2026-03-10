package server

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"
)

type clientLogEntry struct {
	Level     string         `json:"level"`
	Message   string         `json:"message"`
	Error     string         `json:"error,omitempty"`
	Stack     string         `json:"stack,omitempty"`
	Screen    string         `json:"screen,omitempty"`
	Action    string         `json:"action,omitempty"`
	Context   map[string]any `json:"context,omitempty"`
	CreatedAt string         `json:"created_at,omitempty"`
}

type clientLogRecord struct {
	ReceivedAt time.Time      `json:"received_at"`
	DeviceID   string         `json:"device_id"`
	DeviceName string         `json:"device_name"`
	Level      string         `json:"level"`
	Message    string         `json:"message"`
	Error      string         `json:"error,omitempty"`
	Stack      string         `json:"stack,omitempty"`
	Screen     string         `json:"screen,omitempty"`
	Action     string         `json:"action,omitempty"`
	Context    map[string]any `json:"context,omitempty"`
	CreatedAt  string         `json:"created_at,omitempty"`
}

func (a *Application) handleClientLogs(writer http.ResponseWriter, request *http.Request) {
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

	request.Body = http.MaxBytesReader(writer, request.Body, 64*1024)
	defer request.Body.Close()

	var payload clientLogEntry
	if err := json.NewDecoder(request.Body).Decode(&payload); err != nil {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "invalid log payload",
		})
		return
	}
	if strings.TrimSpace(payload.Message) == "" {
		writeJSON(writer, http.StatusBadRequest, map[string]any{
			"error": "message is required",
		})
		return
	}

	record := clientLogRecord{
		ReceivedAt: time.Now().UTC(),
		DeviceID:   device.ID,
		DeviceName: device.Name,
		Level:      strings.TrimSpace(payload.Level),
		Message:    strings.TrimSpace(payload.Message),
		Error:      strings.TrimSpace(payload.Error),
		Stack:      strings.TrimSpace(payload.Stack),
		Screen:     strings.TrimSpace(payload.Screen),
		Action:     strings.TrimSpace(payload.Action),
		Context:    payload.Context,
		CreatedAt:  strings.TrimSpace(payload.CreatedAt),
	}
	if record.Level == "" {
		record.Level = "error"
	}

	if blob, err := json.Marshal(record); err == nil {
		a.clientLogger.Printf("%s", blob)
	} else {
		a.clientLogger.Printf(
			"client log level=%s device=%s message=%s error=%s",
			record.Level,
			record.DeviceName,
			record.Message,
			record.Error,
		)
	}

	writeJSON(writer, http.StatusAccepted, map[string]any{
		"status": "accepted",
	})
}
