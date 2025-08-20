sudo tee -a /root/.bashrc >/dev/null <<'EOF'

# === Var Sync helper ===
if [ -t 1 ] && systemctl list-unit-files | grep -q '^var-sync\.service'; then
  cat <<'TXT'

=== Var Sync: /var → /varbak — What to do ===
Run now:           sudo systemctl start var-sync.service
Check status:      systemctl status var-sync.service
View last logs:    journalctl -u var-sync.service --since '1h'
Tail file log:     sudo tail -n 100 /var/log/varsync.log
Next run time:     systemctl list-timers var-sync.timer
Timer (1:00 AM):   sudo systemctl enable --now var-sync.timer
================================================

TXT
fi
EOF
