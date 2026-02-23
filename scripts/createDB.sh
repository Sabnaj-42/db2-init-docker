#!/bin/bash
set -euo pipefail

DB_NAME="${1}"
INSTANCE_OWNER="${2:-db2inst1}"

run_db2_cmd() {
    local cmd="$1"
    echo "[EXEC] $cmd"
    su - "$INSTANCE_OWNER" -c "source ~/.bashrc 2>/dev/null; $cmd"
}

# Check if database already exists
echo "Checking if database $DB_NAME exists..."
if run_db2_cmd "db2 list db directory" | grep -q "Database name.*=.*${DB_NAME}"; then
    echo "[SKIP] Database $DB_NAME already exists, skipping creation"
    exit 0
fi

echo "Creating database $DB_NAME..."
run_db2_cmd "db2 create database $DB_NAME"
echo "[SUCCESS] Database $DB_NAME created successfully"