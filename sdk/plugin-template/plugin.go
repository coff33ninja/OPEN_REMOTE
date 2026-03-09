package plugin_template

import (
	"context"
	"fmt"

	"openremote/agent/pkg/pluginsdk"
)

type Plugin struct{}

func New() *Plugin {
	return &Plugin{}
}

func (p *Plugin) ID() string {
	return "plugin-template"
}

func (p *Plugin) Name() string {
	return "Plugin Template"
}

func (p *Plugin) Manifest() pluginsdk.Manifest {
	return pluginsdk.Manifest{
		ID:          p.ID(),
		Name:        p.Name(),
		Category:    "template",
		Description: "Starter plugin shape for future extraction",
		Commands:    []string{"template_noop"},
	}
}

func (p *Plugin) Supports(command pluginsdk.Command) bool {
	return command.CommandName() == "template_noop"
}

func (p *Plugin) Execute(_ context.Context, command pluginsdk.Command) error {
	if !p.Supports(command) {
		return fmt.Errorf("unsupported command %q", command.CommandName())
	}

	return nil
}
