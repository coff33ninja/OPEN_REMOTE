# Android Client

## Purpose

The Android client is the handheld control surface. It discovers agents, pairs securely, loads remote definitions, and translates touch input into protocol commands.

## Project Shape

```text
android/
|-- lib/core/models/          transport and layout data models
|-- lib/core/networking/      agent discovery and command transport
|-- lib/features/discovery/   agent selection screens
|-- lib/features/*_remote/    built-in remote screens
|-- lib/features/custom_remotes/
|-- lib/ui/                   themes and reusable widgets
`-- assets/remotes/           local sample remote payloads
```

## Initial Capabilities

- mDNS-based LAN discovery for `_openremote._tcp`.
- Pair URI ingestion through the `openremote://pair` payload format.
- Camera QR scanning for pairing sessions.
- Real pairing completion against the agent API.
- Global device selection with a lock that prevents auto-switching when pairing or reconnecting.
- Wake-on-LAN support for remembered agents, including remote-side `power_wake` interception and offline wake from the Power screen.
- Authenticated WebSocket command transport.
- Connection state tracking with socket keep-alives and a lightweight reconnect loop.
- Local visual remote designer with live preview and JSON export.
- Dynamic remote rendering from JSON definitions fetched from the agent.
- Filesystem browsing against the connected agent.
- Task list viewing against the connected agent.
- File upload to the connected agent.
- Android share-intent intake that uploads queued items to the connected agent.
- Local persistence for paired devices, recent agents, favorite agents, favorite remotes, and cached remote layouts.
- A dedicated power screen that offers Wake-on-LAN when offline, and restart/shutdown/sleep when connected.
- Mouse, keyboard, media, and custom remote starter experiences.
- Unpaired device cards offer a direct pairing shortcut (QR-first with URI fallback).

## Device Selection and Power Rules

All UI surfaces operate on a single selected device. Selection is global, persisted, and can be locked to prevent auto-switching when pairing or reconnecting. Use the device selector in the app bar to change or lock the active device.

Wake-on-LAN does not require a live WebSocket session and is available while the agent is offline. Shutdown, restart, and sleep are only enabled when the selected device is connected.

## Rendering Model

The client should treat remotes as data, not screens. Each remote JSON file describes:

- Remote metadata such as id, name, and category.
- An optional canvas plus absolute frames for positioned layouts.
- A list of controls with type-specific props.
- Command bindings that map interactions to protocol commands.

This architecture keeps the app flexible enough for a future visual remote designer and remote marketplace.

## Near-Term Android Work

1. Add gesture handling for touchpad and air-mouse controls.
2. Expand the designer into drag-and-drop layout editing and remote sync.
3. Deep-link `openremote://pair` URIs into the app directly.
4. Extend share-to-PC beyond uploads into remote-aware actions.
