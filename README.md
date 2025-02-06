# multi-postgres-backup-local

![Docker pulls](https://img.shields.io/docker/pulls/prodrigestivill/postgres-backup-local)
![GitHub actions](https://github.com/prodrigestivill/docker-postgres-backup-local/actions/workflows/ci.yml/badge.svg?branch=main)

Backup PostgresSQL to the local filesystem with periodic rotating backups, based on
[schickling/postgres-backup-s3](https://hub.docker.com/r/schickling/postgres-backup-s3/)
and [prodrigestivill/docker-postgres-backup-local](https://github.com/prodrigestivill/docker-postgres-backup-local).
Backup multiple databases and multiple postgres docker instances from the same host. In
order to this you need to create an env file for each postgres instance you want to
connect, and set database names in `POSTGRES_DB` env variable separated by commas or
spaces.

Supports the following Docker architectures: `linux/amd64`, `linux/arm64`,
`linux/arm/v7`, `linux/s390x`, `linux/ppc64le`.

Please consider reading detailed the [How the backups folder works?](#how-the-backups-folder-works).

This application requires the docker volume `/app/backups` to be a POSIX-compliant
filesystem to store the backups (mainly with support for hardlinks and softlinks). So
filesystems like VFAT, EXFAT, SMB/CIFS, ... can't be used with this docker image.

## Usage

Docker:

> [!WARNING]
> Please do NOT set directly env var that can be shared among postgres instances (e.g.
> POSTGRES_HOST, POSTGRES_USER, ecc.). Use dedicated env file for each instance.

Docker Compose:

```yaml
services:
  postgres:
    image: postgres:16-bookworm
    restart: always
    environment:
      - POSTGRES_DB=database
      - POSTGRES_USER=username
      - POSTGRES_PASSWORD=password
      #  - POSTGRES_PASSWORD_FILE=/run/secrets/db_password <-- alternative for POSTGRES_PASSWORD (to use with docker secrets)
  pgbackups:
    image: rizl4s/multi-postgres-backup-local:16-bookworm
    restart: always
    volumes:
      - /var/opt/pgbackups:/app/backups
      - ./envs:/app/envs
    depends_on:
      - postgres
```

For security reasons the container run with a rootless user.

Please check that backup folder has appropriate permissions.

```sh
mkdir -p /var/opt/pgbackups && chown -R 1000:1000 /var/opt/pgbackups
```

As example check also the test-compose directory in this repo.

### Environment Variables

Most variables are the same as in the [official postgres image](https://hub.docker.com/_/postgres/).

|      env variable       |                                                                                                                                     description                                                                                                                                     |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BACKUP_DIR              | Directory to save the backup at. Defaults to `/app/backups`.                                                                                                                                                                                                                        |
| BACKUP_SUFFIX           | Filename suffix to save the backup. Defaults to `.sql.gz`.                                                                                                                                                                                                                          |
| BACKUP_ON_START         | If set to `TRUE` performs an backup on each container start or restart. Defaults to `FALSE`.                                                                                                                                                                                        |
| BACKUP_KEEP_DAYS        | Number of daily backups to keep before removal. Defaults to `7`.                                                                                                                                                                                                                    |
| BACKUP_KEEP_WEEKS       | Number of weekly backups to keep before removal. Defaults to `4`.                                                                                                                                                                                                                   |
| BACKUP_KEEP_MONTHS      | Number of monthly backups to keep before removal. Defaults to `6`.                                                                                                                                                                                                                  |
| BACKUP_KEEP_MINS        | Number of minutes for `last` folder backups to keep before removal. Defaults to `1440`.                                                                                                                                                                                             |
| BACKUP_LATEST_TYPE      | Type of `latest` pointer (`symlink`,`hardlink`,`none`). Defaults to `symlink`.                                                                                                                                                                                                      |
| VALIDATE_ON_START       | If set to `FALSE` does not validate the configuration on start. Disabling this is not recommended. Defaults to `TRUE`.                                                                                                                                                              |
| HEALTHCHECK_PORT        | Port listening for cron-schedule health check. Defaults to `0` (disabled).                                                                                                                                                                                                          |
| POSTGRES_DB             | Comma or space separated list of postgres databases to backup. If POSTGRES_CLUSTER is set this refers to the database to connect to for dumping global objects and discovering what other databases should be dumped (typically is either `postgres` or `template1`). **Required**. |
| POSTGRES_DB_FILE        | Alternative to POSTGRES_DB, but with one database per line, for usage with docker secrets.                                                                                                                                                                                          |
| POSTGRES_EXTRA_OPTS     | Additional [options](https://www.postgresql.org/docs/12/app-pgdump.html#PG-DUMP-OPTIONS) for `pg_dump` (or `pg_dumpall` [options](https://www.postgresql.org/docs/12/app-pg-dumpall.html#id-1.9.4.13.6) if POSTGRES_CLUSTER is set). Defaults to `-Z1`.                             |
| POSTGRES_CLUSTER        | Set to `TRUE` in order to use `pg_dumpall` instead. Also set POSTGRES_EXTRA_OPTS to any value or empty since the default value is not compatible with `pg_dumpall`.                                                                                                                 |
| POSTGRES_HOST           | Postgres connection parameter; postgres host to connect to. **Required**.                                                                                                                                                                                                           |
| POSTGRES_HOSTNAME       | Friendly name (human readable) of the postgres instance that you want to connect to (e.g. pg-ecommerce). **Required**.                                                                                                                                                              |
| POSTGRES_PASSWORD       | Postgres connection parameter; postgres password to connect with. **Required**.                                                                                                                                                                                                     |
| POSTGRES_PASSWORD_FILE  | Alternative to POSTGRES_PASSWORD, for usage with docker secrets.                                                                                                                                                                                                                    |
| POSTGRES_PASSFILE_STORE | Alternative to POSTGRES_PASSWORD in [passfile format](https://www.postgresql.org/docs/12/libpq-pgpass.html#LIBPQ-PGPASS), for usage with postgres clusters.                                                                                                                         |
| POSTGRES_PORT           | Postgres connection parameter; postgres port to connect to. Defaults to `5432`.                                                                                                                                                                                                     |
| POSTGRES_USER           | Postgres connection parameter; postgres user to connect with. **Required**.                                                                                                                                                                                                         |
| POSTGRES_USER_FILE      | Alternative to POSTGRES_USER, for usage with docker secrets.                                                                                                                                                                                                                        |
| SCHEDULE                | [Cron-schedule](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules) specifying the interval between postgres backups. Defaults to `@daily`.                                                                                                                           |
| ENVS_DIR                | Path to directory containing env files. Defaults to `/app/envs`.                                                                                                                                                                                                                    |
| TZ                      | [POSIX TZ variable](https://www.gnu.org/software/libc/manual/html_node/TZ-Variable.html) specifying the timezone used to evaluate SCHEDULE cron (example "Europe/Paris").                                                                                                           |
| WEBHOOK_URL             | URL to be called after an error or after a successful backup (POST with a JSON payload, check `hooks/00-webhook` file for more info). Default disabled.                                                                                                                             |
| WEBHOOK_ERROR_URL       | URL to be called in case backup fails. Default disabled.                                                                                                                                                                                                                            |
| WEBHOOK_PRE_BACKUP_URL  | URL to be called when backup starts. Default disabled.                                                                                                                                                                                                                              |
| WEBHOOK_POST_BACKUP_URL | URL to be called when backup completes successfully. Default disabled.                                                                                                                                                                                                              |
| WEBHOOK_EXTRA_ARGS      | Extra arguments for the `curl` execution in the webhook (check `hooks/00-webhook` file for more info).                                                                                                                                                                              |

#### Special Environment Variables

This variables are not intended to be used for normal deployment operations:

|        env variable         |                    description                     |
| --------------------------- | -------------------------------------------------- |
| POSTGRES_PORT_5432_TCP_ADDR | Sets the POSTGRES_HOST when the latter is not set. |
| POSTGRES_PORT_5432_TCP_PORT | Sets POSTGRES_PORT when POSTGRES_HOST is not set.  |

### How the backups folder works?

First a new backup is created in the `last` folder with the full time.

Once this backup finish successfully then, it is hard linked (instead of coping to avoid
use more space) to the rest of the folders (daily, weekly and monthly). This step
replaces the old backups for that category storing always only the latest for each
category (so the monthly backup for a month is always storing the latest for that month
and not the first).

So the backup folder are structured as follows:

* `BACKUP_DIR/POSTGRES_HOSTNAME/last/DB-YYYYMMDD-HHmmss.sql.gz`: all the backups are stored
  separately in this folder.
* `BACKUP_DIR/POSTGRES_HOSTNAME/daily/DB-YYYYMMDD.sql.gz`: always store (hard link) the
  **latest** backup of that day.
* `BACKUP_DIR/POSTGRES_HOSTNAME/weekly/DB-YYYYww.sql.gz`: always store (hard link) the
  **latest** backup of that week (the last day of the week will be Sunday as it uses ISO
  week numbers).
* `BACKUP_DIR/POSTGRES_HOSTNAME/monthly/DB-YYYYMM.sql.gz`: always store (hard link) the
  **latest** backup of that month (normally the ~31st).

And the following symlinks are also updated after each successfull backup for simlicity:

```raw
BACKUP_DIR/POSTGRES_HOSTNAME/last/DB-latest.sql.gz -> BACKUP_DIR/POSTGRES_HOSTNAME/last/DB-YYYYMMDD-HHmmss.sql.gz
BACKUP_DIR/POSTGRES_HOSTNAME/daily/DB-latest.sql.gz -> BACKUP_DIR/POSTGRES_HOSTNAME/daily/DB-YYYYMMDD.sql.gz
BACKUP_DIR/POSTGRES_HOSTNAME/weekly/DB-latest.sql.gz -> BACKUP_DIR/POSTGRES_HOSTNAME/weekly/DB-YYYYww.sql.gz
BACKUP_DIR/POSTGRES_HOSTNAME/monthly/DB-latest.sql.gz -> BACKUP_DIR/POSTGRES_HOSTNAME/monthly/DB-YYYYMM.sql.gz
```

For **cleaning** the script removes the files for each category only if the new backup
has been successful. To do so it is using the following independent variables:

* BACKUP_KEEP_MINS: will remove files from the `last` folder that are older than its
  value in minutes after a new successful backup without affecting the rest of the
  backups (because they are hard links).
* BACKUP_KEEP_DAYS: will remove files from the `daily` folder that are older than its
  value in days after a new successful backup.
* BACKUP_KEEP_WEEKS: will remove files from the `weekly` folder that are older than its
  value in weeks after a new successful backup (remember that it starts counting from
  the end of each week not the beginning).
* BACKUP_KEEP_MONTHS: will remove files from the `monthly` folder that are older than
  its value in months (of 31 days) after a new successful backup (remember that it
  starts counting from the end of each month not the beginning).

### Hooks

The folder `hooks` inside the container can contain hooks/scripts to be run in
different cases getting the exact situation as a first argument (`error`, `pre-backup`
or `post-backup`).

Just create an script in that folder with execution permission so that
[run-parts](https://manpages.debian.org/stable/debianutils/run-parts.8.en.html) can
execute it on each state change.

Please, as an example take a look in the script already present there that implements
the `WEBHOOK_URL` functionality.

### Manual Backups

By default this container makes daily backups, but you can start a manual backup by
running `./app/backup.sh`.

```sh
docker exec -it <your_pgbackups_container> sh
./backup.sh
```

### Automatic Periodic Backups

You can change the `SCHEDULE` environment variable to alter the default frequency.
Default is `daily`.

More information about the scheduling can be found
[here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

Folders `daily`, `weekly` and `monthly` are created and populated using hard links to
save disk space.
