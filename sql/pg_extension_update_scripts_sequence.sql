\set ECHO none
\o /dev/null
\getenv extension_name EXTENSION_NAME
\getenv extension_oldest_version EXTENSION_OLDEST_VERSION
select
    not :{?extension_name} as extension_name_missing
    ,not :{?extension_oldest_version} as extension_oldest_version_missing
\gset
\if :extension_name_missing
    \warn 'Missing `EXTENSION_NAME` environment variable.'
    \quit
\endif
\if :extension_oldest_version_missing
    \warn 'Missing `EXTENSION_OLDEST_VERSION` environment variable.'
    \quit
\endif

\set SHOW_CONTEXT 'errors'
\set ON_ERROR_STOP

\o

with version_path as (
    select
        s.version
        ,s.ordinality
    from
        pg_extension_update_paths(:'extension_name') as p
    cross join lateral
        string_to_table(p.path, '--') with ordinality as s(version, ordinality)
    where
        p.source = :'extension_oldest_version'
        and p.target = (select default_version from pg_available_extensions where name = :'extension_name')
)
,update_script_path as (
    select
        concat('sql/', :'extension_name', '--', v1.version, '--', v2.version, '.sql') as filename
        ,v1.ordinality  -- Doesn't matter if we pick `v1.version` or `v2.version`.
    from
        version_path as v1
    inner join
        version_path as v2
        on v2.ordinality = v1.ordinality + 1
)
select
    string_agg(p.filename, ' ' order by p.ordinality) as file_paths
from
    update_script_path as p
\gset

\echo :file_paths
