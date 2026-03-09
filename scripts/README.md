# Scripts

This directory contains repeatable repository automation:

- `validate-remotes.ps1`: validates the shipped remote catalog, checks mirrored Android assets, and rejects unsupported command bindings.
- `smoke-agent.ps1`: builds and launches the agent, pairs a temporary client, exercises the live API and WebSocket transport, and skips sleep and shutdown commands.
