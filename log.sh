#!/usr/bin/env bash

# Check if ENV_FILE is not empty
if [ -s "$ENV_FILE" ]; then
    LOG_FILE="$(dirname "$0")/logs/$(basename "${ENV_FILE}" | sed -r 's/\..+$//').log"
    # Clears the log file
    > "$LOG_FILE"
fi

logm() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local level=$1
    local message=$2
    
    # Default level info so message is first param (no level specified)
    if [[ "$level" != "error" && "$level" != "info" ]]; then
        level="info"
        message=$1
    fi
    
    if [[ "$level" == "error" ]]; then
        echo "$timestamp [ERROR] $message" | tee -a "$LOG_FILE" >&2
    else
        echo "$timestamp [INFO] $message" | tee -a "$LOG_FILE"
    fi
}
