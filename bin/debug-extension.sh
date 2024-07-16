#!/usr/bin/env bash

SCRIPT_NAME=$(basename "$0")
SCRIPT_PATH=$(dirname "$0")

usage() {
    cat <<EOF
Usage:
    $SCRIPT_NAME <extension_sql_file> <extension_control_file>
    $SCRIPT_NAME --help         Show this help.
EOF
}

if [[ "$#" -ne 2 ]]; then
    usage >&2
    exit 2
fi

: "${PG_CONFIG:=pg_config}"
PG_BINDIR="$("$PG_CONFIG" --bindir)"
PSQL="$PG_BINDIR/psql"

EXTENSION_SQL_FILE="$1"
EXTENSION_CONTROL_FILE="$2"

psql_create_ext_opts=()

REQUIRED_EXTENSIONS=$(grep '^requires' "$EXTENSION_CONTROL_FILE" | sed -E "s/^.*'(.*)'$/\1/g" | sed -E 's/, / /g')
for required_extension in $REQUIRED_EXTENSIONS; do
    psql_create_ext_opts+=("-c")
    psql_create_ext_opts+=("CREATE EXTENSION IF NOT EXISTS $required_extension CASCADE;")
done

"$PSQL" \
    -c '\set ON_ERROR_STOP true' \
    -c '\set ECHO errors' \
    -c 'BEGIN TRANSACTION' \
    "${psql_create_ext_opts[@]}" \
    -f <( \
        cat "$EXTENSION_SQL_FILE" \
            | sed -e 's/^\\echo if_debug //' \
            | sed -e 's/^\\echo.*$//' \
            | sed -e 's/^.* -- if_not_debug$//' \
            | sed -e 's/^.*-- replacement_line_if_debug: \(.*\)$/\1/' \
            | sed -e 's/^select .*pg_extension_config_dump(.*);$//' \
            | sed -e '/^select .*pg_extension_config_dump($/{:a;N;/);/!ba; s/^.*$//}' \
            | sed -e '/^comment on extension/{:a;N;/\$md\$;/!ba; s/^.*$//}' \
    ) \
    -c 'ROLLBACK TRANSACTION' \
    postgres

# vim: set expandtab tabstop=4 shiftwidth=4:
