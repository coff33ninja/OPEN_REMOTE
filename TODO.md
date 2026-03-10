# OpenRemote TODO

## Done (With Remaining Gaps)

- Touchpad now supports tap-to-click, double-click, hold-to-drag, drag lock, wheel scroll, middle click, and sensitivity control in the dedicated mouse screen and the JSON touchpad control. See android/lib/features/mouse_remote/mouse_screen.dart, android/lib/ui/widgets/touchpad_surface.dart, android/lib/features/custom_remotes/remote_renderer.dart, agent/plugins/mouse/plugin.go, and agent/internal/system/mouse_windows.go.
- Remaining (touchpad): gesture zones, air-mouse mode, movement smoothing/coalescing/acceleration, and persisted per-device sensitivity or pointer profiles.

- Keyboard now supports text send, per-key send, key down/up, held modifiers, one-shot shortcuts like Alt+Tab and Ctrl+Shift+Esc, arrows, function keys, common editing keys such as backspace, enter, tab, escape, delete, home, end, and page navigation, plus richer IME/composition-aware input on Android. See android/lib/features/keyboard_remote/keyboard_screen.dart, agent/plugins/keyboard/plugin.go, agent/internal/system/keyboard_windows.go, and agent/internal/system/windows_input.go.
- Remaining (keyboard): clipboard sync.

- File explorer now supports directory browsing with breadcrumbs and filtering, remote launch/open, download, text and image preview, rename, delete, move, copy, folder creation, and uploading directly into the folder you are viewing. See android/lib/features/file_explorer/file_explorer_screen.dart, android/lib/core/networking/api_client.dart, agent/internal/server/router.go, and agent/internal/system/explorer_ops.go.
- Remaining (file explorer): large transfers are still one-shot with no chunking, resume, streaming, compression, or progress reporting.

## Not Yet Implemented (Hard Gaps)
- Services are not implemented. The app has a process list and terminate action, but there is no Windows service inventory, no start/stop/restart, and no daemon/service health view. The current task manager is just tasklist plus taskkill. See android/lib/features/task_manager/task_manager_screen.dart and agent/internal/system/processes_windows.go.
- Current active items are mostly absent. There is no active window list, no foreground app, no media-session metadata, no currently playing track, no window titles, no CPU/network/disk telemetry, and no live process updates. The agent is command-oriented, not state-oriented, in agent/internal/server/websocket.go.
- Volume is not real system-state volume. It is a cached approximation stepped via virtual keys, so it cannot reliably reflect actual OS mixer state, mute state, or per-app volume. See agent/internal/system/system.go and agent/internal/system/volume_windows.go.
- Custom remotes are still limited to button, toggle, macro_button, slider, text_input, touchpad, dpad, and grid_buttons. There is no list view control, no dropdowns, no image buttons, no hold-repeat buttons, no joystick, no rotary knob, no state-bound widgets, and no agent-fed dynamic controls. See android/lib/features/custom_remotes/remote_renderer.dart.
- External plugins can run executables, but there is no version handshake, no persistent plugin host, no install/update flow, and no structured capability discovery beyond static manifest commands. See agent/internal/plugins/loader.go and agent/pkg/pluginsdk/sdk.go.
- The real automation surface is Windows-only. Outside Windows, the non-Windows system files are stubs/fallback builds, so cross-platform desktop support is not functionally there yet.

## Performance Limits

- Remote catalog loading is N+1 and sequential: the client fetches the catalog, then fetches each remote JSON one by one in android/lib/core/networking/api_client.dart. That will get slow as remote count grows.
- Android creates a fresh HttpClient per request and a simple raw WebSocket connection with no pooling, no retry policy, and no inbound event processing. See android/lib/core/networking/api_client.dart and android/lib/core/networking/websocket_client.dart.
- Touchpad movement sends every drag delta immediately. There is no coalescing, rate limiting, smoothing, or acceleration profile, so high-frequency pointer use will generate noisy traffic and uneven feel.
- Discovery is still serial mDNS work in android/lib/core/networking/discovery.dart, which means cold scans can feel slower than they need to.
- File transfer is base64-over-JSON in one shot. There is no chunking, resume, streaming, compression, or progress reporting for large files.

## Usability Gaps

- The Android app still does not deep-link openremote://pair into the app directly; pairing is QR scan or manual paste, not OS-level open-with flow.
- There is no background control service, notification remote, home-screen widget, quick settings tile, or lock-screen interaction path.
- Explorer and task views are basic lists: no search, sorting, filters, breadcrumbs/history, multi-select, or context actions.
- There is no diagnostics surface for latency, socket health, auth expiry, command failure history, or plugin availability.
- The app has device management now, but not a true desktop detail page with OS info, plugin inventory, current session state, storage info, or live capability status.
- Android release settings are still using the debug signing config and the default applicationId. See android/android/app/build.gradle.kts.
