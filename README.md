# incoming-connection-logger

Bash script for continuously capturing inbound network connection metadata and storing deduplicated records for operational security visibility.

## Problem
Teams without lightweight network telemetry often miss early signs of unauthorized inbound activity. Native tools exist, but repeated manual inspection is slow and inconsistent.

## Security Context
- Creates a timestamped record of inbound connections for triage and investigations.
- Captures source/destination details and process metadata for faster incident response.
- Reduces blind spots in host-level network monitoring.

## Architecture/Flow
![Connection logger flow](docs/connection-flow.svg)

## Setup
```bash
git clone git@github.com:jaskaranhundal/incoming-connection-logger.git
cd incoming-connection-logger
chmod +x incoming_connection_log.sh
./incoming_connection_log.sh
```

Requirements:
- Linux environment
- `ss` command available
- Permissions to inspect socket/process details

## Example Output
```text
Timestamp,Source IP,Destination IP,Source Port,Destination Port,Process
2026-02-20T09:00:01Z,10.1.0.45,10.1.0.10,54321,22,sshd(1290)
2026-02-20T09:00:11Z,198.51.100.20,10.1.0.10,50012,443,nginx(842)
```

## Limitations
- Host-level only (not full network tap/packet capture).
- Deduplication is best-effort and tuned for repetitive socket entries.
- No built-in SIEM export pipeline yet.

## Roadmap
- Add JSON output mode for log forwarding.
- Add allowlist/denylist filters.
- Add systemd service unit and retention policy support.
- Add severity tagging for suspicious source patterns.
