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
		Description: "Text input commands",
		Commands:    []string{"keyboard_type"},
	}
}

func (p *Plugin) Supports(command internalplugins.Command) bool {
	return command.CommandName() == "keyboard_type"
}

func (p *Plugin) Execute(_ context.Context, command internalplugins.Command) error {
	if command.CommandName() != "keyboard_type" {
		return fmt.Errorf("unsupported keyboard command %q", command.CommandName())
	}

	return p.executor.TypeText(command.StringArg("text", ""))
}
