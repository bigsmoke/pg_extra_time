\pset tuples_only
\pset format unaligned

begin;

create extension pg_extra_time
    with cascade;

select jsonb_pretty(pg_extra_time_meta_pgxn());

rollback;
