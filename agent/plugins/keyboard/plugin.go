package keyboard

import (
	"context"
	"fmt"

	internalplugins "openremote/agent/internal/plugins"
	"openremote/agent/internal/system"
)

type Plugin struct {
	executor *system.Executor
}

func New(executor *system.Executor) *Plugin {
	return &Plugin{executor: executor}
}

func (p *Plugin) ID() string {
	return "keyboard"
}

func (p *Plugin) Name() string {
	return "Keyboard"
}

func (p *Plugin) Manifest() internalplugins.Manifest {
	return internalplugins.Manifest{
		ID:          p.ID(),
		Name:        p.Name(),
		Category:    "input",
		Description: "Text input, single-key, and shortcut commands",
		Commands: []string{
			"keyboard_type",
			"keyboard_press",
			"keyboard_key_down",
			"keyboard_key_up",
			"keyboard_shortcut",
		},
	}
}

func (p *Plugin) Supports(command internalplugins.Command) bool {
	switch command.CommandName() {
	case "keyboard_type", "keyboard_press", "keyboard_key_down", "keyboard_key_up", "keyboard_shortcut":
		return true
	default:
		return false
	}
}

func (p *Plugin) Execute(_ context.Context, command internalplugins.Command) error {
	switch command.CommandName() {
	case "keyboard_type":
		return p.executor.TypeText(command.StringArg("text", ""))
	case "keyboard_press":
		return p.executor.PressKey(command.StringArg("key", ""))
	case "keyboard_key_down":
		return p.executor.KeyDown(command.StringArg("key", ""))
	case "keyboard_key_up":
		return p.executor.KeyUp(command.StringArg("key", ""))
	case "keyboard_shortcut":
		return p.executor.Shortcut(command.StringSliceArg("keys"))
	default:
		return fmt.Errorf("unsupported keyboard command %q", command.CommandName())
	}
}
