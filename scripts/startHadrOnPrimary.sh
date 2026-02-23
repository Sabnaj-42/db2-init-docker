#!/bin/bash

set -euo pipefail

DB_NAME="$1"
NAMESPACE="$2"
INSTANCE_OWNER="${3:-db2inst1}"


# Helper function
run_db2_cmd() {
    su - "$INSTANCE_OWNER" -c "source ~/.bashrc >/dev/null 2>&1; $1"
}
# Terminate DB2 connections
run_db2_cmd "db2 terminate"

# Activate primary database
run_db2_cmd "db2 activate db $DB_NAME"


# Start HADR on primary
run_db2_cmd "db2 START HADR ON DB $DB_NAME AS PRIMARY"

echo "[PRIMARY] Primary HADR started"