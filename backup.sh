#!/usr/bin/env bash
set -Eeo pipefail

ENV_FILE=$1

# Init log system
mkdir -p $(dirname "$0")/logs
source "$(dirname "$0")/log.sh"

logm "Loading environment variables from ${ENV_FILE}"
source "${ENV_FILE}"

HOOKS_DIR="/hooks"
if [ -d "${HOOKS_DIR}" ]; then
    on_error(){
        run-parts -a "error" "${HOOKS_DIR}"
    }
    trap 'on_error' ERR
fi

source "$(dirname "$0")/env.sh"

# Pre-backup hook
if [ -d "${HOOKS_DIR}" ]; then
    run-parts -a "pre-backup" --exit-on-error "${HOOKS_DIR}"
fi

BACKUP_DIR=$BACKUP_DIR/$POSTGRES_HOSTNAME

#Loop all databases
for DB in ${POSTGRES_DBS}; do
    #Initialize dirs
    mkdir -p "${BACKUP_DIR}/last/" "${BACKUP_DIR}/daily/" "${BACKUP_DIR}/weekly/" "${BACKUP_DIR}/monthly/"
    
    #Initialize filename vers
    LAST_FILENAME="${DB}-`date +%Y%m%d-%H%M%S`${BACKUP_SUFFIX}"
    DAILY_FILENAME="${DB}-`date +%Y%m%d`${BACKUP_SUFFIX}"
    WEEKLY_FILENAME="${DB}-`date +%G%V`${BACKUP_SUFFIX}"
    MONTHY_FILENAME="${DB}-`date +%Y%m`${BACKUP_SUFFIX}"
    FILE="${BACKUP_DIR}/last/${LAST_FILENAME}"
    DFILE="${BACKUP_DIR}/daily/${DAILY_FILENAME}"
    WFILE="${BACKUP_DIR}/weekly/${WEEKLY_FILENAME}"
    MFILE="${BACKUP_DIR}/monthly/${MONTHY_FILENAME}"
    #Create dump
    if [ "${POSTGRES_CLUSTER}" = "TRUE" ]; then
        logm "Creating cluster dump of ${DB} database from ${POSTGRES_HOST}..."
        pg_dumpall -l "${DB}" ${POSTGRES_EXTRA_OPTS} | gzip > "${FILE}"
    else
        logm "Creating dump of ${DB} database from ${POSTGRES_HOST}..."
        pg_dump -d "${DB}" -f "${FILE}" ${POSTGRES_EXTRA_OPTS}
    fi
    #Copy (hardlink) for each entry
    if [ -d "${FILE}" ]; then
        DFILENEW="${DFILE}-new"
        WFILENEW="${WFILE}-new"
        MFILENEW="${MFILE}-new"
        rm -rf "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
        mkdir "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
        (
            # Allow to hardlink more files than max arg list length
            # first CHDIR to avoid possible space problems with BACKUP_DIR
            cd "${FILE}"
            for F in *; do
                ln -f "$F" "${DFILENEW}/"
                ln -f "$F" "${WFILENEW}/"
                ln -f "$F" "${MFILENEW}/"
            done
        )
        rm -rf "${DFILE}" "${WFILE}" "${MFILE}"
        logm "Replacing ${DB} daily backup ${DFILE} folder this last backup..."
        mv "${DFILENEW}" "${DFILE}"
        logm "Replacing ${DB} weekly backup ${WFILE} folder this last backup..."
        mv "${WFILENEW}" "${WFILE}"
        logm "Replacing ${DB} monthly backup ${MFILE} folder this last backup..."
        mv "${MFILENEW}" "${MFILE}"
    else
        logm "Replacing ${DB} daily backup ${DFILE} file this last backup..."
        ln -vf "${FILE}" "${DFILE}"
        logm "Replacing ${DB} weekly backup ${WFILE} file this last backup..."
        ln -vf "${FILE}" "${WFILE}"
        logm "Replacing ${DB} monthly backup ${MFILE} file this last backup..."
        ln -vf "${FILE}" "${MFILE}"
    fi
    # Update latest symlinks
    LATEST_LN_ARG=""
    if [ "${BACKUP_LATEST_TYPE}" = "symlink" ]; then
        LATEST_LN_ARG="-s"
    fi
    if [ "${BACKUP_LATEST_TYPE}" = "symlink" -o "${BACKUP_LATEST_TYPE}" = "hardlink"  ]; then
        logm "Point last ${DB} backup file to this last backup..."
        ln "${LATEST_LN_ARG}" -vf "${LAST_FILENAME}" "${BACKUP_DIR}/last/${DB}-latest${BACKUP_SUFFIX}"
        logm "Point latest ${DB} daily backup to this last backup..."
        ln "${LATEST_LN_ARG}" -vf "${DAILY_FILENAME}" "${BACKUP_DIR}/daily/${DB}-latest${BACKUP_SUFFIX}"
        logm "Point latest ${DB} weekly backup to this last backup..."
        ln "${LATEST_LN_ARG}" -vf "${WEEKLY_FILENAME}" "${BACKUP_DIR}/weekly/${DB}-latest${BACKUP_SUFFIX}"
        logm "Point latest ${DB} monthly backup to this last backup..."
        ln "${LATEST_LN_ARG}" -vf "${MONTHY_FILENAME}" "${BACKUP_DIR}/monthly/${DB}-latest${BACKUP_SUFFIX}"
    else # [ "${BACKUP_LATEST_TYPE}" = "none"  ]
        logm "Not updating ${DB} latest backup."
    fi
    #Clean old files
    logm "Cleaning older files for ${DB} database from ${POSTGRES_HOST}..."
    find "${BACKUP_DIR}/last" -maxdepth 1 -mmin "+${KEEP_MINS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
    find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime "+${KEEP_DAYS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
    find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime "+${KEEP_WEEKS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
    find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime "+${KEEP_MONTHS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
done

logm "SQL backup created successfully"

# Post-backup hook
if [ -d "${HOOKS_DIR}" ]; then
    run-parts -a "post-backup" --reverse --exit-on-error "${HOOKS_DIR}"
fi
