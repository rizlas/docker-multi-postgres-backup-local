#!/usr/bin/env bash
set -Eeo pipefail

FAILED=0

# Check if ENVS_DIR is empty or does not exist
if [[ ! -d "$ENVS_DIR" || -z "$(ls -A "$ENVS_DIR"/*.env)" ]]; then
    echo "Error: No environment files found in $ENVS_DIR. Exiting." >&2
    exit 1
fi

for ENV_FILE in "$ENVS_DIR"/*.env; do
    source "$ENV_FILE"
    
    if [[ -z "$HEALTHCHECK_PORT" || "$HEALTHCHECK_PORT" -eq 0 ]]; then
        # echo "Warning: HEALTHCHECK_PORT not defined or set to 0 in $ENV_FILE. Skipping."
        continue
    fi
    
    if ! curl -sf "http://localhost:$HEALTHCHECK_PORT/" >/dev/null; then
        echo "Health check failed for port $HEALTHCHECK_PORT using $ENV_FILE env file!"
        FAILED=1
    fi
done

if [[ $FAILED -eq 1 ]]; then
    exit 1
else
    exit 0
fi
