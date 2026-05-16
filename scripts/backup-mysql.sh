#!/bin/bash
# shellcheck shell=bash
set -euo pipefail

# --- Configuration ---
NAMESPACE="skillpulse-dev"
MYSQL_POD="mysql-0"
MYSQL_USER="skillpulse"
MYSQL_PASSWORD="skillpulse123"
S3_BUCKET="skillpulse-mysql-backups"
REGION="ap-south-1"

# --- Derived paths ---
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DATE=$(date +%Y-%m-%d)
DUMP_FILE="/tmp/skillpulse-backup-${TIMESTAMP}.sql"
DUMP_GZ="${DUMP_FILE}.gz"

log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S)] $*"
}

# Clean up local files on any exit (no-op if already removed)
trap 'rm -f "${DUMP_FILE}" "${DUMP_GZ}"' EXIT

# --- Step 1: Dump all databases from MySQL pod ---
log "Starting backup from pod ${MYSQL_POD} in namespace ${NAMESPACE}..."
kubectl exec -n "${NAMESPACE}" "${MYSQL_POD}" -- \
    mysqldump -u "${MYSQL_USER}" "--password=${MYSQL_PASSWORD}" --all-databases \
    > "${DUMP_FILE}"
log "Dump saved: ${DUMP_FILE} ($(du -sh "${DUMP_FILE}" | cut -f1))"

# --- Step 2: Compress ---
log "Compressing dump..."
gzip "${DUMP_FILE}"
log "Compressed: ${DUMP_GZ} ($(du -sh "${DUMP_GZ}" | cut -f1))"

# --- Step 3: Upload to S3 ---
S3_KEY="${DATE}/backup-${TIMESTAMP}.sql.gz"
S3_PATH="s3://${S3_BUCKET}/${S3_KEY}"
log "Uploading to ${S3_PATH}..."
aws s3 cp "${DUMP_GZ}" "${S3_PATH}" --region "${REGION}"
log "Upload complete: ${S3_PATH}"

# --- Step 4: Delete local dump ---
rm -f "${DUMP_GZ}"
log "Local dump deleted"

# --- Step 5: Retention — delete S3 backups older than 30 days ---
purge_old_backups() {
    log "Checking for S3 backups older than 30 days..."
    local cutoff_epoch
    cutoff_epoch=$(date -d "30 days ago" +%s)

    local objects
    objects=$(aws s3api list-objects-v2 \
        --bucket "${S3_BUCKET}" \
        --region "${REGION}" \
        --output text \
        --query 'Contents[].[Key, LastModified]' 2>/dev/null) || true

    if [ -z "${objects}" ]; then
        log "No objects found in bucket, skipping retention."
        return 0
    fi

    local deleted=0
    while IFS=$'\t' read -r key last_modified; do
        [ -z "${key}" ] && continue
        local obj_epoch
        obj_epoch=$(date -d "${last_modified}" +%s 2>/dev/null) || continue
        if [ "${obj_epoch}" -lt "${cutoff_epoch}" ]; then
            log "Deleting expired backup: ${key}"
            aws s3 rm "s3://${S3_BUCKET}/${key}" --region "${REGION}"
            deleted=$(( deleted + 1 ))
        fi
    done <<< "${objects}"

    log "Retention complete: ${deleted} backup(s) deleted"
}

purge_old_backups

log "Backup finished successfully: ${S3_PATH}"
