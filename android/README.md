# OpenRemote Android

This directory contains the Flutter-based Android client implementation for OpenRemote.

The generated native Android project now lives under `android/`, so this folder is a standard Flutter app root and can build with normal Flutter tooling.

## Included

- shared models for devices, commands, and remote layouts
- mDNS discovery using `multicast_dns`
- a transport client using `dart:io` WebSocket support
- pair-URI parsing and pairing completion against the agent API
- remote catalog loading from the agent
- dynamic rendering for buttons, sliders, touchpads, d-pads, button grids, text input, and macros
- file upload support
- filesystem browsing and process management screens
- mouse, keyboard, media, and custom remote screens
- bundled sample remotes under `assets/remotes/`
- generated Android platform project under `android/`

## Next Step

The major remaining gaps are camera-based QR scanning, persistence of paired devices, and deeper designer/marketplace features.
