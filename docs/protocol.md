# Protocol

The OpenRemote protocol has two data models:

- Command envelopes sent from a client to the agent.
- Remote layout documents that describe renderable controls.

The canonical examples live in [`protocol/commands.md`](/j:/SCRIPTS/OPEN_REMOTE/protocol/commands.md).

## Command Envelope

Each command should be self-describing enough for the agent to route it without tight coupling to a single UI.

Suggested fields:

- `type`: command family, for example `mouse`, `keyboard`, or `media`.
- `action`: action within the family, for example `move`, `type`, or `toggle`.
- `name`: optional fully qualified command name, for example `mouse_move`.
- `arguments`: key-value payload for the command.
- `remote_id`: optional originating remote identifier.
- `request_id`: optional client correlation id.

## Transport Strategy

- HTTP is live for pairing, metadata, and fallback command submission.
- WebSocket is live for low-latency command transport.
- Both transports accept the same command envelope to avoid duplicated logic.
- File transfer is HTTP-only and uses the dedicated `/api/v1/files/upload` endpoint with base64-encoded file bytes.

## Versioning

- Start with `v1` route prefixes.
- Treat new fields as additive and optional by default.
- Avoid changing meaning of existing command names.
