#!/usr/bin/env bash
set -Eeo pipefail

# Check if ENVS_DIR is empty or does not exist
if [[ ! -d "$ENVS_DIR" || -z "$(ls -A "$ENVS_DIR"/*.env)" ]]; then
    echo "Error: No environment files found in $ENVS_DIR. Exiting." >&2
    exit 1
fi

# Prevalidate configuration (don't source)
# if [ "${VALIDATE_ON_START}" = "TRUE" ]; then
#     /env.sh
# fi

for ENV_FILE in "${ENVS_DIR}"/*.env; do
    echo "Loading environment variables from ${ENV_FILE}"
    source "${ENV_FILE}"
    
    EXTRA_ARGS=""
    if [ "${BACKUP_ON_START}" = "TRUE" ]; then
        EXTRA_ARGS="-i"
    fi
    
    echo "Starting backup scheduler for databases: ${POSTGRES_DB} on schedule: ${SCHEDULE}"
    /usr/local/bin/go-cron -s "$SCHEDULE" -p "$HEALTHCHECK_PORT" $EXTRA_ARGS -- $(dirname "$0")/backup.sh $ENV_FILE &
done

# Keep the container running
wait
