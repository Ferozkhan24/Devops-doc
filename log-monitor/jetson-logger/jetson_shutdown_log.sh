#!/bin/sh

# ==============================================================
# Jetson Shutdown Logger
# Sends a "Jetson Stopped" log to the API on shutdown/reboot.
# ==============================================================

LOG_FILE="/home/feroz/log-monitor/jetson-logger/logs/jetson.log"
API_URL="http://192.168.1.16:4500/log"
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

MSG="$TIMESTAMP | $HOSTNAME | INFO | Jetson Stopped"

# Log locally
echo "$MSG" >> "$LOG_FILE"

# Send to API (short timeout since system is shutting down)
JSON_PACKET="{\"message\":\"$MSG\"}"

if curl -s --max-time 5 \
    -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PACKET" > /dev/null 2>&1; then
    echo "$TIMESTAMP | $HOSTNAME | INFO | Shutdown log sent to API" >> "$LOG_FILE"
else
    echo "$TIMESTAMP | $HOSTNAME | ERROR | Failed to send shutdown log to API" >> "$LOG_FILE"
fi
