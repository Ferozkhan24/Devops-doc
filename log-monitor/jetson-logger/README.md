# Jetson Lifecycle Logger

Logs Jetson **boot** and **shutdown** events to a local file and sends them to the API.

## Files

| File | Purpose |
|------|---------|
| `jetson_boot_log.sh` | Runs on boot — sends "Jetson Started" |
| `jetson_shutdown_log.sh` | Runs on shutdown — sends "Jetson Stopped" |
| `logs/jetson_lifecycle.log` | Local log file (auto-created) |

## Setup

### 1. Make scripts executable

```bash
chmod +x /home/feroz/log-monitor/jetson-logger/jetson_boot_log.sh
chmod +x /home/feroz/log-monitor/jetson-logger/jetson_shutdown_log.sh
```

### 2. Create systemd service for boot logging

```bash
sudo tee /etc/systemd/system/jetson-boot-logger.service > /dev/null <<EOF
[Unit]
Description=Send Jetson Boot Log to API
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/home/feroz/log-monitor/jetson-logger/jetson_boot_log.sh

[Install]
WantedBy=multi-user.target
EOF
```

### 3. Create systemd service for shutdown logging

```bash
sudo tee /etc/systemd/system/jetson-shutdown-logger.service > /dev/null <<EOF
[Unit]
Description=Send Jetson Shutdown Log to API
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/home/feroz/log-monitor/jetson-logger/jetson_shutdown_log.sh

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF
```

### 4. Enable the services

```bash
sudo systemctl daemon-reload
sudo systemctl enable jetson-boot-logger.service
sudo systemctl enable jetson-shutdown-logger.service
```

### 5. Test

```bash
# Test boot logger manually
sudo systemctl start jetson-boot-logger.service

# Check the log
cat /home/feroz/log-monitor/jetson-logger/logs/jetson_lifecycle.log
```

## API Payload

Both scripts send a JSON payload to `http://192.168.1.16:4500/log`:

```json
{
  "message": "2026-02-18 16:30:00 | jetson-nano | INFO | Jetson Started"
}
```

## Log Format

```
2026-02-18 10:00:05 | jetson-nano | INFO | Jetson Started
2026-02-18 10:00:05 | jetson-nano | INFO | Boot log sent to API
2026-02-18 18:30:00 | jetson-nano | INFO | Jetson Stopped
2026-02-18 18:30:00 | jetson-nano | INFO | Shutdown log sent to API
```
