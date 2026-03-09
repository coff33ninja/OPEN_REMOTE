package mouse

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
	return "mouse"
}

func (p *Plugin) Name() string {
	return "Mouse"
}

func (p *Plugin) Manifest() internalplugins.Manifest {
	return internalplugins.Manifest{
		ID:          p.ID(),
		Name:        p.Name(),
		Category:    "input",
		Description: "Pointer movement and click actions",
		Commands:    []string{"mouse_move", "mouse_click"},
	}
}

func (p *Plugin) Supports(command internalplugins.Command) bool {
	name := command.CommandName()
	return name == "mouse_move" || name == "mouse_click"
}

func (p *Plugin) Execute(_ context.Context, command internalplugins.Command) error {
	switch command.CommandName() {
	case "mouse_move":
		return p.executor.MoveMouse(command.IntArg("dx", 0), command.IntArg("dy", 0))
	case "mouse_click":
		return p.executor.ClickMouse(command.StringArg("button", "left"))
	default:
		return fmt.Errorf("unsupported mouse command %q", command.CommandName())
	}
}
