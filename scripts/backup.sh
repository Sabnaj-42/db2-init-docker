#!/bin/bash

set -euo pipefail

DB_NAME="$1"
STANDBY_POD="$2"
NAMESPACE="$3"
INSTANCE_OWNER="${4:-db2inst1}"

PIPE="/database/config/db2inst1/restore.pipe"

# Helper function
run_db2_cmd() {
    su - "$INSTANCE_OWNER" -c "source ~/.bashrc >/dev/null 2>&1; $1"
}

echo "[PRIMARY] Waiting for standby FIFO..."

until kubectl exec "$STANDBY_POD" -n "$NAMESPACE" -- test -p "$PIPE"; do
    sleep 2
done

echo "[PRIMARY] FIFO detected, starting backup stream"

# Stream backup to standby
su - "$INSTANCE_OWNER" -c "db2 backup database $DB_NAME to STDOUT" | \
kubectl exec -i "$STANDBY_POD" -n "$NAMESPACE" -- \
    su - "$INSTANCE_OWNER" -c "cat > $PIPE"

echo "[PRIMARY] Backup streaming finished"

# Terminate DB2 connections
run_db2_cmd "db2 terminate"

# Activate primary database
run_db2_cmd "db2 activate db $DB_NAME"

# Wait for standby to be ready for HADR
echo "[PRIMARY] Waiting for standby to be ready for HADR..."
until kubectl exec "$STANDBY_POD" -n "$NAMESPACE" -- test -f /tmp/standby_ready.flag; do
    sleep 2
done
echo "[PRIMARY] Standby is ready, starting HADR on primary"

# Start HADR on primary
run_db2_cmd "db2 START HADR ON DB $DB_NAME AS PRIMARY"

echo "[PRIMARY] Primary HADR started"