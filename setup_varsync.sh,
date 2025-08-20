#!/usr/bin/env bash
# =============================================================================
# Component:   setup_varsync.sh
# Description: Configure daily rsync from /var → /varbak using systemd + logrotate
# File Path:   scripts/setup_varsync.sh
# Created:     2025-08-20
# Maintainer:  8Dweb Ops (Matthew J. Sine)
# Version:     1.1.0
#
# Features:
#   - Creates systemd service (var-sync.service) and timer (var-sync.timer)
#   - Runs daily at 01:00 local time (Persistent=true catchup)
#   - Appends run output to /var/log/varsync.log + keeps journal logs
#   - Logrotate policy: daily, 14 copies, gzip, su root:adm
#   - Tightens /var/log permissions if too loose (required by logrotate)
#   - Excludes common churn/bulk paths under /var (cache, tmp, Docker, Snap)
#   - Safe to re-run (idempotent)
#
# Dependencies:
#   - Ubuntu 24.04+ (systemd, logrotate present by default)
#   - rsync (apt install rsync)
#
# Usage:
#   sudo bash scripts/setup_varsync.sh
#
# Uninstall:
#   sudo systemctl disable --now var-sync.timer
#   sudo rm -f /etc/systemd/system/var-sync.timer /etc/systemd/system/var-sync.service
#   sudo systemctl daemon-reload
#   sudo rm -f /etc/logrotate.d/varsync /var/log/varsync.log
#
# =============================================================================

set -euo pipefail

# -----------------------------
# Tunables
# -----------------------------
SRC="/var/"          # Trailing slash => copy contents of /var
DST="/varbak/"       # Ensure this is on the target partition
LOG="/var/log/varsync.log"
SERVICE="/etc/systemd/system/var-sync.service"
TIMER="/etc/systemd/system/var-sync.timer"
LOGROTATE="/etc/logrotate.d/varsync"

# -----------------------------
# Pre-flight checks
# -----------------------------
if ! command -v rsync >/dev/null 2>&1; then
  echo "ERROR: rsync not found. Install it: sudo apt-get update && sudo apt-get install -y rsync"
  exit 1
fi

# Ensure destination exists (does not create/mount a partition; assumes /varbak is ready)
mkdir -p "$DST"

# -----------------------------
# Write systemd service unit
# -----------------------------
cat > "$SERVICE" <<'EOF'
[Unit]
Description=Sync /var to /varbak
# Ensures source/destination are mounted before this runs
RequiresMountsFor=/var /varbak
# Only run if destination directory exists
ConditionPathIsDirectory=/varbak

[Service]
Type=oneshot
# Be nice to CPU and disks
Nice=10
IOSchedulingClass=idle

# Ensure target exists (idempotent)
ExecStartPre=/usr/bin/mkdir -p /varbak

# Mark start time in the log (ISO-8601)
ExecStartPre=/usr/bin/bash -lc 'echo "--- [$(date -Is)] var-sync START ---" >> /var/log/varsync.log'

# The sync (key flags explained):
#   -aAXH        archive + ACLs + xattrs + hardlinks
#   --numeric-ids preserve numeric IDs (avoid username lookups)
#   -x           do not cross filesystem boundaries (stay on /var)
#   --delete-delay defer deletions to end for safety during churn
#   --partial --inplace better for large files and restarts
#   --info=stats2,progress2 concise progress + end stats
#   --human-readable human-friendly byte units
#   Excludes: cache/tmp/docker/snap (reduce churn and bulk)
ExecStart=/usr/bin/rsync -aAXH --numeric-ids -x \
  --delete-delay --partial --inplace \
  --info=stats2,progress2 --human-readable \
  --exclude='/cache/***' \
  --exclude='/tmp/***' \
  --exclude='/lib/docker/***' \
  --exclude='/snap/***' \
  --exclude='/lib/snapd/***' \
  /var/ /varbak/

# Mark end time & exit code
ExecStartPost=/usr/bin/bash -lc 'echo "--- [$(date -Is)] var-sync END (code=$?) ---" >> /var/log/varsync.log'

# Append both stdout/stderr to a persistent logfile (still goes to journal)
StandardOutput=append:/var/log/varsync.log
StandardError=append:/var/log/varsync.log
EOF

# -----------------------------
# Write systemd timer (daily 01:00)
# -----------------------------
cat > "$TIMER" <<'EOF'
[Unit]
Description=Run var-sync daily at 1:00 AM

[Timer]
OnCalendar=*-*-* 01:00:00
Persistent=true
AccuracySec=1m

[Install]
WantedBy=timers.target
EOF

# -----------------------------
# Ensure logfile exists with sane perms
#   - owner root:adm
#   - mode 0640
#   (journal still captures output regardless)
# -----------------------------
touch "$LOG"
chown root:adm "$LOG"
chmod 0640 "$LOG"

# -----------------------------
# Tighten /var/log directory perms if needed
# logrotate refuses insecure parents (must not be group-writable)
# Ubuntu default: drwxr-xr-x root:syslog (0755)
# -----------------------------
# Remove group write if present
chmod g-w /var/log || true
# Ensure directory is at most 0755 (avoid 0775/0777)
current_mode="$(stat -c '%a' /var/log)"
if [ "$current_mode" -gt 755 ]; then
  chmod 0755 /var/log
fi
# Note: owner/group may be root:syslog or root:root; both are acceptable here.

# -----------------------------
# Install logrotate policy
# -----------------------------
cat > "$LOGROTATE" <<'EOF'
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
EOF

# -----------------------------
# Reload systemd and enable timer
# -----------------------------
systemctl daemon-reload
systemctl enable --now var-sync.timer

# -----------------------------
# Kick an initial run (on-demand) to verify & show logs
# -----------------------------
echo "Running an initial sync now..."
if systemctl start var-sync.service; then
  echo "Initial sync started. Recent log output:"
  tail -n 50 "$LOG" || true
else
  echo "WARNING: var-sync.service start returned non-zero; check: journalctl -u var-sync.service"
fi

# -----------------------------
# Show next scheduled run (for operator sanity)
# -----------------------------
echo
echo "Timer status:"
systemctl list-timers var-sync.timer || true

echo
echo "Setup complete."
echo "• Service:   $SERVICE"
echo "• Timer:     $TIMER"
echo "• Log file:  $LOG  (rotated daily, 14 copies)"
echo
echo "Useful commands:"
echo "  systemctl start var-sync.service          # run on demand"
echo "  systemctl status var-sync.service"
echo "  journalctl -u var-sync.service --since 'today'"
echo "  tail -n 100 $LOG"
