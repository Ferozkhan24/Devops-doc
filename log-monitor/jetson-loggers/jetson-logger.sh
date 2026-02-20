#!/bin/sh

# ==============================================================
# Jetson Logger (Unified)
# Usage: ./jetson_logger.sh [start|stop]
# Logs "Jetson Started" or "Jetson Stopped" to the API.
# ==============================================================

ACTION=$1
LOG_FILE="/home/robotoai/DockerNew/log-monitor/logs/system_errors.log"
API_URL="http://192.168.0.100:4500/log"
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

case "$ACTION" in
    start)
        # Wait for network (especially important on laptop Wi-Fi)
        sleep 10
        MSG="Jetson Started"
        TIMEOUT=10
        ;;
    stop)
        MSG="Jetson Stopped"
        # Short timeout since system is shutting down
        TIMEOUT=5
        ;;
    *)
        echo "Usage: $0 [start|stop]"
        exit 1
        ;;
esac

BASE_MSG="$TIMESTAMP | $HOSTNAME | INFO | $MSG"
JSON_PACKET="{\"message\":\"$BASE_MSG\"}"

# Send to API
if curl -s --max-time "$TIMEOUT" --retry 3 --retry-delay 5 \
    -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PACKET" > /dev/null 2>&1; then
    echo "$BASE_MSG" >> "$LOG_FILE"
else
    echo "$BASE_MSG | API ERROR" >> "$LOG_FILE"
fi
