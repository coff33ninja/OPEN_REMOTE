package presentation

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
	return "presentation"
}

func (p *Plugin) Name() string {
	return "Presentation"
}

func (p *Plugin) Manifest() internalplugins.Manifest {
	return internalplugins.Manifest{
		ID:          p.ID(),
		Name:        p.Name(),
		Category:    "presentation",
		Description: "Slide and blackout controls for talks",
		Commands:    []string{"presentation_next", "presentation_previous", "presentation_blackout"},
	}
}

func (p *Plugin) Supports(command internalplugins.Command) bool {
	switch command.CommandName() {
	case "presentation_next", "presentation_previous", "presentation_blackout":
		return true
	default:
		return false
	}
}

func (p *Plugin) Execute(_ context.Context, command internalplugins.Command) error {
	switch command.CommandName() {
	case "presentation_next":
		return p.executor.PresentationAction("next")
	case "presentation_previous":
		return p.executor.PresentationAction("previous")
	case "presentation_blackout":
		return p.executor.PresentationAction("blackout")
	default:
		return fmt.Errorf("unsupported presentation command %q", command.CommandName())
	}
}
