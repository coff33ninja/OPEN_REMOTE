# OpenRemote Agent

This module contains the desktop-side runtime for OpenRemote.

## Current State

The agent is now a working runtime with these pieces in place:

- configuration loading
- mDNS advertisement
- HTTP control and pairing endpoints
- authenticated WebSocket command transport
- remote definition catalog and document serving
- QR pairing image generation
- browser-based pairing page at `/pair`
- pairing session generation
- trusted device persistence
- command routing to builtin plugins
- disk-loaded external plugin manifests and executables
- Windows automation for mouse, keyboard, media, presentation, power, and approximate volume control

## Run

```powershell
Set-Location .\agent
go build ./...
.\openremote-agent.exe
```

## Useful Environment Variables

- `OPENREMOTE_PORT`
- `OPENREMOTE_LISTEN_ADDRESS`
- `OPENREMOTE_PUBLIC_HOST`
- `OPENREMOTE_PAIRING_TTL`
- `OPENREMOTE_DATA_DIR`
- `OPENREMOTE_REMOTES_DIR`
- `OPENREMOTE_PLUGINS_DIR`
- `OPENREMOTE_OPEN_PAIRING_UI`
