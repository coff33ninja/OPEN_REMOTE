# Plugin SDK

## Goal

The plugin SDK exists so the agent can grow beyond its builtin remotes without turning the core into a monolith.

## Contract

Each plugin must provide:

- A stable identifier.
- A human-readable name.
- A manifest containing supported commands and categories.
- A capability check that determines whether the plugin can handle a command.
- An execution method that accepts the canonical command model.

## Development Model

The current repository ships builtin plugins inside the agent module. External plugins should depend on the public contract package at `openremote/agent/pkg/pluginsdk`.

The SDK template in [`sdk/plugin-template/README.md`](/j:/SCRIPTS/OPEN_REMOTE/sdk/plugin-template/README.md) is its own Go module and points at the local agent module through a `replace` directive so it compiles inside this repository without importing `internal` packages.
The agent now loads external plugins from disk via `plugin.json` plus an executable, and delivers command envelopes as JSON over stdin.

## External Manifest Shape

- `id`: stable plugin identifier.
- `name`: human-readable plugin name.
- `category`: manifest category.
- `description`: short plugin summary.
- `commands`: explicit list of command names handled by the plugin.
- `executable`: relative or absolute executable path.
- `args`: optional argument list.
- `working_dir`: optional process working directory.
- `timeout_ms`: optional execution timeout.
- `environment`: optional environment variable map.

## Future Enhancements

- Load plugin manifests from disk.
- Verify plugin compatibility against protocol and agent versions.
- Support remote packages that bundle UI definitions and plugin metadata together.
