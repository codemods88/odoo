#!/bin/bash
set -e

if [ -v PASSWORD_FILE ]; then
    PASSWORD=$(< "$PASSWORD_FILE")
fi

: ${PGHOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PGPORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${PGUSER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PGPASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}
: ${DB_NAME:=${POSTGRES_DB:='odoo'}}

echo "Connecting to PostgreSQL: host=$PGHOST port=$PGPORT user=$PGUSER db=$DB_NAME"

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if ! grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then
        DB_ARGS+=("--${param}")
        DB_ARGS+=("${value}")
    fi;
}
check_config "db_host" "$PGHOST"
check_config "db_port" "$PGPORT"
check_config "db_user" "$PGUSER"
check_config "db_password" "$PGPASSWORD"

wait-for-psql.py --db_host "$PGHOST" --db_port "$PGPORT" --db_user "$PGUSER" --db_password "$PGPASSWORD" --timeout=30

DB_EXISTS=$(PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -t -c "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null | tr -d ' ')
echo "Database check: exists=$DB_EXISTS"

if [ "$DB_EXISTS" = "1" ]; then
    DB_INITIALIZED=$(PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_catalog.pg_tables WHERE tablename='ir_module_module'" 2>/dev/null || echo "0")
    DB_INITIALIZED=$(echo "$DB_INITIALIZED" | tr -d ' ')
    echo "Database init check: initialized=$DB_INITIALIZED"
    
    if [ "$DB_INITIALIZED" = "0" ]; then
        echo "Database $DB_NAME exists but is empty. Dropping and recreating..."
        PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "DROP DATABASE IF EXISTS \"$DB_NAME\""
        DB_EXISTS="0"
    fi
fi

if [ "$DB_EXISTS" != "1" ]; then
    echo "Creating database $DB_NAME..."
    PGPASSWORD="$PGPASSWORD" psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$PGUSER\""
    echo "Initializing Odoo database..."
    odoo -d "$DB_NAME" -i base --stop-after-init "${DB_ARGS[@]}"
    echo "Database initialized."
fi

echo "Starting Odoo..."
exec odoo -d "$DB_NAME" "$@" "${DB_ARGS[@]}"
