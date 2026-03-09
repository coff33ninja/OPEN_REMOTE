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
		Description: "Pointer movement, click, hold, and scroll actions",
		Commands: []string{
			"mouse_move",
			"mouse_click",
			"mouse_double_click",
			"mouse_button_down",
			"mouse_button_up",
			"mouse_scroll",
		},
	}
}

func (p *Plugin) Supports(command internalplugins.Command) bool {
	name := command.CommandName()
	switch name {
	case "mouse_move", "mouse_click", "mouse_double_click", "mouse_button_down", "mouse_button_up", "mouse_scroll":
		return true
	default:
		return false
	}
}

func (p *Plugin) Execute(_ context.Context, command internalplugins.Command) error {
	switch command.CommandName() {
	case "mouse_move":
		return p.executor.MoveMouse(command.IntArg("dx", 0), command.IntArg("dy", 0))
	case "mouse_click":
		return p.executor.ClickMouse(command.StringArg("button", "left"))
	case "mouse_double_click":
		if err := p.executor.ClickMouse(command.StringArg("button", "left")); err != nil {
			return err
		}
		return p.executor.ClickMouse(command.StringArg("button", "left"))
	case "mouse_button_down":
		return p.executor.MouseButtonDown(command.StringArg("button", "left"))
	case "mouse_button_up":
		return p.executor.MouseButtonUp(command.StringArg("button", "left"))
	case "mouse_scroll":
		return p.executor.ScrollMouse(command.IntArg("vertical", command.IntArg("amount", 0)))
	default:
		return fmt.Errorf("unsupported mouse command %q", command.CommandName())
	}
}
