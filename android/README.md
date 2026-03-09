# OpenRemote Android

This directory contains the Flutter-based Android client implementation for OpenRemote.

The generated native Android project now lives under `android/`, so this folder is a standard Flutter app root and can build with normal Flutter tooling.

## Included

- shared models for devices, commands, and remote layouts
- mDNS discovery using `multicast_dns`
- a transport client using `dart:io` WebSocket support
- pair-URI parsing and pairing completion against the agent API
- camera QR scanning for desktop pairing
- remote catalog loading from the agent
- local visual remote designer with live preview and JSON export
- dynamic rendering for buttons, sliders, touchpads, d-pads, button grids, text input, and macros
- file upload support
- Android share-intent intake that uploads files to the connected agent
- persistence for paired agents, favorites, recents, and cached layouts
- filesystem browsing and process management screens
- mouse, keyboard, media, and custom remote screens
- bundled sample remotes under `assets/remotes/`
- generated Android platform project under `android/`

## Next Step

The major remaining gaps are camera-based QR scanning, persistence of paired devices, and deeper designer/marketplace features.
