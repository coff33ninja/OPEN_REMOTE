package power

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
	return "power"
}

func (p *Plugin) Name() string {
	return "Power"
}

func (p *Plugin) Manifest() internalplugins.Manifest {
	return internalplugins.Manifest{
		ID:          p.ID(),
		Name:        p.Name(),
		Category:    "system",
		Description: "Power management commands",
		Commands:    []string{"power_sleep", "power_shutdown"},
	}
}

func (p *Plugin) Supports(command internalplugins.Command) bool {
	switch command.CommandName() {
	case "power_sleep", "power_shutdown":
		return true
	default:
		return false
	}
}

func (p *Plugin) Execute(_ context.Context, command internalplugins.Command) error {
	switch command.CommandName() {
	case "power_sleep":
		return p.executor.PowerAction("sleep")
	case "power_shutdown":
		return p.executor.PowerAction("shutdown")
	default:
		return fmt.Errorf("unsupported power command %q", command.CommandName())
	}
}
