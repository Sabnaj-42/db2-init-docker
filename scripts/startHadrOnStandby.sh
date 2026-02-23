#!/bin/bash
set -euo pipefail

DB_NAME="$1"
PRIMARY_HOST="$2"
INSTANCE_OWNER="${3:-db2inst1}"
PORT_NUMBER="$4"

# Helper function to execute DB2 commands as instance owner
run_db2_cmd() {
    local cmd="$1"
    echo "[EXEC] $cmd"
    su - "$INSTANCE_OWNER" -c "source ~/.bashrc >/dev/null 2>&1; $cmd"
}


# ================================
# Configure HADR on Standby
# ================================



run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING LOGINDEXBUILD ON"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING INDEXREC RESTART"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_HOST $(hostname -f)"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_LOCAL_SVC $PORT_NUMBER"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_HOST $PRIMARY_HOST"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_SVC $PORT_NUMBER"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REMOTE_INST $INSTANCE_OWNER"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_SYNCMODE NEARSYNC"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_REPLAY_DELAY 0"
run_db2_cmd "db2 UPDATE DB CFG FOR $DB_NAME USING HADR_TIMEOUT 120"


# ================================
# CRITICAL: Enable Read on Standby (MUST be before START HADR)
# ================================
echo "[CONFIG] Enabling Read on Standby..."
run_db2_cmd "db2set DB2_HADR_ROS=ON"
run_db2_cmd "db2set DB2_STANDBY_ISO=UR"

# Verify settings were applied
run_db2_cmd "db2set -all | grep -E 'HADR_ROS|STANDBY_ISO'"

# ================================
# Start HADR (Variables must be set before this)
# ================================
run_db2_cmd "db2 START HADR ON DATABASE $DB_NAME AS STANDBY"

# Verify HADR status
run_db2_cmd "db2pd -db $DB_NAME -hadr"

echo "[STANDBY] Standby ready"