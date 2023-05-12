-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on extension pg_extra_time is
$markdown$
# `pg_extra_time` PostgreSQL extension

The `pg_extra_time` PostgreSQL extension contains some date time functions and operators that, according to the extension author, ought to be part of the PostgreSQL standard distribution.

<?pg-readme-reference?>

## Extension origins

`pg_extra_time` was developed to simplify quite a bit of code in the PostgreSQL
backend of the [FlashMQ MQTT hosting platform](https://www.flashmq.com/),
especially for financial calculations regarding subscription durations, etc..
Datetime calculations are notoriously easy to get wrong, and therefore better
to isolate and test well rather than mix into the business logic on an ad hoc
basis.

## Extension author(s)

* Rowan Rodrik van der Molen—the original (and so far only) author of
  `pg_extra_time`—identifies more as a [restorative farmer, permaculture writer
  and reanimist](https://sapienshabitat.com) than as a techologist.
  Nevertheless, computer technology has remained stubbornly intertwined with his
  life, the trauma of which he tries to process by writing the book on [_Why
  Programming Still Sucks_](https://www.whyprogrammingstillsucks.com/)
  ([@ysosuckysoft](https://twitter.com/ysosuckysoft)).  As of 2023, he is
  applying his painfully earned IT wisdom to a robust [MQTT SaaS
  service](https://www.flashmq.com/), and he does so alternatingly:

    - from within a permaculture project in central Portugal;
    - and his beautiful [holiday home for rent in the forests of
      Drenthe](https://www.schuilplaats-norg.nl/), where from his work place
      he looks out over his lush ecological garden and a private heather field.

  His day to day [musings on technology](https://blog.bigsmoke.us/) he usually
  slaps onto his blog.

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------

create function pg_extra_time_readme()
    returns text
    volatile
    set search_path from current
    set pg_readme.include_view_definitions to 'true'
    set pg_readme.include_routine_definitions_like to '{test__%}'
    set pg_readme.readme_url to 'https://github.com/bigsmoke/pg_extra_time/blob/master/README.md'
    language plpgsql
    as $plpgsql$
declare
    _readme text;
begin
    create extension if not exists pg_readme with cascade;

    _readme := pg_extension_readme('pg_extra_time'::name);

    raise transaction_rollback;  -- to `DROP EXTENSION` if we happened to `CREATE EXTENSION` for just this.
exception
    when transaction_rollback then
        return _readme;
end;
$plpgsql$;

comment on function pg_extra_time_readme() is
$markdown$Fire up the `pg_readme` extension to generate a thorough README for this extension, based on the `pg_catalog` and the `COMMENT` objects found therein.
$markdown$;

--------------------------------------------------------------------------------------------------------------

create function pg_extra_time_meta_pgxn()
    returns jsonb
    stable
    set search_path from current
    language sql
    return jsonb_build_object(
        'name'
        ,'pg_extra_time'
        ,'abstract'
        ,'Some date-time functions and operators that, according to the extension author, ought to be part of'
            ' the PostgreSQL standard distribution.'
        ,'description'
        ,'The pg_extra_time PostgreSQL extension contains some date time functions and operators that,'
            ' in the opinion of the extension author, ought to be part of the PostgreSQL standard'
            ' distribution.'
        ,'version'
        ,(
            select
                pg_extension.extversion
            from
                pg_catalog.pg_extension
            where
                pg_extension.extname = 'pg_extra_time'
        )
        ,'maintainer'
        ,array[
            'Rowan Rodrik van der Molen <rowan@bigsmoke.us>'
        ]
        ,'license'
        ,'postgresql'
        ,'prereqs'
        ,'{
            "test": {
                "requires": {
                    "pgtap": 0
                }
            },
            "develop": {
                "recommends": {
                    "pg_readme": 0
                }
            }
        }'::jsonb
        ,'provides'
        ,('{
            "pg_extra_time": {
                "file": "pg_extra_time--0.7.1.sql",
                "version": "' || (
                    select
                        pg_extension.extversion
                    from
                        pg_catalog.pg_extension
                    where
                        pg_extension.extname = 'pg_extra_time'
                ) || '",
                "docfile": "README.md"
            }
        }')::jsonb
        ,'resources'
        ,'{
            "homepage": "https://blog.bigsmoke.us/tag/pg_extra_time",
            "bugtracker": {
                "web": "https://github.com/bigsmoke/pg_extra_time/issues"
            },
            "repository": {
                "url": "https://github.com/bigsmoke/pg_extra_time.git",
                "web": "https://github.com/bigsmoke/pg_extra_time",
                "type": "git"
            }
        }'::jsonb
        ,'meta-spec'
        ,'{
            "version": "1.0.0",
            "url": "https://pgxn.org/spec/"
        }'::jsonb
        ,'generated_by'
        ,'`select pg_extra_time_meta_pgxn()`'
        ,'tags'
        ,array[
            'plpgsql',
            'function',
            'functions',
            'date',
            'datetime',
            'interval',
            'time'
        ]
    );

comment on function pg_extra_time_meta_pgxn() is
$markdown$Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

`pg_extra_time` can indeed be found on PGXN: https://pgxn.org/dist/pg_readme/
$markdown$;

--------------------------------------------------------------------------------------------------------------

create function extract_interval(
        tstzrange
        ,interval[]
    )
    returns interval
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    return (
        -- The `RECURSIVE` keyword always comes at the start, not in the specific CTE that _is_ recursive.
        with recursive requested_subintervals as (
            select
                subintervals.subinterval
                ,subintervals.granularity_level
            from
                unnest($2) with ordinality as subintervals(subinterval, granularity_level)
        )
        -- This is the actual recursive CTE.
        ,subinterval_steps as (
            select
                max(ticks.tick) as cutoff
                ,max((ticks.tick_no - 1) * this_subinterval.subinterval) as subtotal
                ,min(this_subinterval.granularity_level) as granularity_level  -- min() = max()
            from
                requested_subintervals as this_subinterval
            cross join lateral
                generate_series(lower($1), upper($1), this_subinterval.subinterval)
                with ordinality as ticks(tick, tick_no)
            where
                this_subinterval.granularity_level = 1
            union all
            select
                max_tick.tick as cutoff
                ,previous_step.subtotal
                    + (max_tick.tick_no - 1) * this_subinterval.subinterval as subtotal
                ,this_subinterval.granularity_level as granularity_level
            from
                subinterval_steps as previous_step
            inner join
                requested_subintervals as this_subinterval
                on this_subinterval.granularity_level = previous_step.granularity_level + 1
            cross join lateral (
                select
                    max(ticks.tick) as tick
                    ,max(ticks.tick_no) as tick_no
                from
                    generate_series(
                        previous_step.cutoff, upper($1), this_subinterval.subinterval
                    ) with ordinality as ticks(tick, tick_no)
            ) as max_tick
        )
        select
            max(subtotal)
        from
            subinterval_steps
    );

comment on function extract_interval(tstzrange, interval[]) is
$markdown$Extract all the rounded intervals given in the second argument from the datetime range in the first argument.

The function starts with as many of the biggest units given as fit in the datetime range, then tries the next-biggest unit with the remainder, etc.

See the `test__extract_interval()` procedure for examples.
$markdown$;

--------------------------------------------------------------------------------------------------------------

create function extract_interval(tstzrange)
    returns interval
    returns null on null input
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    language sql
    return extract_interval(
        $1,
        array[
            -- interval '1 millennium',
            -- interval '1 century',
            -- interval '1 decade',
            interval '1 year',
            interval '1 month',
            --interval '1 week',  -- Weeks are never part of the output
            interval '1 day',
            interval '1 hour',
            interval '1 minute',
            interval '1 second',
            interval '1 millisecond',
            interval '1 microsecond'
        ]
    );

comment on function extract_interval(tstzrange) is
$markdown$Extract an interval from a datetime range, starting with the largest interval unit possible, and down to the microsecond.
$markdown$;

--------------------------------------------------------------------------------------------------------------

create cast (tstzrange as interval)
    with function extract_interval(tstzrange)
    as assignment;

comment on cast (tstzrange as interval) is
$markdown$Cast a datetime range to the intervals that fit in that range, starting with the largest interval unit possible, and down to the microsecond.$markdown$;

--------------------------------------------------------------------------------------------------------------

create procedure test__extract_interval()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert extract_interval(
            tstzrange('2022-07-22', '2022-09-23'),
            array[interval '1 month', interval '1 hour']
        ) = interval '2 month 24 hour';

    assert tstzrange('2022-07-20', '2022-09-28')::interval = interval '2 month 1 week 1 day';
    -- `WEEK` is support as input, but is always outputted as `7 DAYS`
    assert interval '2 month 1 week 1 day' = interval '2 month 8 day';  -- See?

    assert tstzrange('1001-07-20', '2002-07-20')::interval = interval '1 millennium 1 year';

    assert extract_interval(
            tstzrange('1001-07-20', '2242-07-20')
        ) = interval '1 millennium 2 century 4 decade 1 year';

    assert interval '1 millennium 2 century 4 decade 1 year' = interval '1241 year';

    -- Summer time started on March 27 in 2022
    assert extract_interval(
            tstzrange('2022-03-01', '2022-05-8'),
            array[interval '1 month', interval '1 day', interval '1 hour']
        ) = interval '2 month 1 week';
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function extract_days(tstzrange)
    returns integer
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    return (date_trunc('day', upper($1))::date - date_trunc('day', lower($1))::date)
            + upper_inc($1)::int - (lower_inc($1) = false)::int;

comment on function extract_days(tstzrange) is
$markdown$Extract the number of whole days from a given `tstzrange` value.
$markdown$;

--------------------------------------------------------------------------------------------------------------

create cast (tstzrange as integer)
    with function extract_days(tstzrange)
    as assignment;

comment on cast (tstzrange as integer) is
$markdown$Extract the number of whole days from a given `tstzrange` value.
$markdown$;

--------------------------------------------------------------------------------------------------------------

create procedure test__extract_days_from_tstzrange()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert extract_days('[2021-12-01,2022-01-01)'::tstzrange) = 31;
    assert extract_days('[2021-12-01,2022-01-01]'::tstzrange) = 32;
    assert extract_days('(2021-12-01,2022-01-01)'::tstzrange) = 30;
    assert extract_days('(2021-12-01,2021-12-02)'::tstzrange) = 0;
    assert extract_days('[2021-12-01,2021-12-02)'::tstzrange) = 1;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function extract_days(interval)
    returns integer
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return floor(extract(epoch from $1) / 86400);

comment on function extract_days(interval) is
$markdown$Extract the number of whole days (rounded down) from a given `interval` value.$markdown$;

--------------------------------------------------------------------------------------------------------------

create cast (interval as integer)
    with function extract_days(interval)
    as assignment;

comment on cast (interval as integer) is
$markdown$Extract the number of whole days (rounded down) from a given `interval` value.$markdown$;

--------------------------------------------------------------------------------------------------------------

create procedure test__extract_days_from_interval()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert extract_days(interval '1 month') = 30;
    assert extract_days(interval '1 week') = 7;
    assert extract_days(interval '3 month 1 week 2 days') = 99;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function modulo(tstzrange, interval)
    returns interval
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    as $$
select
    upper($1) - max(i)
from
    generate_series(lower($1), upper($1), $2) as i
;
$$;

comment on function modulo(tstzrange, interval) is
$markdown$As you would expect from a modulo operator, this function returns the remainder of the given datetime range after dividing it in as many of the given whole intervals as possible.
$markdown$;

--------------------------------------------------------------------------------------------------------------

create operator % (
    leftarg = tstzrange
    ,rightarg = interval
    ,function = modulo
    ,commutator = %
);

comment on operator % (tstzrange, interval) is
$markdown$As you would expect from a modulo operator, this function returns the remainder of the given datetime range after dividing it in as many of the given whole intervals as possible.
$markdown$;

--------------------------------------------------------------------------------------------------------------

create procedure test__modulo__tsttzrange__interval()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert (tstzrange(make_date(2022,7,1), make_date(2022,8,2)) % interval '1 month') = interval '1 day';
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function date_part_parts(text, text, timestamptz)
    returns int
    returns null on null input
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    language sql
    return date_part($2, date_trunc($1, $3) + format('1 %s', $1)::interval - date_trunc($1, $3));

comment on function date_part_parts(text, text, timestamptz) is
$md$Extract the number of date parts that exist in the other given date part for the given date.

Use this function:

* if you want to know the number of days in the month for the month that the given date falls in;
* if you want to know the number of days in the year for the year that the given date falls in;
* if you need to be reminded that really _every_ year has 12 months;
* etc.

Of course, this function is mostly useful to avoid conditional nightmares in other date-time-related calculations.

The names of the date parts follow those of the standard PostgreSQL [`date_part()`](https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-EXTRACT) and [`date_trunc()`](https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-TRUNC) functions.

See the `test__date_part_parts()` routine for examples.
$md$;

create procedure test__date_part_parts()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert date_part_parts('year', 'days', make_date(2022,8,23)) = 365;
    assert date_part_parts('year', 'days', make_date(2024,8,23)) = 366;
    assert date_part_parts('month', 'days', make_date(2024,2,12)) = 29;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function each_subperiod(
        dividend$ tstzrange
        ,divisor$ interval
        ,round_remainder$ int default 0
    )
    returns table (
        quotient tstzrange
    )
    immutable
    leakproof
    parallel safe
    language sql
begin atomic
    with recursive division(quotient) as (
        select  tstzrange(
                    lower(dividend$)
                    ,case
                        when sign(round_remainder$) = 1
                        then lower(dividend$) + divisor$
                        else least(upper(dividend$),  lower(dividend$) + divisor$)
                    end
                )
        where   sign(round_remainder$) > -1
                or (lower(dividend$) + divisor$) <= upper(dividend$)
        union all
        select  tstzrange(
                    upper(previous.quotient)
                    ,case
                        when sign(round_remainder$) = 1
                        then upper(previous.quotient) + divisor$
                        else least(upper(dividend$),  upper(previous.quotient) + divisor$)
                    end
                )
        from    division as previous
        where   case
                    when sign(round_remainder$) = -1
                    then (upper(previous.quotient) + divisor$) <= upper(dividend$)
                    else upper(previous.quotient) < upper(dividend$)
                end
    )
    select  quotient
    from    division
    ;
end;

comment on function each_subperiod(tstzrange, interval, int) is
$md$Divide the given `dividend$` into `divisor$`-sized chunks.

The remainder is rounded:

- up, to a complete `divisor$`, if `round_remainder$ >= 1`;
- down, discarding the remainder, if `round_remainder$ <= 1`; or
- not at all and kept as the remainder, if `round_remainder = 0`.

See the [`test__each_subperiod`](#routine-test__each_subperiod) routine for
examples.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__each_subperiod()
    set search_path from current
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
begin
    assert (
            select
                array_agg(quotient)
            from
                each_subperiod('[2023-01-01,2023-04-01)'::tstzrange, '1 month'::interval, 0)
        ) = '{
            "[2023-01-01, 2023-02-01)",
            "[2023-02-01, 2023-03-01)",
            "[2023-03-01, 2023-04-01)"
        }'::tstzrange[];

    assert (
            select
                array_agg(quotient)
            from
                each_subperiod('[2023-01-01,2023-04-02)'::tstzrange, '1 month'::interval, 0)
        ) = '{
            "[2023-01-01, 2023-02-01)",
            "[2023-02-01, 2023-03-01)",
            "[2023-03-01, 2023-04-01)",
            "[2023-04-01, 2023-04-02)"
        }'::tstzrange[];

    assert (
            select
                array_agg(quotient)
            from
                each_subperiod('[2023-01-01,2023-04-02)'::tstzrange, '1 month'::interval, 1)
        ) = '{
            "[2023-01-01, 2023-02-01)",
            "[2023-02-01, 2023-03-01)",
            "[2023-03-01, 2023-04-01)",
            "[2023-04-01, 2023-05-01)"
        }'::tstzrange[];

    assert (
            select
                array_agg(quotient)
            from
                each_subperiod('[2023-01-01,2023-01-02)'::tstzrange, '1 month'::interval, 1)
        ) = '{"[2023-01-01, 2023-02-01)"}'::tstzrange[];

    assert (
            select
                array_agg(quotient)
            from
                each_subperiod('[2023-01-01,2023-04-02)'::tstzrange, '1 month'::interval, -1)
        ) = '{
            "[2023-01-01, 2023-02-01)",
            "[2023-02-01, 2023-03-01)",
            "[2023-03-01, 2023-04-01)"
        }'::tstzrange[];

    assert (
            select
                count(*)
            from
                each_subperiod('[2023-01-01,2023-01-31)'::tstzrange, '1 month'::interval, -1)
        ) = 0;
end;
$$;

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
