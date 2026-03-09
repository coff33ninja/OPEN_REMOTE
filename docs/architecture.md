# Architecture

## System Overview

OpenRemote is a three-plane system:

1. Control plane: discovery, pairing, authentication, capability metadata.
2. Command plane: transport and routing for user actions such as mouse moves or media controls.
3. Presentation plane: data-driven remote layouts rendered by the Android client.

```text
Android client
  | discovery + pairing
  v
Desktop agent
  | command routing
  v
Builtin plugins / future extensions
```

## Bounded Components

### Android client

- Discovers nearby agents over LAN metadata.
- Scans QR pairing URIs and exchanges them for access tokens.
- Renders built-in and custom remotes from JSON definitions.
- Sends command envelopes over the selected transport.

### Desktop agent

- Publishes discovery metadata.
- Mints short-lived pairing sessions and long-lived device tokens.
- Exposes transport endpoints and routes commands to plugins.
- Executes system automation through a stable internal facade.

### Protocol and remote definition layer

- Defines canonical command envelopes.
- Defines remote layout primitives such as button, slider, and touchpad.
- Allows client and agent features to evolve independently.

## Runtime Data Flow

1. The agent starts, loads config, and prepares builtin plugins.
2. The Android client discovers the agent or scans a pairing QR.
3. The client exchanges the pairing token for a device token.
4. The client fetches remote metadata and renders local or synced remotes.
5. User actions become protocol commands that the agent routes to a matching plugin.
6. The plugin delegates to the system executor abstraction.

## Storage Boundaries

- `agent/data/trusted-devices.json`: paired device tokens and audit metadata.
- `remotes/*.json`: portable remote definitions that the client can render.
- `protocol/`: canonical specifications shared across implementations.
- `sdk/plugin-template/`: authoring template for future third-party plugins.

## Implementation Notes

- The agent now advertises itself over mDNS, serves pairing and remote APIs over HTTP, and accepts authenticated command frames over WebSocket.
- The Android client can discover agents over mDNS, pair from a QR URI, upload files, and load remote definitions from the agent.
- Windows automation is implemented directly in the agent for mouse, keyboard, media, presentation, and power flows. Absolute volume is still approximated from cached state rather than queried from the OS mixer.
