#!/usr/bin/env bash
set -Eeo pipefail

mkdir /logs
ENVS_DIR="/envs"

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
    
    echo "Starting backup scheduler for databases: ${POSTGRES_DBS} on schedule: ${SCHEDULE}"
    /usr/local/bin/go-cron -s "$SCHEDULE" -p "$HEALTHCHECK_PORT" $EXTRA_ARGS -- /backup.sh $ENV_FILE &
done

# Keep the container running
wait
