package pluginsdk

import internalplugins "openremote/agent/internal/plugins"

type Command = internalplugins.Command

type Manifest = internalplugins.Manifest

type Plugin = internalplugins.Plugin

type Registry = internalplugins.Registry

func NewRegistry(plugins ...Plugin) *Registry {
	return internalplugins.NewRegistry(plugins...)
}
