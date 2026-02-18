# Jetson Lifecycle Logger

> **Part of [log-monitor](file:///home/feroz/log-monitor)**

## About log-monitor

`log-monitor` is a Docker-based monitoring system that runs on the Jetson device. It:

- Runs a container (`log-monitor`) built from the local `Dockerfile`
- Monitors **CPU & memory usage** inside the container via `system_error_check.sh`
- Sends alerts to the API at `http://192.168.1.16:4500/log` when usage hits **≥ 90%**
- Logs all events to `logs/system_errors.log`
- Resource limits: **2 CPUs**, **1024 MB RAM**

**`jetson-logger`** extends this by also capturing **Jetson device-level** boot and shutdown events into the same `logs/system_errors.log`, giving a complete picture:

```
Jetson boots  →  Container starts  →  Resource alerts  →  Container stops  →  Jetson shuts down
```

---

Logs Jetson **boot** and **shutdown** events to the shared log file and sends them to the API.

## Files

| File | Purpose |
|------|---------|
| `jetson_boot_log.sh` | Runs on boot — logs & sends "Jetson Started" |
| `jetson_shutdown_log.sh` | Runs on shutdown — logs & sends "Jetson Stopped" |

## Log Output

Both scripts write to the shared log file:

```
/home/feroz/log-monitor/logs/system_errors.log
```

**Log format:**
```
2026-02-18 10:00:05 | jetson-nano | INFO | Jetson Started
2026-02-18 18:30:00 | jetson-nano | INFO | Jetson Stopped
2026-02-18 18:30:00 | jetson-nano | INFO | Jetson Stopped | API ERROR
```

- If API succeeds → clean single line, no suffix
- If API fails → appends `| API ERROR`

## Sample Output (`logs/system_errors.log`)

This is how the **complete log file** looks combining both Jetson and container events:

```
2026-02-18 10:00:05 | jetson-nano | INFO | Jetson Started
2026-02-18 10:00:10 | a1b2c3d4e5f6 | log-monitor | INFO | Container Started
2026-02-18 10:15:00 | a1b2c3d4e5f6 | log-monitor | ERROR | cpu=95% | mem=45%
2026-02-18 10:25:00 | a1b2c3d4e5f6 | log-monitor | INFO | Container Stopped
2026-02-18 10:25:05 | jetson-nano | INFO | Jetson Stopped
2026-02-18 10:25:05 | jetson-nano | INFO | Jetson Stopped | API ERROR
```

| Field | Example | Meaning |
|-------|---------|---------|
| `TIMESTAMP` | `2026-02-18 10:00:05` | Date and time of event |
| `HOSTNAME` | `jetson-nano` | Jetson hostname or container ID |
| `NAME` | `log-monitor` | Container name (container logs only) |
| `LEVEL` | `INFO` / `ERROR` | Log severity |
| `EVENT` | `Jetson Started` / `cpu=95%` | What happened |
| `API ERROR` | _(only if API failed)_ | API was unreachable |

## API

Both scripts POST to:

```
http://192.168.1.16:4500/log
```

Payload:
```json
{ "message": "2026-02-18 10:00:05 | jetson-nano | INFO | Jetson Started" }
```

## Setup

### 1. Make scripts executable

```bash
chmod +x /home/feroz/log-monitor/jetson-logger/jetson_boot_log.sh
chmod +x /home/feroz/log-monitor/jetson-logger/jetson_shutdown_log.sh
```

### 2. Create systemd service for boot

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

### 3. Create systemd service for shutdown

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

### 5. Test manually

```bash
sudo systemctl start jetson-boot-logger.service
cat /home/feroz/log-monitor/logs/system_errors.log
```
