#!/bin/sh

LOG_FILE="/app/logs/system_errors.log"
API_URL="http://192.168.1.16:4500/log"
CPU_THRESHOLD=90
MEM_THRESHOLD=90
# Container ID is the hostname
CONTAINER_ID=$(hostname)
# Container Name is passed via environment variable
CONTAINER_NAME=${CONTAINER_NAME:-"unknown"}
NAME="$CONTAINER_ID | $CONTAINER_NAME"

# Function to send log to API with error handling
send_to_api() {
    local plain_msg="$1"
    local json_packet="{\"message\":\"$plain_msg\"}"
    
    # Added --max-time 2 to prevent shutdown hang if API is unreachable
    if curl -s --max-time 2 -X POST "$API_URL" -H "Content-Type: application/json" -d "$json_packet" > /dev/null; then
        echo "$plain_msg" >> "$LOG_FILE"
    else
        echo "$plain_msg | API ERROR" >> "$LOG_FILE"
    fi
}

ALERT_SENT=0
ENTRY_TS=$(date '+%Y-%m-%d %H:%M:%S')
MSG="$ENTRY_TS | $NAME | INFO | Container Started"
send_to_api "$MSG"

cleanup() {
    EXIT_TS=$(date '+%Y-%m-%d %H:%M:%S')
    MSG="$EXIT_TS | $NAME | INFO | Container Stopped"
    send_to_api "$MSG"
    exit 0
}

trap cleanup INT TERM

while true; do
    TS=$(date '+%Y-%m-%d %H:%M:%S')

    ##### CPU (delta-based) #####
    # Read /proc/stat
    CPU_STAT=$(grep '^cpu ' /proc/stat)
    if [ -z "$CPU_STAT" ]; then
        MSG="$TS | $NAME | ERROR | Failed to read /proc/stat"
        send_to_api "$MSG"
        sleep 2 & wait $!
        continue
    fi

    set -- $CPU_STAT
    IDLE1=$5
    TOTAL1=$(( $2+$3+$4+$5+$6+$7+$8 ))

    sleep 1 & wait $!

    CPU_STAT=$(grep '^cpu ' /proc/stat)
    set -- $CPU_STAT
    IDLE2=$5
    TOTAL2=$(( $2+$3+$4+$5+$6+$7+$8 ))

    CPU=0
    DT=$((TOTAL2 - TOTAL1))
    DI=$((IDLE2 - IDLE1))
    [ "$DT" -gt 0 ] && CPU=$(( (100 * (DT - DI)) / DT ))

    ##### MEMORY (container-aware via cgroups v1/v2) #####
    MEM=0
    # Cgroup V2
    if [ -r /sys/fs/cgroup/memory.current ] && [ -r /sys/fs/cgroup/memory.max ]; then
        CUR=$(cat /sys/fs/cgroup/memory.current)
        MAX=$(cat /sys/fs/cgroup/memory.max)
        if [ "$MAX" != "max" ] && [ "$MAX" -gt 0 ]; then
            MEM=$(( CUR * 100 / MAX ))
        fi
    # Cgroup V1
    elif [ -r /sys/fs/cgroup/memory/memory.usage_in_bytes ] && [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        CUR=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes)
        MAX=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
        # Check if limit is set (v1 often uses a very large number for 'no limit')
        if [ "$MAX" -lt $(( 1 << 60 )) ] 2>/dev/null && [ "$MAX" -gt 0 ]; then
            MEM=$(( CUR * 100 / MAX ))
        fi
    fi


    ##### LOGIC: CPU OR MEMORY >= Threshold (Log only once per incident) #####
    if [ "$CPU" -ge "$CPU_THRESHOLD" ] || [ "$MEM" -ge "$MEM_THRESHOLD" ]; then
        if [ "$ALERT_SENT" -eq 0 ]; then
            MSG="$TS | $NAME | ERROR | cpu=${CPU}% | mem=${MEM}%"
            send_to_api "$MSG"
            ALERT_SENT=1
        fi
    else
        # Reset alert flag once resources return to normal
        ALERT_SENT=0
    fi

    sleep 2 & wait $!
done
 