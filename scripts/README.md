# Scripts

This directory contains repeatable repository automation:

- `validate-remotes.ps1`: validates the shipped remote catalog, checks mirrored Android assets, and rejects unsupported command bindings.
- `smoke-agent.ps1`: builds and launches the agent, pairs a temporary client, exercises the live API and WebSocket transport, and skips sleep and shutdown commands.
- `build-release-artifacts.ps1`: restores Go and Flutter dependencies, builds the Windows agent plus Android release APK, and stages both under the gitignored `release-artifacts/` folder at the repo root.
- `publish-release.ps1`: pushes a tag and creates or updates a GitHub release from the host machine using `gh`, which is the temporary release path while GitHub-hosted runners are out of scope.
