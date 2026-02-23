#!/bin/bash
set -euo pipefail

DB_NAME="$1"
PRIMARY_HOST="$2"
INSTANCE_OWNER="${3:-db2inst1}"

PIPE="/database/config/db2inst1/restore.pipe"

# Helper function to execute DB2 commands as instance owner
run_db2_cmd() {
    local cmd="$1"
    echo "[EXEC] $cmd"
    su - "$INSTANCE_OWNER" -c "source ~/.bashrc >/dev/null 2>&1; $cmd"
}

cleanup() {
    rm -f "$PIPE"
}
trap cleanup EXIT

echo "[STANDBY] Creating restore pipe..."
mkfifo "$PIPE"
chown "$INSTANCE_OWNER" "$PIPE"

echo "[STANDBY] READY"  # Signal to coordinator that pipe exists

echo "[STANDBY] Starting restore (blocking on pipe)..."
run_db2_cmd "db2 restore database $DB_NAME from $PIPE" &
RESTORE_PID=$!

# Read from stdin (fed by coordinator) and write to pipe
cat > "$PIPE"

wait "$RESTORE_PID"
echo "[STANDBY] Restore completed"