-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Routines should not be bound to the installation time `search_path`, because this extension is marked
-- as `relocatable`.

alter function pg_extra_time_readme()
    reset search_path;

alter function pg_extra_time_meta_pgxn()
    reset search_path;

alter procedure test__each_subperiod()
    reset search_path;

alter procedure test__make_tstzrange()
    reset search_path;

alter procedure test__make_tsrange()
    reset search_path;

--------------------------------------------------------------------------------------------------------------

-- Slightly reword comment.
comment on function modulo(tstzrange, interval) is
$markdown$As you would expect from a modulo operator, this function returns the remainder of the given datetime range after dividing it in as many of the given whole intervals as possible.
$markdown$;

--------------------------------------------------------------------------------------------------------------

create function modulo(interval, interval)
    returns interval
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return (
        (to_timestamp(0) + $1) - date_bin($2, to_timestamp(0) + $1, to_timestamp(0))
    );

comment on function modulo(interval, interval) is
$md$As one would expect from a modulo operator, this function returns the remainder of the first given interval after dividing it into as many of the intervals given in the second argument as possible.
$md$;

--------------------------------------------------------------------------------------------------------------

create operator % (
    leftarg = interval
    ,rightarg = interval
    ,function = modulo
    ,commutator = %
);

comment on operator % (interval, interval) is
$md$As one would expect from a modulo operator, this operator yields the remainder of the first given interval after dividing it into as many of the intervals given in the second argument as possible.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__modulo__interval__interval()
    set search_path from current
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert ('8 days 3 seconds'::interval % '2 days'::interval) = interval '3 seconds';
    assert ('9 days 3 seconds'::interval % '2 days'::interval) = interval '1 day 3 seconds';
    assert ('30 days'::interval % '10 days'::interval) = interval '0';
end;
$$;

--------------------------------------------------------------------------------------------------------------
