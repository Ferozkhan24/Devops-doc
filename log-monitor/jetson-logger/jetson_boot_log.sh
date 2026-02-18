#!/bin/sh

# ==============================================================
# Jetson Boot Logger
# Sends a "Jetson Started" log to the API on every boot.
# ==============================================================

LOG_FILE="/home/feroz/log-monitor/jetson-logger/logs/jetson_lifecycle.log"
API_URL="http://192.168.1.16:4500/log"
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

MSG="$TIMESTAMP | $HOSTNAME | INFO | Jetson Started"

# Log locally
echo "$MSG" >> "$LOG_FILE"

# Send to API
JSON_PACKET="{\"message\":\"$MSG\"}"

if curl -s --max-time 10 --retry 3 --retry-delay 5 \
    -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PACKET" > /dev/null 2>&1; then
    echo "$TIMESTAMP | $HOSTNAME | INFO | Boot log sent to API" >> "$LOG_FILE"
else
    echo "$TIMESTAMP | $HOSTNAME | ERROR | Failed to send boot log to API" >> "$LOG_FILE"
fi
