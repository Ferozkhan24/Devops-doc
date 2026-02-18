#!/bin/sh

# ==============================================================
# Jetson Boot Logger
# Sends a "Jetson Started" log to the API on every boot.
# ==============================================================

LOG_FILE="/home/feroz/log-monitor/logs/system_errors.log"
API_URL="http://192.168.1.16:4500/log"
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

BASE_MSG="$TIMESTAMP | $HOSTNAME | INFO | Jetson Started"

# Send to API
JSON_PACKET="{\"message\":\"$BASE_MSG\"}"

if curl -s --max-time 10 --retry 3 --retry-delay 5 \
    -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PACKET" > /dev/null 2>&1; then
    echo "$BASE_MSG" >> "$LOG_FILE"
else
    echo "$BASE_MSG | API ERROR" >> "$LOG_FILE"
fi