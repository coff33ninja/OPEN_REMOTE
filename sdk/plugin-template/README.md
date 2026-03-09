# Plugin Template

Use this folder as the starting point for a future agent plugin package.

## Expected Responsibilities

- publish manifest metadata
- declare supported command names
- validate command arguments
- delegate OS work through a stable automation boundary

## Files

- `go.mod`: standalone module metadata for editor and build support
- `cmd/plugin-template/main.go`: executable entry point for the external plugin process
- `plugin.go`: starter implementation shape
- `plugin.json`: disk-loaded metadata consumed by the agent plugin loader

## Compatibility Guidance

- Import the public plugin contract from `openremote/agent/pkg/pluginsdk`.
- Build the executable beside `plugin.json` so the agent can launch it from disk.
- External plugin commands are delivered as JSON on stdin and use exit status plus stderr for failure reporting.
- Keep command names additive and explicit.
- Avoid shelling out directly from the plugin.
- Treat all remote-supplied arguments as untrusted input.
