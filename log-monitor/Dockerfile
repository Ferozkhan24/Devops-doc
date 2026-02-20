FROM ros:humble-ros-base

# Install dependencies, turtlesim, tzdata, and curl
RUN apt-get update && apt-get install -y \
    ros-humble-turtlesim \
    procps \
    stress-ng \
    tzdata \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY system_error_check.sh .
RUN chmod +x system_error_check.sh

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["./system_error_check.sh"]
