ARG BASETAG=alpine
FROM postgres:$BASETAG

ARG TARGETOS
ARG TARGETARCH
ARG GO_CRON_VERSION=v0.0.11
ARG GO_CRON_URL=https://github.com/prodrigestivill/go-cron/releases/download/$GO_CRON_VERSION/go-cron-$TARGETOS-$TARGETARCH-static.gz
ARG UID=1000
ARG GID=1000
ARG USER=pbl
ARG GROUP=pbl

RUN <<EOF
set -x
apk update
apk add --no-cache ca-certificates curl
curl --fail --retry 4 --retry-all-errors -L $GO_CRON_URL | zcat > /usr/local/bin/go-cron
addgroup -g $GID $GROUP && adduser -D -u $UID -G $GROUP $USER
chown $USER:$GROUP /usr/local/bin/go-cron
chmod a+x /usr/local/bin/go-cron
EOF

ENV POSTGRES_DB="**None**" \
  POSTGRES_DB_FILE="**None**" \
  POSTGRES_HOSTNAME="**None**" \
  POSTGRES_HOST="**None**" \
  POSTGRES_PORT=5432 \
  POSTGRES_USER="**None**" \
  POSTGRES_USER_FILE="**None**" \
  POSTGRES_PASSWORD="**None**" \
  POSTGRES_PASSWORD_FILE="**None**" \
  POSTGRES_PASSFILE_STORE="**None**" \
  POSTGRES_EXTRA_OPTS="-Z1" \
  POSTGRES_CLUSTER="FALSE" \
  SCHEDULE="@daily" \
  ENVS_DIR="/app/envs" \
  VALIDATE_ON_START="TRUE" \
  BACKUP_ON_START="FALSE" \
  BACKUP_DIR="/app/backups" \
  BACKUP_SUFFIX=".sql.gz" \
  BACKUP_LATEST_TYPE="symlink" \
  BACKUP_KEEP_DAYS=7 \
  BACKUP_KEEP_WEEKS=4 \
  BACKUP_KEEP_MONTHS=6 \
  BACKUP_KEEP_MINS=1440 \
  HEALTHCHECK_PORT=0 \
  WEBHOOK_URL="**None**" \
  WEBHOOK_ERROR_URL="**None**" \
  WEBHOOK_PRE_BACKUP_URL="**None**" \
  WEBHOOK_POST_BACKUP_URL="**None**" \
  WEBHOOK_EXTRA_ARGS=""

WORKDIR /app

COPY --chown=$USER:$GROUP hooks hooks
COPY --chown=$USER:$GROUP backup.sh env.sh init.sh log.sh ./

RUN mkdir $BACKUP_DIR && chown -R $USER:$GROUP /app && chmod +x /app/*.sh

USER $USER

ENTRYPOINT ["sh", "init.sh"]
