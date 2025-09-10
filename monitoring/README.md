# Monitoring scripts

This directory contains helper scripts to monitor the application.

## `uptime.sh`
Polls `/api/health` and `/api/status` periodically. The base URL and the polling interval can be set via the `BASE_URL` and `INTERVAL` environment variables. The script exits with a non‑zero status code when any request fails.

Example:
```bash
BASE_URL=https://example.com INTERVAL=60 ./uptime.sh
```

## `tls_expiry.sh`
Checks TLS certificate expiration for a host. The script exits with status 1 when the certificate is about to expire within the provided threshold.

Usage:
```bash
./tls_expiry.sh example.com 443 30
```
The third argument is the number of days to warn before expiration.

## Scheduling and alerts

Run the scripts via `cron` or `systemd` timers and send alerts to Slack or email when they exit with a non‑zero status:

### Cron
```
* * * * * /opt/monitoring/uptime.sh || curl -X POST -H 'Content-type: application/json' --data '{"text":"API is down"}' "$SLACK_WEBHOOK_URL"
0 0 * * * /opt/monitoring/tls_expiry.sh example.com 443 30 || mail -s "TLS cert expiring" admin@example.com
```

### systemd timer
Create `/etc/systemd/system/api-uptime.service`:
```
[Unit]
Description=Check API health

[Service]
Type=oneshot
ExecStart=/opt/monitoring/uptime.sh
```
Create `/etc/systemd/system/api-uptime.timer`:
```
[Unit]
Description=Run API health check every minute

[Timer]
OnUnitActiveSec=1min
Unit=api-uptime.service

[Install]
WantedBy=timers.target
```
Enable with `systemctl enable --now api-uptime.timer`.

External services like Prometheus or UptimeRobot can also monitor these endpoints and forward alerts to Slack or email.
