#!/bin/bash

set -euo pipefail

DB_NAME="${1}"
REMOTE_HOST="${2}"
INSTANCE_OWNER="${3:-db2inst1}"
BACKUP_PATH="${4:-/shared/db2backup}"
PORT_NUMBER="${5}"

if [[ -z "$DB_NAME" || -z "$REMOTE_HOST" ]]; then
    echo "ERROR: Missing parameters. Usage: $0 <db_name> <remote_host> [instance_owner] [backup_path]"
    exit 1
fi

LOCAL_HOST=$(hostname -f)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up HADR for DB: $DB_NAME"
echo "Local host: $LOCAL_HOST"
echo "Remote host: $REMOTE_HOST"

run_db2_cmd() {
    local cmd="$1"
    echo "[EXEC] $cmd"
    su - "$INSTANCE_OWNER" -c "source ~/.bashrc 2>/dev/null; $cmd"
}

echo "Configuring HADR parameters..."
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING LOGARCHMETH1 \"DISK:${BACKUP_PATH}\""
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING LOGINDEXBUILD ON"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING INDEXREC RESTART"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_HOST $LOCAL_HOST"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_SVC $PORT_NUMBER"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_HOST $REMOTE_HOST"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_SVC $PORT_NUMBER"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_INST db2inst1"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_SYNCMODE NEARSYNC"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_TIMEOUT 120"

echo "Restarting database to apply changes..."
run_db2_cmd "db2 deactivate db $DB_NAME" || true

echo "[SUCCESS] HADR configuration completed for $DB_NAME"