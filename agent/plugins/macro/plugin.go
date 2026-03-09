package macro

import (
	"context"
	"fmt"
	"strings"

	internalplugins "openremote/agent/internal/plugins"
)

type Runner func(context.Context, internalplugins.Command) error

type Plugin struct {
	run Runner
}

func New(run Runner) *Plugin {
	return &Plugin{run: run}
}

func (p *Plugin) ID() string {
	return "macro"
}

func (p *Plugin) Name() string {
	return "Macro"
}

func (p *Plugin) Manifest() internalplugins.Manifest {
	return internalplugins.Manifest{
		ID:          p.ID(),
		Name:        p.Name(),
		Category:    "automation",
		Description: "Execute multi-step command macros",
		Commands:    []string{"macro_run"},
	}
}

func (p *Plugin) Supports(command internalplugins.Command) bool {
	return command.CommandName() == "macro_run"
}

func (p *Plugin) Execute(ctx context.Context, command internalplugins.Command) error {
	stepsValue, ok := command.Arguments["steps"]
	if !ok {
		return fmt.Errorf("macro_run requires steps")
	}

	steps, ok := stepsValue.([]any)
	if !ok || len(steps) == 0 {
		return fmt.Errorf("macro_run steps must be a non-empty array")
	}

	for _, raw := range steps {
		stepMap, ok := raw.(map[string]any)
		if !ok {
			return fmt.Errorf("macro_run step must be an object")
		}

		stepCommand, err := decodeStep(stepMap, command.RemoteID)
		if err != nil {
			return err
		}

		if stepCommand.CommandName() == "macro_run" {
			return fmt.Errorf("nested macro_run is not allowed")
		}

		if err := p.run(ctx, stepCommand); err != nil {
			return fmt.Errorf("macro step %q failed: %w", stepCommand.CommandName(), err)
		}
	}

	return nil
}

func decodeStep(raw map[string]any, remoteID string) (internalplugins.Command, error) {
	command := internalplugins.Command{
		RemoteID:  remoteID,
		Arguments: map[string]any{},
	}

	if name, ok := raw["name"].(string); ok && name != "" {
		command.Name = name
	}
	if cmd, ok := raw["cmd"].(string); ok && cmd != "" && command.Name == "" {
		command.Name = cmd
	}
	if commandType, ok := raw["type"].(string); ok && commandType != "" {
		command.Type = commandType
	}
	if action, ok := raw["action"].(string); ok && action != "" {
		command.Action = action
	}
	if arguments, ok := raw["arguments"].(map[string]any); ok {
		command.Arguments = arguments
	}

	for key, value := range raw {
		switch key {
		case "name", "cmd", "type", "action", "arguments":
			continue
		default:
			command.Arguments[key] = value
		}
	}

	if command.Type == "" && command.Name != "" {
		parts := strings.Split(command.Name, "_")
		command.Type = parts[0]
		if len(parts) > 1 {
			command.Action = strings.Join(parts[1:], "_")
		}
	}

	if command.Type == "" && command.Name == "" {
		return internalplugins.Command{}, fmt.Errorf("macro step requires type or name")
	}

	return command, nil
}
