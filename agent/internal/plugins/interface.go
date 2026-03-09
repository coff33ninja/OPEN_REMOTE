package plugins

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
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

func (c Command) StringSliceArg(name string) []string {
	value, ok := c.Arguments[name]
	if !ok || value == nil {
		return nil
	}

	switch typed := value.(type) {
	case []string:
		return append([]string(nil), typed...)
	case []any:
		values := make([]string, 0, len(typed))
		for _, item := range typed {
			switch concrete := item.(type) {
			case string:
				if trimmed := strings.TrimSpace(concrete); trimmed != "" {
					values = append(values, trimmed)
				}
			case json.Number:
				values = append(values, concrete.String())
			default:
				values = append(values, fmt.Sprint(concrete))
			}
		}
		return values
	case string:
		if strings.TrimSpace(typed) == "" {
			return nil
		}
		parts := strings.Split(typed, ",")
		values := make([]string, 0, len(parts))
		for _, part := range parts {
			if trimmed := strings.TrimSpace(part); trimmed != "" {
				values = append(values, trimmed)
			}
		}
		return values
	default:
		return nil
	}
}
