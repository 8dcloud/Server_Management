# Var Sync — `/var` → `/varbak` (systemd + rsync + logrotate)

Daily backup of `/var/` to `/varbak/` using `rsync`, managed by **systemd** with persistent file logging and **logrotate**.  
Designed for Ubuntu 24.04+ and safe to re-run (idempotent).

---

## What It Does

- Creates a **systemd service** `var-sync.service` and **timer** `var-sync.timer`.
- Runs **daily at 01:00 local time** (`OnCalendar=*-*-* 01:00:00`, with catch-up if missed).
- Syncs `/var/` → `/varbak/` using:
  - `-aAXH --numeric-ids -x --delete-delay --partial --inplace`
  - Excludes high-churn/bulk: `/cache`, `/tmp`, `/lib/docker`, `/snap`, `/lib/snapd`
- Appends output to **`/var/log/varsync.log`** (also available via `journalctl`).
- Installs a logrotate policy (daily, 14 copies, gzip) with `su root adm`.
- Tightens `/var/log` permissions if needed (required by logrotate).

> Note: This does **not** create or mount a `/varbak` partition; it assumes `/varbak` already exists and is writable (e.g., separate disk/partition is mounted).

---

## Repo Layout

    .
    ├─ scripts/
    │  └─ setup_varsync.sh         # one-shot installer (service, timer, logging, logrotate)
    └─ README.md                    # this file

---

## Requirements

- Ubuntu 24.04+ (systemd, logrotate present by default).
- `rsync` installed:

    sudo apt-get update && sudo apt-get install -y rsync

---

## Install

Run the setup script (idempotent):

    sudo bash scripts/setup_varsync.sh

This will:

1. Write units to `/etc/systemd/system/`:
   - `var-sync.service`
   - `var-sync.timer` (daily at 01:00)
2. Create `/var/log/varsync.log` with `root:adm 0640`.
3. Install `/etc/logrotate.d/varsync`.
4. Tighten `/var/log` directory permissions if too loose.
5. Enable the timer and trigger an initial sync.
6. Print the next scheduled runtime.

---

## Verify

    systemctl status var-sync.service
    journalctl -u var-sync.service --since "today"
    tail -n 100 /var/log/varsync.log
    systemctl list-timers var-sync.timer

Successful runs will show **START/END** markers and `rsync` stats in `/var/log/varsync.log`.

---

## Operator Cheat Sheet (What To Do)

    Run now:           sudo systemctl start var-sync.service
    Check status:      systemctl status var-sync.service
    View last logs:    journalctl -u var-sync.service --since '1h'
    Tail file log:     sudo tail -n 100 /var/log/varsync.log
    Next run time:     systemctl list-timers var-sync.timer
    Enable timer:      sudo systemctl enable --now var-sync.timer
    Disable timer:     sudo systemctl disable --now var-sync.timer

*(If you want this printed at every login, add a small snippet to `~/.bashrc` or `/etc/profile.d/`.)*

---

## Customize

- **Destination path:** edit `DST="/varbak/"` in `scripts/setup_varsync.sh`.
- **Schedule:** change `OnCalendar` in `/etc/systemd/system/var-sync.timer`.
  - Example hourly: `OnCalendar=hourly`
  - Example every 15 min (for testing): `OnCalendar=*:0/15`
- **Excludes:** edit the `--exclude` lines in the service’s `ExecStart`.
- **ACLs/xattrs:** `-A -X` are enabled. If your destination FS doesn’t support them, remove those flags to avoid warnings.

---

## Common Issues & Fixes

### 1) Logrotate: “insecure parent directory”
Logrotate refuses to rotate if `/var/log` is group-writable.

    # Fix perms:
    sudo chmod 0755 /var/log

Ensure `/etc/logrotate.d/varsync` uses `su`:

    /var/log/varsync.log {
        su root adm
        rotate 14
        daily
        missingok
        notifempty
        compress
        delaycompress
        create 0640 root adm
    }

### 2) Destination is read-only / lacks space

    df -h /varbak
    sudo mount -o remount,rw /varbak

### 3) Lots of churn (Docker, snaps)
Keep the provided excludes or add more per your environment.

### 4) rsync ACL/xattr warnings
If `/varbak` FS doesn’t support ACLs/xattrs, remove `-A -X` from the `ExecStart` line.

---

## Run On Demand

    sudo systemctl start var-sync.service

---

## Uninstall

    sudo systemctl disable --now var-sync.timer
    sudo rm -f /etc/systemd/system/var-sync.timer /etc/systemd/system/var-sync.service
    sudo systemctl daemon-reload
    sudo rm -f /etc/logrotate.d/varsync /var/log/varsync.log

---

## Security Notes

- `/var/log/varsync.log` is `root:adm 0640`.
  - Add users to the `adm` group if they need read access.
- The service runs as **root** to preserve ownership/ACLs and read all of `/var`.

---

## License

MIT (or your internal license).
