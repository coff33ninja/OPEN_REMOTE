# SDK

The SDK directory holds starter materials for plugin authors.

Current contents:

- `plugin-template/`: starter manifest, README, executable entry point, and Go shape for an external agent plugin.

The current repository only wires builtin plugins directly into the agent, but the SDK documents the compatibility surface those future external plugins should follow through `openremote/agent/pkg/pluginsdk`.
