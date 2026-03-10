# Commands

## Command Envelope

```json
{
  "request_id": "01HTQPVV7BX0T3V9SQW78MK5MN",
  "remote_id": "mouse-touchpad",
  "type": "mouse",
  "action": "move",
  "name": "mouse_move",
  "arguments": {
    "dx": 18,
    "dy": -6
  }
}
```

## Builtin Command Families

### Mouse

- `mouse_move`: `dx`, `dy`
- `mouse_click`: `button`

### Keyboard

- `keyboard_type`: `text`

### Media

- `media_toggle`
- `media_next`
- `media_previous`
- `media_stop`

### Volume

- `volume_set`: `value`

### Power

- `power_wake`: optional `mac`, `broadcast`, `port`
- `power_sleep`
- `power_shutdown`
- `power_restart`

`power_wake` is special:

- When it reaches the agent, the power plugin can emit a Wake-on-LAN magic packet using either command arguments or the agent's configured/default wake target.
- The Android client also intercepts `power_wake` and can send the magic packet directly from the phone when the selected agent has persisted wake metadata. That is what allows a previously paired but currently offline PC to be powered on.

### Presentation

- `presentation_next`
- `presentation_previous`
- `presentation_blackout`

### Macro

- `macro_run`: `steps`

Each step can contain `name`, `type`, `action`, and `arguments`. Nested `macro_run` is rejected.

## Transport Notes

- HTTP: `POST /api/v1/commands` with `Authorization: Bearer <token>`.
- WebSocket: send the same JSON envelope frame-by-frame on `/ws?access_token=<token>`.
- File transfer: `POST /api/v1/files/upload` with JSON fields `name` and `base64_data`.
