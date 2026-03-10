# Agent Server

## Purpose

The desktop agent is the runtime that turns a phone into a control surface for a PC. The current implementation now covers real discovery, pairing, transport, and command execution paths on Windows.

## Directory Layout

```text
agent/
|-- cmd/openremote-agent/     process entry point
|-- internal/config/          environment and default settings
|-- internal/discovery/       mDNS advertisement
|-- internal/pairing/         QR session issuance and validation
|-- internal/plugins/         registry and plugin contracts
|-- internal/server/          HTTP API, auth, websocket transport
|-- internal/system/          Windows automation bindings
|-- pkg/pluginsdk/            public plugin contract for external modules
`-- plugins/                  builtin plugin implementations
```

## Responsibilities

- Serve metadata and health endpoints.
- Issue pairing sessions and exchange them for access tokens.
- Advertise wake-target metadata for offline power-on flows.
- Authenticate command requests with bearer tokens.
- Route commands to builtin or future external plugins.
- Load external plugin executables from disk through `plugin.json` manifests.
- Keep system automation behind a narrow executor interface.

## Initial API Surface

- `GET /healthz`: process health.
- `GET /pair`: browser-based pairing UI with embedded QR code.
- `GET /`: redirect to the pairing UI.
- `GET /api/v1/meta`: agent capabilities and endpoint metadata.
- `GET /api/v1/plugins`: builtin plugin manifests.
- `GET /api/v1/remotes/catalog`: remote catalog summary.
- `GET /api/v1/remotes/{name}`: remote JSON document.
- `GET /api/v1/filesystem`: list filesystem roots or directory contents.
- `GET /api/v1/pairing/session`: issue a short-lived pairing QR payload.
- `GET /api/v1/pairing/qr.png`: render a QR image for a fresh pairing session.
- `POST /api/v1/pairing/complete`: exchange a pairing token for a device token.
- `GET /api/v1/files`: list uploaded files.
- `POST /api/v1/files/upload`: store a transferred file under the agent data directory.
- `GET /api/v1/processes`: list running processes.
- `POST /api/v1/processes/terminate`: request process termination.
- `GET /api/v1/services`: list Windows services and status metadata.
- `POST /api/v1/services/start|stop|restart`: control a Windows service by name.
- `GET /api/v1/system/info`: snapshot CPU, memory, GPU, disk, and thermal telemetry.
- `POST /api/v1/logs/client`: accept client error logs (requires bearer token).
- `POST /api/v1/commands`: authenticated command submission.
- `GET /ws`: authenticated WebSocket command transport.

Agent log files live under `data/logs/` by default:

- `agent.log`: agent/server logs.
- `client.log`: Android client error reports.

## System Telemetry Sources

Telemetry is opportunistic: the agent returns what the host OS can provide. Some metrics are built-in, while others require optional tools.

### Windows (current implementation)

- **Built-in (no extra installs)**: PowerShell `Get-CimInstance` over WMI/CIM classes:
  - `Win32_Processor`, `Win32_OperatingSystem`, `Win32_VideoController`, `Win32_LogicalDisk`.
- **Built-in perf counters (no extra installs)**:
  - Per-core CPU load: `Win32_PerfFormattedData_PerfOS_Processor` (`PercentProcessorTime`).
  - GPU memory usage: `Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory` (`DedicatedUsage`, `SharedUsage`, `TotalCommitted`). Availability varies by driver/GPU.
  - Thermals: `MSAcpi_ThermalZoneTemperature` (namespace `root/wmi`). Often missing on desktops; temperatures are optional.
- **Optional tools (not yet integrated)**:
  - **HWiNFO64**: enable “Shared Memory Support” for per-core temps, fan speeds, GPU sensors.
  - **AIDA64**: enable sensor shared memory/export for CPU/GPU/VRM temps and power.

### Linux (planned)

- **Built-in sources**: `/proc`, `/sys`, `/sys/class/thermal`, `/sys/class/drm`, `lscpu`, `lsblk`, `df`, `free`.
- **Optional packages/tools**:
  - **lm-sensors**: `sensors` for CPU/GPU temps and fan readouts.
  - **smartmontools**: `smartctl` for disk SMART health/temps.
  - **NVIDIA**: `nvidia-smi` (typically from `nvidia-utils`).
  - **AMD ROCm**: `rocm-smi` (from `rocm-smi` package).
  - **Intel**: `intel_gpu_top` (from `intel-gpu-tools`) for GPU load and metrics.
  - **Mesa utilities**: `glxinfo` (from `mesa-utils`) for GPU identification.
- Some tools require root or elevated permissions depending on distro security policy.

### macOS (planned)

- **Built-in sources**:
  - CPU/Memory/Disks: `sysctl`, `system_profiler`, `df`.
  - GPU: `system_profiler SPDisplaysDataType`.
  - Thermals/Power: `pmset -g therm`, `ioreg`.
- **Privileged tools**:
  - `powermetrics` (requires sudo) for detailed thermal/power telemetry.
- Availability varies by hardware and OS version; some metrics are permission-gated.

## Next Implementation Steps

1. Add bidirectional event frames over WebSocket instead of ack-only responses.
2. Replace cached volume stepping with direct OS mixer integration.
3. Add compatibility/version checks for external plugins.
4. Add a native window wrapper around the pairing page instead of a browser tab.
