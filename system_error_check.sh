#!/bin/sh

LOG_FILE="/logs/system_errors.log"
API_URL="http://192.168.0.100:4500/log"
CPU_THRESHOLD=90
MEM_THRESHOLD=90
NAME=$(hostname)

# Create log file if it doesn't exist
touch "$LOG_FILE"

ALERT_SENT=0

while true; do
    TS=$(date '+%Y-%m-%d %H:%M:%S')

    ##### CPU (delta-based) #####
    # Read /proc/stat
    CPU_STAT=$(grep '^cpu ' /proc/stat)
    if [ -z "$CPU_STAT" ]; then
        MSG="$TS | $NAME | ERROR | Failed to read /proc/stat"
        echo "$MSG" | tee -a "$LOG_FILE"
        curl -X POST "$API_URL" -H "Content-Type: application/json" -d "{\"message\":\"$MSG\"}"
        sleep 10
        continue
    fi

    set -- $CPU_STAT
    IDLE1=$5
    TOTAL1=$(( $2+$3+$4+$5+$6+$7+$8 ))

    sleep 1

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
            echo "$MSG" | tee -a "$LOG_FILE"
            curl -s -X POST "$API_URL" \
                 -H "Content-Type: application/json" \
                 -d "{\"message\":\"$MSG\"}" > /dev/null &
            ALERT_SENT=1
        fi
    else
        # Reset alert flag once resources return to normal
        ALERT_SENT=0
    fi

    sleep 10
done
 
