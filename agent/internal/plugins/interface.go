package plugins

import (
	"context"
	"encoding/json"
	"strconv"
)

type Command struct {
	RequestID string         `json:"request_id,omitempty"`
	RemoteID  string         `json:"remote_id,omitempty"`
	Type      string         `json:"type"`
	Action    string         `json:"action,omitempty"`
	Name      string         `json:"name,omitempty"`
	Arguments map[string]any `json:"arguments,omitempty"`
}

type Manifest struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Category    string   `json:"category"`
	Description string   `json:"description"`
	Commands    []string `json:"commands"`
}

type Plugin interface {
	ID() string
	Name() string
	Manifest() Manifest
	Supports(command Command) bool
	Execute(ctx context.Context, command Command) error
}

func (c Command) CommandName() string {
	if c.Name != "" {
		return c.Name
	}

	if c.Type != "" && c.Action != "" {
		return c.Type + "_" + c.Action
	}

	return c.Type
}

func (c Command) IntArg(name string, fallback int) int {
	value, ok := c.Arguments[name]
	if !ok {
		return fallback
	}

	switch typed := value.(type) {
	case int:
		return typed
	case int32:
		return int(typed)
	case int64:
		return int(typed)
	case float32:
		return int(typed)
	case float64:
		return int(typed)
	case json.Number:
		parsed, err := typed.Int64()
		if err == nil {
			return int(parsed)
		}
	case string:
		parsed, err := strconv.Atoi(typed)
		if err == nil {
			return parsed
		}
	}

	return fallback
}

func (c Command) StringArg(name string, fallback string) string {
	value, ok := c.Arguments[name]
	if !ok {
		return fallback
	}

	switch typed := value.(type) {
	case string:
		return typed
	case json.Number:
		return typed.String()
	}

	return fallback
}
