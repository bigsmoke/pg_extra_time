-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on extension pg_extra_time is
$markdown$
# `pg_extra_time` PostgreSQL extension

The `pg_extra_time` PostgreSQL extension contains some date time functions and operators that, according to the extension author, ought to be part of the PostgreSQL standard distribution.

## From `tstzrange` and `interval` to days (not seconds)

`pg_extra_time` has functions to get the number of days (with or without
fractions) contained in a `tstzrange` or `interval`.  Each of these functions is
also paired to a cast to convert to either:

  - a `float` representing the number of days including the remainder, or
  - an `integer` representing the number of whole days, rounded down.


| Cast                 | Function                                                  | Example                                                     |
| -------------------- | --------------------------------------------------------- | ----------------------------------------------------------- |
| `tstzrange::float`   | [`days(tstzrange)`](#function-days-tstzrange)             | `'[2024-06-06,2024-06-08 06:00)'::tstzrange::float = 3.25`  |
| `tstzrange::integer` | [`whole_days(tstzrange)`](#function-whole_days-tstzrange) | `'[2024-06-06,2024-06-08 18:00)'::tstzrange::int = 3`       |
| `interval::float`    | [`days(interval)`](#function-days-interval)               | `'10 days 12 hours'::interval::float = 10.5`                |
| `interval::integer`  | [`whole_days(interval)`](#function-whole_days-interval)   | `'10 days 20 hours 20 minutes'::interval::int = 10`         |

### Why cast to days and not seconds?

PostgreSQL (as of version 16) doesn't come with built-in casts of date-timey
types to `float`s and/or `integer`s.  So the extension author had to make a
choice what unit to cast _to_.  The reasoning to cast to days rather than
seconds goes as follows.

Let's start with a counter-argument: PostgreSQL, as most things with a Unixy
origin, counts dates as the number of seconds elapsed since the Unix epox.

Nevertheless, whereas Postgres doesn't come with an opinion on what timestampy
things should be converted into, MSSQL does offer a `CAST(DATETIME AS FLOAT)`.
An MSSQL `DATETIME` is not quite the same as a Postgres `tstzrange` or
`interval`, but hey, at least it provides us with _a_ reference opinion.  In
older versions of MSSQL, it was also possible to directly `CAST(DATETIME AS
INTEGER)`, rounding down to the number of whole days elapsed since the
[`mssql_epoch()`](#function-mssql_epoch).

Indeed, in MSSQL, these casts return the number of days elapsed since the SQL
Server epoch.  That could be another argument in favor of seconds, since in
Postgres, Unix timestamps are (as always in \*nix contexts) counted in seconds
elapsed since the Unix epoch.

Apart from the inspiration from MSSQL, there's the thing that it is already very
trivial to extract the number of seconds from a `timestamp` (`with time zone`)
or from an `interval` in Postgres, using [`extract(epoch from
…)`](https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-EXTRACT),
and the extension author preferred to make it easy to do something that was not
_already_ easy.

## Installing & using this extension

When using this extension, _please_ feel free to not actually use it as an
extension and instead just copy-paste the precise function(s) and/or cast(s)
that you need.  To make copy-pasting bits and pieces easier, the extension
author has tried his best not to succumb to the DRY disease and thus not reuse
functions in other function, only to safe a few characters and introduce extra
indirection (and sloth, because Postgres, as of version 16, supports inlining
of SQL functions, but only one level deep).  And DRY to safe on bugs?  Come on
now, there's a test procedure for each function.

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
$md$Fire up the `pg_readme` extension to generate a thorough README for this extension, based on the `pg_catalog` and the `COMMENT` objects found therein.
$md$;

--------------------------------------------------------------------------------------------------------------

create function pg_extra_time_meta_pgxn()
    returns jsonb
    stable
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
                "file": "pg_extra_time--2.0.0.sql",
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
$md$Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

`pg_extra_time` can indeed be found on PGXN: https://pgxn.org/dist/pg_readme/
$md$;

--------------------------------------------------------------------------------------------------------------
-- A bunch of constant functions to return various epochs.
--------------------------------------------------------------------------------------------------------------

create function unix_epoch()
    returns timestamptz
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return 'epoch'::timestamptz;

comment on function unix_epoch() is
$md$Constant function to retrieve the Unix epoch as a `timestamptz` value.

Don't use this function.  Directly use `'epoch'::timestamptz` instead.  Yeah,
this function just exists to remind the extension author of Postgres'
understanding of the `'epoch'` `timestamp`(`tz`) input.
$md$;

--------------------------------------------------------------------------------------------------------------

create function mssql_epoch()
    returns timestamptz
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return '1900-01-01 00:00:00 UTC'::timestamptz;

comment on function mssql_epoch() is
$md$Constant function to retrieve Microsoft SQL Server's epoch as a `timestamptz` value.

Of course, you can (and, in many cases, _should_) also just copy-paste the
timestamp literal from this function's body.
$md$;

--------------------------------------------------------------------------------------------------------------

create function nt_epoch()
    returns timestamptz
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return '1601-01-01 00:00:00 UTC'::timestamptz;

comment on function nt_epoch() is
$md$The time epoch used in Windows 32/64, NTFS and COBOL.

Of course, you can (and, in many cases, _should_) also just copy-paste the
timestamp literal from this function's body.
$md$;

--------------------------------------------------------------------------------------------------------------
-- Functions and casts to convert `tstzrange` values to `interval`s.
--------------------------------------------------------------------------------------------------------------

create function to_interval(
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

comment on function to_interval(tstzrange, interval[]) is
$md$Divide the datetime range given in the first argument over the given `interval`(s) in the second argument.

The function starts with as many of the biggest units given as fit in the
datetime range, then tries the next-biggest unit with the remainder, etc.

As of version 2.0.0, this function does not (yet) order the `interval[]` array
by decreasing `interval` size itself.  Therefore, the `interval[]` array must
be passed greatest-first for this function to work correctly.

This function simply discards the remainder of the range that does not fit in
the smallest given `interval` in the array of valid intervals.  Thus, rounding
is always down and never up.

See the [`test__to_interval()`](#procedure-test__to_interval) procedure for examples.
$md$;

--------------------------------------------------------------------------------------------------------------

create function to_interval(tstzrange)
    returns interval
    returns null on null input
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    language sql
    return to_interval(
        $1,
        array[
            -- interval '1 millennium',  -- intentionally omitted
            -- interval '1 century',  -- intentionally omitted
            -- interval '1 decade',  -- intentionally omitted
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

comment on function to_interval(tstzrange) is
$md$Extract an interval from a datetime range, starting with the largest interval unit possible, and down to the microsecond.

“Largest interval unit possible” must be taken with a grain of salt, because
this function ignores the units that are never part of the [interval `text `
output](https://www.postgresql.org/docs/current/datatype-datetime.html#DATATYPE-INTERVAL-OUTPUT).
Those are:

  - all units greater than a `year`—`decade`, `century` and `millennium`, and
  - `week`.

Note that, even if you call [`to_interval(tstzrange,
interval[])`](#function-to_interval-tstzrange-interval) directly instead
and include those excluded intervals in the given `interval` array, the result
will be the same as if you did include these units, because “[i]nternally,
interval values are stored as three integral fields: months, days, and
microseconds.”

Also note that, if you simply wish to convert a `tstzrange` value and then
_truncate_ the resulting interval, you can either use Postgres' standard
`date_trunc(text, interval)` function, or cast to an `interval` type with
`fields` specifier, as in:

```sql
select '3 months 12 days 10 minutes'::interval month = '3 months'::interval;  -- true
select '3 months 12 days 10 minutes'::interval day = '3 months 12 days'::interval;  -- true
```

Be aware, however, that, unlike when calling `to_interval()`, units with large enough quantities that they would

```sql
select '1 year 3 months'::interval month = '3 months'::interval;  -- true
```

The extension author would have preferred to call this function simply
`interval`, thereby conforming to [the recommendationin the `CREATE CAST`
documentation](https://www.postgresql.org/docs/current/sql-createcast.html#SQL-CREATECAST-NOTES),
if not for the fact that that produced a “syntax error”:

> While not required, it is recommended that you continue to follow this old
> convention of naming cast implementation functions after the target data
> type. Many users are used to being able to cast data types using a
> function-style notation, that is `typename(x)`. This notation is in fact
> nothing more nor less than a call of the cast implementation function; it is
> not specially treated as a cast. If your conversion functions are not named
> to support this convention then you will have surprised users. Since
> PostgreSQL allows overloading of the same function name with different
> argument types, there is no difficulty in having multiple conversion
> functions from different types that all use the target type's name.

In his opinion, this is another good reason to have this in Postgres' core.
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (tstzrange as interval)
    with function to_interval(tstzrange)
    as assignment;

comment on cast (tstzrange as interval) is
$md$Cast a datetime range to the intervals that fit in that range, starting with the largest interval unit possible, and down to the microsecond.$md$;

--------------------------------------------------------------------------------------------------------------

create function extract_interval(tstzrange, interval[])
    returns interval
    returns null on null input
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
begin
    raise warning using
        errcode = '01P01'  -- `deprecated_feature`; https://www.postgresql.org/docs/current/errcodes-appendix.html
        ,message = '`extract_interval(tstzrange, interval[])` has been deprected since `pg_extra_time` 2.0.'
        ,hint = 'Please use `to_interval(tstzrange, interval[])` directly instead of'
                ' `extract_interval(tstzrange, interval[])`.';

    return to_interval($1, $2);
end;
$$;

comment on function extract_interval(tstzrange, interval[]) is
$md$Deprecated function alias, as of `pg_extra_time` 2.0, then reincarnated as `to_interval(tstzrange, interval[])`.

If still using this function, change your code to use [`to_interval(tstzrange,
interval[])`](#function-to_interval-tstzrange-interval).
$md$;

--------------------------------------------------------------------------------------------------------------

create function extract_interval(tstzrange)
    returns interval
    returns null on null input
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
begin
    raise warning using
        errcode = '01P01'  -- `deprecated_feature`; https://www.postgresql.org/docs/current/errcodes-appendix.html
        ,message = '`extract_interval(tstzrange)` has been deprected since `pg_extra_time` 2.0.'
        ,hint = 'Please use `to_interval(tstzrange)` directly instead of `extract_interval(tstzrange)`.';

    return to_interval($1);
end;
$$;

comment on function extract_interval(tstzrange) is
$md$Deprecated function alias, as of `pg_extra_time` 2.0, then reincarnated as `to_interval(tstzrange)`.

If still using this function, change your code to use
[`to_interval(tstzrange])`](#function-to_interval-tstzrange).
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__to_interval()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert to_interval(
            tstzrange('2022-07-22', '2022-09-23'),
            array[interval '1 month', interval '1 hour']
        ) = interval '2 month 24 hour';

    assert tstzrange('2022-07-20', '2022-09-28')::interval = interval '2 month 1 week 1 day';
    -- `WEEK` is support as input, but is always outputted as `7 DAYS`
    assert interval '2 month 1 week 1 day' = interval '2 month 8 day';  -- See?

    assert tstzrange('1001-07-20', '2002-07-20')::interval = interval '1 millennium 1 year';

    assert to_interval(
            tstzrange('1001-07-20', '2242-07-20')
        ) = interval '1 millennium 2 century 4 decade 1 year';

    assert interval '1 millennium 2 century 4 decade 1 year' = interval '1241 year';

    -- Summer time started on March 27 in 2022
    assert to_interval(
            tstzrange('2022-03-01', '2022-05-8'),
            array[interval '1 month', interval '1 day', interval '1 hour']
        ) = interval '2 month 1 week';
end;
$$;

--------------------------------------------------------------------------------------------------------------
-- Functions and casts to get the number of days (whole as `int`, or fractional as `float`) in a `tstzrange`
--------------------------------------------------------------------------------------------------------------

create function whole_days(tstzrange)
    returns integer
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    return (
        date_trunc(
            'day'
            ,(
                upper($1) - make_interval(secs=>0.000001) * (not upper_inc($1))::int
                - (lower($1) + make_interval(secs=>0.000001) * (not lower_inc($1))::int)
            )
        )
    );

comment on function whole_days(tstzrange) is
$md$Get the number of whole days that fit in the given `tstzrange` value.

For example usage of `whole_days(tstzrange)`, see the test procedure
[`test__whole_days_from_tstzrange()`](#procedure-test__whole_days_from_tstzrange).

Prior to `pg_extra_time` 2.0.x, this function was called `extract_days()`.
But, Postgres its built-in `extract()` function has different semantics—a good
reason to drop `extract_` from this function's name.  Instead, the `whole_`
prefix was added, to distinguish this function from its new
[`days(tstzrange)`](#function-days-tstzrange) counterpart, that also returns
the possibly remaining day fraction.
$md$;

--------------------------------------------------------------------------------------------------------------

create function whole_days(tstzrange, double precision = 0.000001)
    returns integer
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    return (
        date_trunc(
            'day'
            ,(
                upper($1) - make_interval(secs=>$2) * (not upper_inc($1))::int
                - (lower($1) + make_interval(secs=>$2) * (not lower_inc($1))::int)
            )
        )
    );

--------------------------------------------------------------------------------------------------------------

create cast (tstzrange as integer)
    with function whole_days(tstzrange)
    as assignment;

comment on cast (tstzrange as integer) is
$md$Convert a `tstzrange` to an `integer` value representing the number of whole days from the interval between the two datetimes.

For example usage of `cast(tstzrange as integer)`, see the test procedure
[`test__whole_days_from_tstzrange()`](#procedure-test__whole_days_from_tstzrange).

In `pg_extra_time` 2.0.0, this cast was changed from using the ill-named and
ill-behaved [`extract_days(tstzrange)`](#function-extract_days-tstzrange)
function to the more enlightened
[`whole_days(tstzrange)`](#function-whole_days-tstzrange) function, with the
consequence that inclusive or exclusive of bounds are no longer faultily
interpreted as a day more or less, but rather as microseconds (the precision of
the timestamps in a `tstzrange`).
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__whole_days_from_tstzrange()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert whole_days('[2024-06-15 01:10, 2024-06-16 01:10)'::tstzrange) = 0;
    assert whole_days('[2024-06-15 01:10, 2024-06-16 01:11)'::tstzrange) = 1;
    assert whole_days('[2024-06-15 01:10, 2024-06-16 01:10]'::tstzrange) = 1;
    assert whole_days('(2024-06-15 01:10, 2024-06-16 01:10]'::tstzrange) = 0;
    assert whole_days('[2024-06-15 01:00:01, 2024-06-16 01:00:01)'::tstzrange) = 0;
    assert whole_days('[2024-06-15 01:00:01, 2024-06-16 01:00:01]'::tstzrange) = 1;
    assert whole_days('[2021-12-01,2022-01-01)'::tstzrange) = 30;
    assert whole_days('[2021-12-01,2022-01-01]'::tstzrange) = 31;
    assert whole_days('(2021-12-01,2022-01-01)'::tstzrange) = 30;
    assert whole_days('(2021-12-01,2022-01-01)'::tstzrange) = 30;
    assert whole_days('[2022-01-01,2022-01-10 15:00)'::tstzrange) = 9;
    assert whole_days('[2022-01-01,2022-01-01 23:00)'::tstzrange) = 0;
    assert whole_days('[2022-01-01,2022-01-01 23:00]'::tstzrange) = 0,
        whole_days('[2022-01-01,2022-01-01 23:00]'::tstzrange);

    -- Cast should behave the same as the direct function calls above.
    assert '[2021-12-01,2022-01-01)'::tstzrange::integer = 30;
    assert '[2021-12-01,2022-01-01]'::tstzrange::integer = 31;
    assert '(2021-12-01,2022-01-01]'::tstzrange::integer = 30;
    assert cast('[2021-12-01,2022-01-01)'::tstzrange as integer) = 30;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function extract_days(tstzrange)
    returns integer
    returns null on null input
    language plpgsql
    immutable
    leakproof
    parallel safe
    as $$
begin
    raise warning using
        errcode = '01P01'  -- `deprecated_feature`; https://www.postgresql.org/docs/current/errcodes-appendix.html
        ,message = '`extract_days(tstzrange)` has been deprected since `pg_extra_time` 2.0.'
        ,hint = 'Please use `whole_days(tstzrange)` instead of `extract_days(tstzrange)`.';

    return (date_trunc('day', upper($1))::date - date_trunc('day', lower($1))::date)
            + upper_inc($1)::int - (lower_inc($1) = false)::int;
end;
$$;

comment on function extract_days(tstzrange) is
$md$Deprecated function alias, as of `pg_extra_time` 2.0—then reincarnated as `whole_days(tstzrange)`.

This function has a rather peculiar interpretation of inclusivity of the given
`tstzrange` bounds: it interprets inclusivity and exclusivity of these bounds
as representing the absence or presence of that day.  The sensible thing to do
is is to interpret inclusivity at the microsecond level, since a `tstzrange`
consists of `timestamptz` values with maximum precision, and this is precisely
what the newer [`days(tstzrange)`](#function-days-tstzrange) function does.

For example usage of this function, see the
[`test__extract_days_from_tstzrange()`](#procedure-test__extract_days_from_tstzrange)
procedure.
$md$;

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
    assert extract_days('[2022-01-01,2022-01-10 15:00)'::tstzrange) = 9;
    assert extract_days('[2022-01-01,2022-01-01 23:00)'::tstzrange) = 0;
    assert extract_days('[2022-01-01,2022-01-01 23:00]'::tstzrange) = 1;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function days(tstzrange)
    returns float
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    return extract(
        'epoch' from (
            upper($1)
            - make_interval(secs=>0.000001) * (not upper_inc($1))::int
            - make_interval(secs=>0.000001) * (not lower_inc($1))::int
            - lower($1)
        )
    ) / 86400;

comment on function days(tstzrange) is
$md$Get the number of days, including the fraction of the remainder day, between the start and end of the given `tstzrange`.

Because Postgres' built-in `tstzrange` type has microsecond precision,
inclusivity of the lower and upper bounds is interpreted as the inclusion or
not of a microsecond at either end.

If you have your own custom `tstzrange*` types based on `timestamptz`
subtypes of other precisions, best also create create an overloaded version of
this present function.

For example usage of `days(tstzrange)`, see the test procedure
[`test__days_from_tstzrange()`](#procedure-test__days_from_tstzrange).
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (tstzrange as float)
    with function days(tstzrange)
    as assignment;

comment on cast (tstzrange as float) is
$md$Convert a `tstzrange` value to a `double precision` value representing the number of days, including day fraction.

For example usage of `cast(tstzrange as float)`, see the test procedure
[`test__days_from_tstzrange()`](#procedure-test__days_from_tstzrange).
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__days_from_tstzrange()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert days('[2021-12-01,2022-01-01]'::tstzrange) = 31.0;
    assert days('(2021-12-01,2021-12-02)'::tstzrange) between 0.9 and 1.0;
    assert days('[2021-12-01,2021-12-02 00:00:00.000001)'::tstzrange) = 1.0;
    assert days('[2022-01-01,2022-01-09 12:00]'::tstzrange) = 8.5;
    assert days('[2022-01-01,2022-01-09 12:00:00.000001)'::tstzrange) = 8.5;
    assert days('[2022-01-01,2022-02-01 06:00]'::tstzrange) = 31.25;
    assert days('[2022-01-01,2022-02-01 06:00:00.000001)'::tstzrange) = 31.25;
    assert round(days('[2022-01-01 10:00:00.000013,2022-01-09 16:00:00.000023)'::tstzrange)::numeric, 12) = round(
        8.25 + extract('second' from make_interval(secs=>0.000022-0.000013)) / 86400
        ,12
    );
    assert round(days('(2022-01-01 10:00:00.000013,2022-01-09 22:00:00.000021)'::tstzrange)::numeric, 12) = round(
        8.5 + extract('second' from make_interval(secs=>0.000020-0.000014)) / 86400
        ,12
    );
    assert round(days('[2022-01-01 00:20:00.000013,2022-01-09 12:20:00.000023]'::tstzrange)::numeric, 12) = round(
        8.5 + extract('second' from make_interval(secs=>0.000023-0.000013)) / 86400
        ,12
    );

    assert '[2021-12-01,2022-01-01)'::tstzrange::float = 31.0;

    assert cast('[2021-12-01,2022-01-01)'::tstzrange as float) = 31.0;
end;
$$;

--------------------------------------------------------------------------------------------------------------
-- Functions and casts to get the number of days from a `daterange`.
--------------------------------------------------------------------------------------------------------------

create function days(daterange)
    returns int
    returns null on null input
    immutable
    leakproof
    parallel safe
    language sql
    return upper($1) - lower($1) - 1;

comment on function days(daterange) is
$md$Get the number of days in the given `daterange`.

Given the simplicity of this function, you may (and probably should) just as
well use the `upper($1) - lower($1) - 1` expression in your code directly.

Still, it is useful to have the function here in `pg_extra_time` from a
librarian perspective, to remind us that, as stated under [_Discrete Range
Types_](https://www.postgresql.org/docs/current/rangetypes.html#RANGETYPES-DISCRETE)
in the Postgres docs:

> The built-in range type[…] daterange […] use[s] a canonical form that
> includes the lower bound and excludes the upper bound; that is, `[)`.

This means that `[2022-06-01,2022-06-02]`::daterange is canonicalized into
`[2022-06-01,2022-06-03)`.  As a consequence:

1. we never have to check `lower_inc(daterange)` or `upper_inc(daterange)`
   (the former _always_ and the latter _never_ being true); and
2. we always have to subtract 1 from the difference between `upper(daterange)`
   and `lower(daterange)`, because of that.

See the [`test__daterange_to_days()`](#procedure-test__daterange_to_days)
procedure for usage examples.
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (daterange as int)
    with function days(daterange)
    as assignment;

comment on cast (daterange as int) is
$md$Convert a `daterange` value to the number of days in that range, in a bound-inclusivity-aware manner.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__days_in_daterange()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert days('[2022-06-01,2022-06-01)'::daterange) is null;
    assert days('[2022-06-01,2022-06-02)'::daterange) = 0;
    assert days('[2022-06-01,2022-06-22)'::daterange) = 20;
    assert '[2022-06-01,2022-06-22]'::daterange::text = '[2022-06-01,2022-06-23)'::daterange::text;
    assert days('[2022-06-01,2022-06-22]'::daterange) = 21;
end;
$$;

--------------------------------------------------------------------------------------------------------------
-- Functions and casts to get the number days in an `interval`:
--    - as an `integer`, rounded down to whole days; or
--    - as a `float`, including the remaining fraction of a day.
--------------------------------------------------------------------------------------------------------------

create function days(interval)
    returns float
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return extract(epoch from $1) / 86400;

comment on function days(interval) is
$md$Extract the number of days, including fractions, from a given `interval` value.

The choice for days (rather than seconds) is taken to be consistent with MSSQL,
which, when converting a `DATETIME` to a `FLOAT` counts from the MSSQL epoch in
days, not seconds.

If you want to convert an `interval` to (sub)seconds, use the Postgres-standard:

```
extract('epoch' from interval)
```
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (interval as float)
    with function days(interval)
    as assignment;

comment on cast (interval as float) is
$md$Convert an `interval` value to a number of whole days plus day fraction.

The choice for days (rather than seconds) is taken to be consistent with MSSQL,
which, when converting a `DATETIME` to a `FLOAT` counts from the MSSQL epoch in
days, not seconds.

If you want to convert an `interval` to (sub)seconds, use the Postgres-standard:

```
extract('epoch' from interval)
```
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__days_from_interval()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert cast('1 day 6 hours'::interval as float) = 1.25;
    assert days('0'::interval) = 0;
    assert days('1 day'::interval) = 1;
    assert days('12 hours'::interval) = 0.5;
    assert days('1 day 12 hours'::interval) = 1.5;
    assert days('3 days 6 hours'::interval) = 3.25;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function whole_days(interval)
    returns integer
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return floor(extract(epoch from $1) / 86400);

comment on function whole_days(interval) is
$md$Get the number of whole days (rounded down) present in a given `interval` value.

The choice for days (rather than seconds) is taken to be consistent with MSSQL,
which, when converting a `DATETIME` to a `FLOAT` counts from the MSSQL epoch in
days, not seconds.

If you want to convert an `interval` to (sub)seconds, use the Postgres-standard:

```
extract('epoch' from interval)`
```

Please don't be clever and make this function reuse `days(interval)`:

1. The functions in this extensions are meant to be copy-pastable apart from
   each other independently.
2. Individual SQL functions can be inlined by the planner, but not nested
   functions.
3. These functions are way to simple to justify reuse.
4. And we have test cases.
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (interval as integer)
    with function whole_days(interval)
    as assignment;

comment on cast (interval as integer) is
$md$Extract the number of whole days (rounded down) from a given `interval` value.

The choice for days (rather than seconds) is taken to be consistent with MSSQL,
which, when converting a `DATETIME` to a `FLOAT` counts from the MSSQL epoch in
days, not seconds.
$md$;

--------------------------------------------------------------------------------------------------------------

create function extract_days(interval)
    returns integer
    returns null on null input
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
begin
    raise warning using
        errcode = '01P01'  -- `deprecated_feature`; https://www.postgresql.org/docs/current/errcodes-appendix.html
        ,message = '`extract_days(interval)` has been deprected since `pg_extra_time` 2.0.'
        ,hint = 'Please use `whole_days(interval)` directly instead of `extract_days(interval)`.';

    return whole_days($1);
end;
$$;

comment on function extract_days(interval) is
$md$Deprecated function alias, as of `pg_extra_time` 2.0—then reincarnated as `whole_days(interval)`.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__whole_days_from_interval()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert whole_days(interval '1 month') = 30;
    assert whole_days(interval '1 week') = 7;
    assert whole_days(interval '3 month 1 week 2 days') = 99;
    assert cast(interval '2 days 10 minutes' as int) = 2;
    assert '1 day 23 hours'::interval::int = 1;

    assert extract_days('1 day 23 hours'::interval) = 1;  -- Should raise a `deprecated_feature` warning.
end;
$$;

--------------------------------------------------------------------------------------------------------------
-- Additional, slightly opiniated datetime operators that are missing in Postgres.
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
$md$As you would expect from a modulo operator, this function returns the remainder of the given datetime range after dividing it in as many of the given whole intervals as possible.
$md$;

--------------------------------------------------------------------------------------------------------------

create operator % (
    leftarg = tstzrange
    ,rightarg = interval
    ,function = modulo
    ,commutator = %
);

comment on operator % (tstzrange, interval) is
$md$As you would expect from a modulo operator, this operator yields the remainder of the given datetime range after dividing it in as many of the given whole intervals as possible.
$md$;

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

create function modulo(interval, interval)
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
-- `date_part_parts()` function and test routine.
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

--------------------------------------------------------------------------------------------------------------

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
- down, discarding the remainder, if `round_remainder$ <= -1`; or
- not at all and kept as the remainder, if `round_remainder = 0`.

See the [`test__each_subperiod`](#procedure-test__each_subperiod) routine for
examples.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__each_subperiod()
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
-- Functions to make a `ts[tz]range` from a `timestamp[tz]` and an interval.
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
-- Easy access to `pg_timezone_names` view.
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
