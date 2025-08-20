# Var Sync — /var → /varbak (systemd + rsync + logrotate)

Daily backup of `/var/` to `/varbak/` using `rsync`, managed by `systemd` with persistent file logging and log rotation.
Designed for Ubuntu 24.04+ and idempotent re-runs.

## What it does

- Creates a **systemd service** `var-sync.service` and **timer** `var-sync.timer`
- Runs **daily at 01:00 local time** (`OnCalendar=*-*-* 01:00:00`)
- Syncs `/var/` → `/varbak/` with:
  - `-aAXH --numeric-ids -x --delete-delay --partial --inplace`
  - excludes high-churn/bulk: `/cache`, `/tmp`, `/lib/docker`, `/snap`, `/lib/snapd`
- Appends output to **`/var/log/varsync.log`** (and also to systemd journal)
- Installs logrotate policy (daily, 14 copies, gzip) with `su root adm`
- Tightens `/var/log` permissions if too loose (required by logrotate)

> **Note:** This does *not* create or mount a `/varbak` partition; it assumes the destination path exists and is writable (e.g., separate disk/partition already mounted).

## Requirements

- Ubuntu 24.04+ (systemd & logrotate)
- `rsync` installed:
  ```bash
  sudo apt-get update && sudo apt-get install -y rsync
