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
- Real pairing completion against the agent API.
- Authenticated WebSocket command transport.
- Dynamic remote rendering from JSON definitions fetched from the agent.
- Filesystem browsing against the connected agent.
- Task list viewing against the connected agent.
- File upload to the connected agent.
- Mouse, keyboard, media, and custom remote starter experiences.

## Rendering Model

The client should treat remotes as data, not screens. Each remote JSON file describes:

- Remote metadata such as id, name, and category.
- A list of controls with type-specific props.
- Command bindings that map interactions to protocol commands.

This architecture keeps the app flexible enough for a future visual remote designer and remote marketplace.

## Near-Term Android Work

1. Wire the pair URI flow to camera scanning.
2. Persist paired agents and last-used remotes locally.
3. Add gesture handling for touchpad and air-mouse controls.
4. Add visual remote authoring and macro editing.
