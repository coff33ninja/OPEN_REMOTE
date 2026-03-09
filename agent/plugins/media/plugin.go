package media

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
	return "media"
}

func (p *Plugin) Name() string {
	return "Media"
}

func (p *Plugin) Manifest() internalplugins.Manifest {
	return internalplugins.Manifest{
		ID:          p.ID(),
		Name:        p.Name(),
		Category:    "media",
		Description: "Playback transport controls",
		Commands:    []string{"media_toggle", "media_next", "media_previous", "media_stop"},
	}
}

func (p *Plugin) Supports(command internalplugins.Command) bool {
	switch command.CommandName() {
	case "media_toggle", "media_next", "media_previous", "media_stop":
		return true
	default:
		return false
	}
}

func (p *Plugin) Execute(_ context.Context, command internalplugins.Command) error {
	switch command.CommandName() {
	case "media_toggle":
		return p.executor.MediaAction("toggle")
	case "media_next":
		return p.executor.MediaAction("next")
	case "media_previous":
		return p.executor.MediaAction("previous")
	case "media_stop":
		return p.executor.MediaAction("stop")
	default:
		return fmt.Errorf("unsupported media command %q", command.CommandName())
	}
}
