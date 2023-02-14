-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create function current_timezone()
    returns pg_catalog.pg_timezone_names
    stable
    parallel safe
    set pg_readme.include_this_routine_definition to true
    language sql
    return (
        select
            row(pg_timezone_names.*)::pg_catalog.pg_timezone_names
        from
            pg_catalog.pg_timezone_names
        where
            pg_timezone_names.name = current_setting('timezone')
    );

comment on function current_timezone() is
$md$Returns a `pg_timezone_names` record with the currently active timezone.
$md$;

--------------------------------------------------------------------------------------------------------------
