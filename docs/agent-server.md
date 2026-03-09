# Agent Server

## Purpose

The desktop agent is the runtime that turns a phone into a control surface for a PC. The current implementation now covers real discovery, pairing, transport, and command execution paths on Windows.

## Directory Layout

```text
agent/
|-- cmd/openremote-agent/     process entry point
|-- internal/config/          environment and default settings
|-- internal/discovery/       mDNS advertisement
|-- internal/pairing/         QR session issuance and validation
|-- internal/plugins/         registry and plugin contracts
|-- internal/server/          HTTP API, auth, websocket transport
|-- internal/system/          Windows automation bindings
|-- pkg/pluginsdk/            public plugin contract for external modules
`-- plugins/                  builtin plugin implementations
```

## Responsibilities

- Serve metadata and health endpoints.
- Issue pairing sessions and exchange them for access tokens.
- Authenticate command requests with bearer tokens.
- Route commands to builtin or future external plugins.
- Keep system automation behind a narrow executor interface.

## Initial API Surface

- `GET /healthz`: process health.
- `GET /api/v1/meta`: agent capabilities and endpoint metadata.
- `GET /api/v1/plugins`: builtin plugin manifests.
- `GET /api/v1/remotes/catalog`: remote catalog summary.
- `GET /api/v1/remotes/{name}`: remote JSON document.
- `GET /api/v1/filesystem`: list filesystem roots or directory contents.
- `GET /api/v1/pairing/session`: issue a short-lived pairing QR payload.
- `GET /api/v1/pairing/qr.png`: render a QR image for a fresh pairing session.
- `POST /api/v1/pairing/complete`: exchange a pairing token for a device token.
- `GET /api/v1/files`: list uploaded files.
- `POST /api/v1/files/upload`: store a transferred file under the agent data directory.
- `GET /api/v1/processes`: list running processes.
- `POST /api/v1/processes/terminate`: request process termination.
- `POST /api/v1/commands`: authenticated command submission.
- `GET /ws`: authenticated WebSocket command transport.

## Next Implementation Steps

1. Add bidirectional event frames over WebSocket instead of ack-only responses.
2. Replace cached volume stepping with direct OS mixer integration.
3. Add plugin loading from disk and compatibility checks.
4. Add a local desktop pairing UI that renders the QR code directly.
