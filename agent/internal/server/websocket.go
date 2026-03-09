package server

import (
	"context"
	"net/http"

	"github.com/gorilla/websocket"
	"openremote/agent/internal/plugins"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(_ *http.Request) bool {
		return true
	},
}

func (a *Application) handleWebSocket(writer http.ResponseWriter, request *http.Request) {
	device, ok := a.authorizer.AuthenticateWebSocket(request)
	if !ok {
		writeJSON(writer, http.StatusUnauthorized, map[string]any{
			"error": "missing or invalid access token",
		})
		return
	}

	conn, err := upgrader.Upgrade(writer, request, nil)
	if err != nil {
		a.logger.Printf("websocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	a.logger.Printf("websocket connected device=%s", device.Name)

	for {
		var command plugins.Command
		if err := conn.ReadJSON(&command); err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				a.logger.Printf("websocket closed unexpectedly: %v", err)
			}
			return
		}

		if command.Type == "" && command.Name == "" {
			_ = conn.WriteJSON(map[string]any{
				"type":  "error",
				"error": "command type or name is required",
			})
			continue
		}

		if err := a.registry.Execute(context.Background(), command); err != nil {
			_ = conn.WriteJSON(map[string]any{
				"type":    "error",
				"command": command.CommandName(),
				"error":   err.Error(),
			})
			continue
		}

		_ = conn.WriteJSON(map[string]any{
			"type":      "ack",
			"device_id": device.ID,
			"command":   command.CommandName(),
		})
	}
}
