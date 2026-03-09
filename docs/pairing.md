# Pairing

## Goal

Pair the Android client with a desktop agent in one scan without manual IP entry or reusable setup codes.

## Pairing Flow

1. The agent generates a short-lived pairing token.
2. The agent encodes host, port, token, device metadata, and wake-target metadata in an `openremote://pair` URI.
3. The Android client scans or receives that URI.
4. The client calls `POST /api/v1/pairing/complete` with the pairing token and device name.
5. The agent consumes the pairing token and returns a long-lived bearer token.
6. The client stores the bearer token and uses it for future command requests.

## QR Payload Shape

```json
{
  "host": "192.168.1.50",
  "port": 9876,
  "token": "6f8c3eaa92",
  "device": "DJ-PC",
  "service": "_openremote._tcp",
  "ws_path": "/ws",
  "wake_mac": "AA:BB:CC:DD:EE:FF",
  "wake_broadcast": "192.168.1.255",
  "wake_port": 9
}
```

Encoded form:

```text
openremote://pair?data=<base64url-json>
```

## Security Rules

- Pairing tokens expire quickly. The current implementation defaults to 2 minutes.
- Pairing tokens are single use.
- Access tokens are device-specific.
- The agent records last-seen timestamps for paired devices.
- Wake metadata is advisory and is used by the Android client to send WOL packets even while the agent itself is offline.
- Future revisions should add optional TLS and device-scoped permissions.
