#!/bin/bash
set -e

if [ -v PASSWORD_FILE ]; then
    PASSWORD=$(< "$PASSWORD_FILE")
fi

: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}
: ${DB_NAME:=${POSTGRES_DB:='odoo'}}

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if ! grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then
        DB_ARGS+=("--${param}")
        DB_ARGS+=("${value}")
    fi;
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

wait-for-psql.py --db_host "$HOST" --db_port "$PORT" --db_user "$USER" --db_password "$PASSWORD" --timeout=30

DB_EXISTS=$(PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USER" -t -c "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null | tr -d ' ' || echo "0")
DB_INITIALIZED=$(PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_catalog.pg_tables WHERE tablename='ir_module_module'" 2>/dev/null || echo "0")
DB_INITIALIZED=$(echo "$DB_INITIALIZED" | tr -d ' ')

if [ "$DB_EXISTS" = "1" ] && [ "$DB_INITIALIZED" = "0" ]; then
    echo "Database $DB_NAME exists but is empty. Dropping and recreating..."
    PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USER" -c "DROP DATABASE IF EXISTS \"$DB_NAME\""
    DB_EXISTS="0"
fi

if [ "$DB_EXISTS" != "1" ]; then
    echo "Creating database $DB_NAME..."
    PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USER" -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$USER\""
    echo "Initializing Odoo database..."
    odoo -d "$DB_NAME" -i base --stop-after-init "${DB_ARGS[@]}"
    echo "Database initialized."
fi

exec odoo -d "$DB_NAME" "$@" "${DB_ARGS[@]}"
