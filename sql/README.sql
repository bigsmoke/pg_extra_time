\pset tuples_only
\pset format unaligned

begin;

create extension pg_extra_time;

select pg_extra_time_readme();

rollback;
