#!/bin/bash

# Configuration
CONTAINER_NAME="my_container"
COMPOSE_DIR="/home/feroz/log-monitor"
INTERVAL=10

echo "Starting Internet Checker for container: $CONTAINER_NAME"
echo "Monitoring interval: ${INTERVAL}s"

while true; do

    # 1. Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
        echo "Container '$CONTAINER_NAME' does not exist → Attempting to bring it up..."
        if [ -d "$COMPOSE_DIR" ]; then
            cd "$COMPOSE_DIR" || { echo "Failed to enter $COMPOSE_DIR"; exit 1; }
            docker compose up -d
        else
            echo "Error: COMPOSE_DIR '$COMPOSE_DIR' not found."
        fi
        sleep $INTERVAL
        continue
    fi

    # 2. Check internet
    if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        INTERNET=true
    else
        INTERNET=false
    fi

    # 3. Check container state
    RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)

    # 4. Internet ON + container stopped → START
    if [ "$INTERNET" = true ]; then
        if [ "$RUNNING" = "false" ]; then
            echo "Internet ON + container stopped → Starting container..."
            if [ -d "$COMPOSE_DIR" ]; then
                cd "$COMPOSE_DIR" || exit 1
                docker compose start
            else
                docker start "$CONTAINER_NAME"
            fi
        fi
    else
        # 5. Internet OFF + container running → STOP
        if [ "$RUNNING" = "true" ]; then
            echo "Internet OFF + container running → Stopping container..."
            docker stop "$CONTAINER_NAME"
        fi
    fi

    sleep $INTERVAL
done