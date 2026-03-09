# OpenRemote

OpenRemote is a monorepo implementation for an open-source alternative to Unified Remote. It packages three core ideas into one repository:

- A desktop agent that discovers itself on the LAN, pairs with mobile devices, and routes commands to plugins.
- A Flutter-based Android client that discovers agents, renders remotes, and sends commands.
- A protocol, remote definition format, and SDK surface that let new remotes and plugins ship without rewriting the whole stack.

The repository is generated from the product brief in [`CHAT.md`](/j:/SCRIPTS/OPEN_REMOTE/CHAT.md) and turns that conversation into a concrete starter layout.

## Repository Map

```text
openremote/
|-- agent/        Desktop agent in Go
|-- android/      Flutter-based Android client app
|-- docs/         Product, architecture, security, and delivery docs
|-- plugins/      Reserved for future shared plugin assets
|-- protocol/     Command and remote layout specifications
|-- remotes/      Sample remote definitions rendered by the client
|-- scripts/      Validation and smoke-test automation
|-- sdk/          Plugin SDK template and authoring guidance
`-- web-admin/    Optional control plane placeholder
```

## MVP Scope

The current implementation is biased toward the first usable milestone:

1. Agent discovery over mDNS plus HTTP and WebSocket control endpoints.
2. QR-based pairing and token issuance flow.
3. Core control plugins for mouse, keyboard, media, presentation, power, volume, and macros.
4. Dynamic remote definitions stored as JSON and served by the agent.
5. Explorer, process list, file upload, and a Flutter client that can pair, discover, connect, and load remotes from the agent.

## Validation

```powershell
.\scripts\validate-remotes.ps1
.\scripts\smoke-agent.ps1
```

## Quick Start

### Agent

```powershell
Set-Location .\agent
go build ./...
.\openremote-agent.exe
```

The agent now exposes a live HTTP API, a live authenticated WebSocket endpoint, mDNS advertisement, and QR pairing output.

### Android

```powershell
Set-Location .\android
flutter pub get
flutter build apk --debug
```

The Android client now includes a generated native Android project plus pair-URI flow, mDNS discovery, WebSocket transport, remote catalog loading, custom remote rendering, explorer, tasks, and file upload support.

## Primary Docs

- [`docs/architecture.md`](/j:/SCRIPTS/OPEN_REMOTE/docs/architecture.md)
- [`docs/agent-server.md`](/j:/SCRIPTS/OPEN_REMOTE/docs/agent-server.md)
- [`docs/android-client.md`](/j:/SCRIPTS/OPEN_REMOTE/docs/android-client.md)
- [`docs/pairing.md`](/j:/SCRIPTS/OPEN_REMOTE/docs/pairing.md)
- [`docs/protocol.md`](/j:/SCRIPTS/OPEN_REMOTE/docs/protocol.md)
- [`docs/plugin-sdk.md`](/j:/SCRIPTS/OPEN_REMOTE/docs/plugin-sdk.md)
- [`docs/remote-designer.md`](/j:/SCRIPTS/OPEN_REMOTE/docs/remote-designer.md)
- [`docs/security.md`](/j:/SCRIPTS/OPEN_REMOTE/docs/security.md)
- [`docs/roadmap.md`](/j:/SCRIPTS/OPEN_REMOTE/docs/roadmap.md)

## Design Principles

- Keep transport, UI rendering, and command execution decoupled.
- Prefer data-driven remote definitions over hardcoded screens.
- Keep the agent portable and dependency-light in the first milestone.
- Treat pairing and device trust as first-class platform features, not add-ons.
- Make every future feature extensible through protocol evolution rather than ad hoc special cases.
