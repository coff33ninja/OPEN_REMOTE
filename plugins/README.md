# Shared Plugins

The repository keeps builtin agent plugins under `agent/plugins/` so the Go module can compile cleanly on its own.

This top-level directory is now the default disk-loaded plugin root for external plugin bundles.

Each plugin bundle should provide a `plugin.json` manifest plus an executable that accepts a JSON command envelope on stdin and returns a zero exit code on success.
