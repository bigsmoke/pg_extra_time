-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Deal better with negative intervals.
create or replace function modulo(interval, interval)
    returns interval
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return (
        sign(extract(epoch from $1)) * (
            (to_timestamp(0) + greatest($1, -$1))
            - date_bin(greatest($2, -$2), to_timestamp(0) + greatest($1, -$1), to_timestamp(0))
        )
    );

-- Explain signedness behavior.
comment on function modulo(interval, interval) is
$md$As one would expect from a modulo operator, this function returns the remainder of the first given interval after dividing it into as many of the intervals given in the second argument as possible.

This function ignores the sign of the second argument.  The sign of the first
argument is preserved.  To take the absolute (intermediate) value of both
arguments, `greatest(interval, -interval)` is used.  According to some, this
[_might_](https://www.postgresql.org/message-id/flat/5ccd53c10910270727m5bf6d4adoa9424f49a397ca5e%40mail.gmail.com)
be a too simplistic approach, but the extension author (Rowan) is of the
opinion that that's okay in this context.
$md$;

--------------------------------------------------------------------------------------------------------------

-- Add tests for negative intervals.
create or replace procedure test__modulo__interval__interval()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert ('8 days 3 seconds'::interval % '2 days'::interval) = interval '3 seconds';
    assert ('9 days 3 seconds'::interval % '2 days'::interval) = interval '1 day 3 seconds';
    assert ('30 days'::interval % '10 days'::interval) = interval '0';
    assert ('-10 days'::interval % '1 day'::interval) = interval '0',
        format('%L ≠ %L', '-10 days'::interval % '1 day'::interval, '@ 00:00:00');
    assert ('-10 days -4 hours'::interval % '1 day'::interval) = interval '-4 hours',
        format('%L ≠ %L', '-10 days 4 hours'::interval % '1 day'::interval, '@ -4 hours');
    assert ('28 days'::interval % '-7 days'::interval) = interval '0 seconds';
    assert ('29 hours'::interval % '-7 hours'::interval) = interval '1 hour';
end;
$$;

--------------------------------------------------------------------------------------------------------------
