# Security

## Security Baseline

OpenRemote is a control plane for desktop automation, so the default security posture must assume hostile local networks and accidental device exposure.

## Baseline Controls

- Require pairing before any command is accepted.
- Make pairing tokens short lived and single use.
- Persist trusted device metadata and update last-seen timestamps.
- Authenticate commands with bearer tokens.
- Rate-limit or reject malformed command bursts.
- Validate command payloads before they reach OS automation code.

## Planned Hardening

1. TLS for network transport.
2. Optional public key exchange during pairing.
3. Device-scoped permissions such as media-only remotes.
4. Audit logs for control actions and trust changes.
5. Secret rotation and device revocation flows.

## Threat Model Snapshot

- Opportunistic LAN attackers trying to replay commands.
- Users sharing screenshots of still-valid QR pairing codes.
- Compromised mobile devices reusing bearer tokens.
- Malformed plugin commands attempting to reach shell-level automation.
