package volume

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
	return "volume"
}

func (p *Plugin) Name() string {
	return "Volume"
}

func (p *Plugin) Manifest() internalplugins.Manifest {
	return internalplugins.Manifest{
		ID:          p.ID(),
		Name:        p.Name(),
		Category:    "media",
		Description: "Volume controls",
		Commands:    []string{"volume_set"},
	}
}

func (p *Plugin) Supports(command internalplugins.Command) bool {
	return command.CommandName() == "volume_set"
}

func (p *Plugin) Execute(_ context.Context, command internalplugins.Command) error {
	if command.CommandName() != "volume_set" {
		return fmt.Errorf("unsupported volume command %q", command.CommandName())
	}

	return p.executor.SetVolume(command.IntArg("value", 0))
}
