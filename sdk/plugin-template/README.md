# Plugin Template

Use this folder as the starting point for a future agent plugin package.

## Expected Responsibilities

- publish manifest metadata
- declare supported command names
- validate command arguments
- delegate OS work through a stable automation boundary

## Files

- `go.mod`: standalone module metadata for editor and build support
- `plugin.go`: starter implementation shape
- `plugin.json`: metadata that can later be indexed by a marketplace or plugin loader

## Compatibility Guidance

- Import the public plugin contract from `openremote/agent/pkg/pluginsdk`.
- Keep command names additive and explicit.
- Avoid shelling out directly from the plugin.
- Treat all remote-supplied arguments as untrusted input.
