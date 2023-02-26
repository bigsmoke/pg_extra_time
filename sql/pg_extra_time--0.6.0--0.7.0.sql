-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create function make_tstzrange(timestamptz, interval, text default '[)')
    returns tstzrange
    returns null on null input
    immutable
    leakproof
    parallel safe
    language sql
    return case
        when $2 < interval '0'
        then tstzrange($1 + $2, $1, $3)
        else tstzrange($1, $1 + $2, $3)
    end;

comment on function make_tstzrange(timestamptz, interval, text) is
$md$Build a `tstzrange` from a given timestamp from or until the given interval.

This function will do the right thing when confronted with negative intervals.

The function name is chosen for consistency with (some of) PostgreSQL built-in
date/time functions.  I would have preferred to call it plainly `tstzrange()`,
but that would require users of this extensions to have to become explicit when
calling the existing `tsrange(text)` constructor while relying on an explicit
cast of `unknown` to `text`.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__make_tstzrange()
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
begin
    assert make_tstzrange('2023-02-21 01:02'::timestamptz, '1 day'::interval) = tstzrange(
        '2023-02-21 01:02'::timestamptz
        ,'2023-02-22 01:02'::timestamptz
    );
    assert make_tstzrange('2023-02-21 01:02'::timestamptz, '-1 month'::interval) = tstzrange(
        '2023-01-21 01:02'::timestamptz
        ,'2023-02-21 01:02'::timestamptz
    );
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function make_tsrange(timestamp, interval, text default '[)')
    returns tsrange
    returns null on null input
    immutable
    leakproof
    parallel safe
    language sql
    return case
        when $2 < interval '0'
        then tsrange($1 + $2, $1, $3)
        else tsrange($1, $1 + $2, $3)
    end;

comment on function make_tsrange(timestamp, interval, text) is
$md$Build a `tsrange` from a given timestamp from or until the given interval.

This function will do the right thing when confronted with negative intervals.

The function name is chosen for consistency with (some of) PostgreSQL built-in
date/time functions.  I would have preferred to call it plainly `tsrange()`,
but that would require users of this extensions to have to become explicit when
calling the existing `tsrange(text)` constructor while relying on an explicit
cast of `unknown` to `text`.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__make_tsrange()
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
begin
    assert make_tsrange('2023-02-21 01:02'::timestamp, '1 day'::interval) = tsrange(
        '2023-02-21 01:02'::timestamp
        ,'2023-02-22 01:02'::timestamp
    );
    assert make_tsrange('2023-02-21 01:02'::timestamp, '-1 month'::interval) = tsrange(
        '2023-01-21 01:02'::timestamp
        ,'2023-02-21 01:02'::timestamp
    );
end;
$$;

--------------------------------------------------------------------------------------------------------------
