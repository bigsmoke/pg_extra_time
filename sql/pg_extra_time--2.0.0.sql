-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on extension pg_extra_time is
$markdown$
# `pg_extra_time` PostgreSQL extension

The `pg_extra_time` PostgreSQL extension contains some date time functions and
operators that, according to the extension author, ought to be part of the
PostgreSQL standard distribution.

## From `tstzrange`/`tsrange`, `interval` and `timestamp`/`timestamptz` to seconds or days

`pg_extra_time` has functions to convert various PostgreSQL datetime types
(`tstzrange`/`tsrange`, `interval`, and `timestamp`/`timestamptz`) to the
number of seconds or days (in the range, interval or since the Unix epoch,
respectively).

| Function                                                                | Example                                                                      |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| [`to_float(timestamptz)`](#function-to_float-timestamp-with-time-zone)  | `to_float('1970-01-01 00:00:00+0'::timestamptz) --> 0.0`                     |
| [`to_float(timestamp)`](#function-to_float-timestamp-without-time-zone) | `to_float('1970-01-01 00:00:00+0'::timestamp) --> 0.0`                       |
| [`to_float(tstzrange)`](#function-to_float-tstzrange)                   | `to_float('[2024-06-06 05:58:00,2024-06-06 06:00:10]'::tstzrange) --> 130.0` |
| [`to_float(tsrange)`](#function-to_float-tsrange)                       | `to_float('[2024-06-06 05:58:00,2024-06-06 06:00:10]'::tsrange) --> 130.0`   |
| [`to_float(interval)`](#function-to_float-interval)                     | `to_float(interval '10 seconds 100 milliseconds') --> 10.100`                |
| [`days(tstzrange)`](#function-days-tstzrange)                           | `days('[2024-06-06,2024-06-08 06:00]'::tstzrange) --> 3.25`                  |
| [`whole_days(tstzrange)`](#function-whole_days-tstzrange)               | `whole_days('[2024-06-06,2024-06-08 18:00]'::tstzrange) --> 2.5`             |
| [`days(interval)`](#function-days-interval)                             | `days('10 days 12 hours'::interval) --> 10.5`                                |
| [`whole_days(interval)`](#function-whole_days-interval)                 | `whole_days('10 days 20 hours 20 minutes'::interval) --> 10`                 |

Converting from these datetime types to seconds can be done by casting to
a `double precision`/`float` value as well.

| Cast                 | `WITH FUNCTION`                                           | Example                                                           |
| -------------------- | --------------------------------------------------------- | ----------------------------------------------------------------- |
| `timestamptz::float` | [`to_float(timestamptz)`](#function-to_float-timestamptz) |  `'1970-01-01 01:03:01+00'::timestamptz::float --> 3181.00`       |
| `timestamp::float`   | [`to_float(timestamp)`](#function-to_float-timestamp)     |  `'1970-01-02 00:00:01+00'::timestamp::float --> 86401.0`         |
| `tstzrange::float`   | [`to_float(tstzrange)`](#function-to_float-tstzrange)     |  `'[epoch,1970-01-01T01:03:01+00]'::tstzrange::float --> 3181.00` |
| `tsrange::float`     | [`to_float(tsrange)`](#function-to_float-tsrange)         |  `'[epoch,1970-01-01T01:03:01+00]'::tsrange::float --> 3181.00`   |
| `interval::float`    | [`to_float(interval)`](#function-to_float-interval)       |  `'1 day 1 sec 200 ms 200 us'::interval::float --> 86401.2002`    |

Note that the
[`to_float(tstzrange)`](#function-to_float-tstzrange)/`tstzrange::float` and
[`to_float(tsrange)`](#function-to_float-tsrange)/`tsrange::float` functions
will:

1. return positive or negative infinity if there's no upper bound and/or lower
   bound in the range, respectively;
2. return 0 if the given range is altogether empty.

Casts to `integer` are not provided, because the extension author doesn't want
to impose an opinion on rounding to the users of `pg_extra_time`.  Note that
this distinctly differs from `pg_extra_time` < 2.0.0, when casting a
`tstzrange` or `interval` to an integer meant the number of whole days (rounded
down) in that range or interval; this functionality is now available via the
[`whole_days(tstzrange)`](#function-whole_days-tstzrange) and
[`whole_days(interval)`](#function-whole_days-interval) functions,
respectively.

### Why cast to seconds and not days (or something else)?

PostgreSQL (as of version 16) doesn't come with built-in casts of date-timey
types to `float`s and/or `integer`s.  So the extension author had to make a
choice what unit to cast _to_.

Counting the number of seconds since the Unix epoch has become a prominent
means of representing timestamps on modern platforms.  PostgreSQL itself
stores `timestamp` values internally as the number of _micro_-seconds and not
counting from the Unix epoch (January 1 1970), but from January 1 2000.  But,
as a testimony to the ubiquitousness of the Unix epoch, Postgres allows users
to easily convert `timestamp`(`tz`) values to and from a Unix timestamp:

* `extract('epoch' from timestamp)`, `extract('epoch' from timestamptz)`,
  `extract('epoch' from interval)`; and
* `to_timestamp(double precision)`, respectively.

```sql
select extract('epoch' from timestamptz '2010-09-13 04:32:03+00');  --> 1284352323
select extract('epoch' from interval '10 seconds 100 milliseconds');  --> 10.100000
select to_timestamp(1284352323);  --> '2010-09-13 04:32:03+00'
```

PostgreSQL even allows its users to simply input `epoch` in a `timestamp`
string literal:

```sql
select 'epoch'::timestamptz;  --> '1970-01-01 01:00:00+01'
```

So, indeed, although PostgreSQL internally counts from 2000-01-01, it considers
as the epoch the One True Epoch: The Unix One.

In `pg_extra_time` < 2.0, the extension author made the mistake of following
MSSQL's lead in making `tstzrange` and `interval` values cast to days rather
than seconds when converting to `integer`.  This was mistaken:

1. Even though MSSQL has forever come with the ability to convert `DATETIME`
   values to `FLOAT` values (and, until recently, the avility to convert
   `DATETIME` values to `INTEGER` as well), MSSQL, as of its 2016 release,
   has no concept of intervals, nor of ranges.  Thus, there were really no
   sensible semantics to copy there.
2. `CAST(DATETIME AS FLOAT)` in MSSQL returns the number of days since the
   MSSQL's epoch (see the [`mssql_epoch()`](#function-mssql_epoch) function),
   which is completely senseless out of the context of MSSQL.  (Not that
   `pg_extra_time` supported casting `timestamp(tz)` to float _at all_, just
   to show that furthering consistency with MSSQL would make things even
   worse for modern users not used to Microsoft's decrepit SQL Server.)

### Why `to_float()` and not `float()`?

Indeed, if this wouldn't cause a syntax error, the extension author _would_
have called these functions `float(datetimeytype)` rather then
`to_float(datetimeytype)`, because “[it is
recommended](https://www.postgresql.org/docs/current/sql-createcast.html) that
you continue to follow this old convention of naming cast implementation
functions after the target data type.”

## Backwards (in)compatibility of casting to `integer` days

`pg_extra_time` 2.0.0 dropped the pre-2.0 semantics that casting a `tstzrange`
or `interval` to an `integer` would cast to a number of days (MSSQL-style)
rather than the number of seconds.  (As discussed above, `pg_extra_time` 2.0

## Installing & using this extension

When using this extension, _please_ feel free to not actually use it as an
extension and instead just copy-paste the precise function(s) and/or cast(s)
that you need.  To make copy-pasting bits and pieces easier, the extension
author has tried his best not to succumb to the DRY disease and thus not reuse
functions in other functions, only to save a few characters and introduce extra
indirection (and sloth, because Postgres, as of version 16, supports inlining
of SQL functions, but only one level deep).  And DRY to save on bugs?  Come on
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

Of course, you can (and, in most cases, _should_) also just copy-paste the
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

Of course, you can (and, in most cases, _should_) also just copy-paste the
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
is always down and never up.  If you are specifically interested in the
remainder, see the `tstzrange % interval` operator and its supporting
[`modulo(tstzrange, interval)`](#function-modulo-tstzrange-interval) function.

Note that `to_interval(tstzrange, interval[])` has very distinct semantics from
simply subtracting the `lower(tstzrange)` from the `upper(tstzrange)` and then
truncating using `date_trunc('<field>' from interval)` or `cast(interval as
interval <fields>)`, because when truncating you will simply use any subfields
with units smaller than the included intervals, even if these subfields have
large enough quantities to fit in the bigger, included fields:

```sql
select '3 months 12 days 70 minutes'::interval day;  --> '3 mons 12 days'
```

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
        array['1 month'::interval, '1 day'::interval, '1 microsecond'::interval]
    );

comment on function to_interval(tstzrange) is
$md$Extract an interval from a datetime range, starting with the largest interval unit possible, and down to the microsecond.

“Largest interval unit possible” must be taken with a grain of salt, because
this function ignores the units that are never part of the [interval `text `
output](https://www.postgresql.org/docs/current/datatype-datetime.html#DATATYPE-INTERVAL-OUTPUT).
Those are:

  - all units greater than a `year`—`decade`, `century` and `millennium`,
  - as well as `week`.

Note that, even if you call [`to_interval(tstzrange,
interval[])`](#function-to_interval-tstzrange-interval) directly instead
and include those excluded intervals in the given `interval` array, the result
will be the same as if you did include these units, because “[i]nternally,
interval values are stored as three integral fields: months, days, and
microseconds.”

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

In the author's opinion, this is another good reason to have this function in
Postgres' core.  Or should it then be called `fit_interval()` instead?
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (tstzrange as interval)
    with function to_interval(tstzrange)
    as assignment;

comment on cast (tstzrange as interval) is
$md$Cast a datetime range to the intervals that fit in that range, starting with the largest interval unit possible, and down to the microsecond.
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

    -- Internally in Pg, intervals are stored as months, days and microseconds.
    assert interval '2 month 1 week 1 day' = interval '2 month 8 day';  -- See?

    assert extract_interval(
            tstzrange('1001-07-20', '2242-07-20')
        ) = interval '1 millennium 2 century 4 decade 1 year';

    -- Internally in Pg, intervals are stored as months, days and microseconds.
    assert interval '1 millennium 2 century 4 decade 1 year' = interval '1241 year';

    -- Summer time started on March 27 in 2022.
    assert extract_interval(
            tstzrange('2022-03-01', '2022-05-8'),
            array[interval '1 month', interval '1 day', interval '1 hour']
        ) = interval '2 month 1 week';
end;
$$;

--------------------------------------------------------------------------------------------------------------
-- Functions and casts to convert timestamp (ranges) and intervals to the number of seconds (since the Unix
-- epoch, between the points in the range or in the interval).
--------------------------------------------------------------------------------------------------------------

create function to_float(timestamp)
    returns float
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return extract('epoch' from $1);

comment on function to_float(timestamp) is
$md$Get the given `timestamp` as the number of seconds (down to microseconds) elapsed since the Unix epoch.

Don't use this function.  Just use `extract('epoch' from timestamp)` directly
instead.  This function solely serves as a support function for the
`timestamp::float` cast.
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (timestamp as float)
    with function to_float(timestamp)
    as assignment;

comment on cast (timestamp as float) is
$md$Convert a `timestamp` value to the number of seconds (down to microseconds in the decimal part) since the Unix epoch.
$md$;

--------------------------------------------------------------------------------------------------------------

create function to_float(timestamptz)
    returns float
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return extract('epoch' from $1);

comment on function to_float(timestamptz) is
$md$Get the given `timestamp` as the number of seconds (down to microseconds) elapsed since the Unix epoch.

Don't use this function.  Just use `extract('epoch' from timestamptz)` directly
instead.  This function solely serves as a support function for the
`timestamptz::float` cast.
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (timestamptz as float)
    with function to_float(timestamptz)
    as assignment;

comment on cast (timestamptz as float) is
$md$Convert a `timestamptz` value to the number of seconds (down to microseconds in the decimal part) since the Unix epoch.
$md$;

--------------------------------------------------------------------------------------------------------------

create function to_float(tsrange)
    returns float
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return case
        when isempty($1) then 0
        when lower_inf($1) and not upper_inf($1) then '-infinity'
        when upper_inf($1) then '+infinity'
        else extract('epoch' from (upper($1) - lower($1)))
            - 0.000001 * (not upper_inc($1))::int
            - 0.000001 * (not lower_inc($1))::int
    end;

comment on function to_float(tsrange) is
$md$Get the number of (fractional) seconds between the two points in the given `tsrange`.

  * When the given range is empty, that is interpreted as 0 seconds.
  * When the upper point in the given range is empty, the range is interpreted
    as an infinite number of seconds.
  * When the lower point is absent, the range instead is interpreted as a
    infinite negative number of seconds.
  * When both points are present, the distance in seconds between the two points
    is returned.

    Because the points in `tsrange` are of type `timestamp without time zone` /
    `timestamp`, which has microsecond precision, a microsecond is subtracted
    for either or both the lower and upper bound when it is exclusive.

If you have a custom `timestamp(p)` range type, you will want to overload this
function and subtract a fractional of a second corresponding to that precision
instead.
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (tsrange as float)
    with function to_float(tsrange)
    as assignment;

comment on cast (tsrange as float) is
$md$Convert a `tsrange` value to a `double precision` value representing the number of (fractional) seconds between the 2 points in the range.

See the comments on the [`to_float(tsrange)`](#function-seconds-tsrange)
function that powers this cast for further details.
$md$;

--------------------------------------------------------------------------------------------------------------

create function to_float(tstzrange)
    returns float
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    return case
        when isempty($1) then 0
        when upper_inf($1) then '+infinity'
        when lower_inf($1) then '-infinity'
        else extract('epoch' from (upper($1) - lower($1)))
            - 0.000001 * (not upper_inc($1))::int
            - 0.000001 * (not lower_inc($1))::int
    end;

comment on function to_float(tstzrange) is
$md$Get the number of (fractional) seconds between the two points in the given `tstzrange`.

  * When the given range is empty, that is interpreted as 0 seconds.
  * When the upper point in the given range is empty, the range is interpreted
    as an infinite number of seconds.
  * When the lower point is absent, the range instead is interpreted as a
    infinite negative number of seconds.
  * When both points are present, the distance in seconds between the two points
    is returned.

    Because the points in `tstzrange` are of type `timestamp with time zone` /
    `timestamptz`, which has microsecond precision, a microsecond is subtracted
    for either or both the lower and upper bound when it is exclusive.

For example usage of `to_float(tstzrange)`, see the test procedure
[`test__tstzrange_to_seconds()`](#procedure-test__tstzrange_to_seconds).

If you have a custom `timestamptz(p)` range type, you will want to overload this
function and subtract a fractional of a second corresponding to that precision
instead.
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (tstzrange as float)
    with function to_float(tstzrange)
    as assignment;

comment on cast (tstzrange as float) is
$md$Convert a `tstzrange` value to a `double precision` value representing the number of (fractional) seconds between the 2 points in the range.

See the comments on the [`to_float(tstzrange)`](#function-seconds-tstzrange)
function that powers this cast for further details.
$md$;

--------------------------------------------------------------------------------------------------------------

create function to_float(interval)
    returns float
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return extract('epoch' from $1);

comment on function to_float(interval) is
$md$Convert a given `interval` to the number of seconds, including fractions.

You probably shouldn't use this function and just use `extract('epoch' from
interval)` instead.  This function primarily exists to power `cast(interval as
float)` (and to remind the reader that `extract('epoch' from interval)` is
always already possible in Postgres.
$md$;

--------------------------------------------------------------------------------------------------------------

create cast (interval as float)
    with function to_float(interval)
    as assignment;

comment on cast (interval as float) is
$md$Convert an `interval` value to the number of seconds in that interval, including fractions.
$md$;

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
    return case
        when isempty($1) then 0
        when upper_inf($1) or lower_inf($1) then null
        else floor(
            (
                extract('epoch' from upper($1))
                - extract('epoch' from lower($1))
            ) / 86400
        )
    end;

comment on function whole_days(tstzrange) is
$md$Get the number of whole days that fit in the given `tstzrange` value.

Zero is returned when the given `tstzrange` is empty.

Because Postgres doesn't support infinity values for integers, `null` is
returned when either end of the range is infinity; thus no distinction is made
between positive or negative infinity.  In fact, negative infinity would be an
impossibility anyway, because a range's lower bound must be less than or
equal to its upper bound, and `null` is not a too shabby choice to denote
infinity in this case, because `null` is similarly used to indicate infinity by
various [built-in range functions in Postgres]

The [`days(tstzrange)`](#function-days-tstzrange) function, which returns a
float value rather than an int can be used instead if you want explicit support
for infinity (which Postgres does have for floating point values, contrary to
its lack of support for postive and negative integer infinity.)

This function ignores inclusivity/exclusivity of both lower and upper bounds
of the given range.  Practically, this means that when you naively construct
a `tstzrange` `r` with an upper bound that is `d` days later than it lower
bound, `whole_days(r)` will return that same number of days `d`:

```sql
do $$
declare
    d int := 5;
    r tstzrange := tstzrange(now(), now() + format('%s days', d)::interval);
begin
    assert whole_days(r) = d;
end;
$$;
```

If you want to treat the `tstzrange` value as discrete rather than continuous
at a given level of subsecond precision, see the [`whole_days(tstzrange,
int)`](#function-whole_days-tstzrange-double_precision) function.

For example usage of `whole_days(tstzrange)`, see the test procedure
[`test__whole_days_from_tstzrange()`](#procedure-test__whole_days_from_tstzrange).

[built-in range functions in Postgres]: https://www.postgresql.org/docs/current/functions-range.html
$md$;

--------------------------------------------------------------------------------------------------------------

create function whole_days(tstzrange, double precision)
    returns integer
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    return case
        when isempty($1) then 0
        when upper_inf($1) or lower_inf($1) then null
        else floor(
            (
                extract('epoch' from upper($1))
                - extract('epoch' from lower($1))
                - $2 * (not upper_inc($1))::int
                - $2 * (not lower_inc($1))::int
            ) / 86400
        )
    end;

comment on function whole_days(tstzrange, double precision) is
$md$Get the number of whole days that fit in the given `tstzrange` value, subtracting the amount of `double precision` seconds for bounds that are exclusive.

When its second argument is zero (`0`), this function behaves identical to
[`whole_days(tstzrange)`](#function-whole_days-tstzrange), blindly truncating
without regard for bound exclusivity.

Zero is returned when the given `tstzrange` is empty.

Because Postgres doesn't support infinity values for integers, `null` is
returned when either end of the range is infinity; thus no distinction is made
between positive or negative infinity.  In fact, negative infinity would be an
impossibility anyway, because a range's lower bound must be less than or
equal to its upper bound, and `null` is not a too shabby choice to denote
infinity in this case, because `null` is similarly used to indicate infinity by
various [built-in range functions in Postgres]

The [`days(tstzrange, float)`](#function-days-tstzrange-double_precision)
function, which returns a float value rather than an int can be used instead if
you want explicit support for infinity (which Postgres does have for floating
point values, contrary to its lack of support for postive and negative
integer infinity.)

For example usage of `whole_days(tstzrange, float)`, see the test procedure
[`test__whole_days_from_tstzrange()`](#procedure-test__whole_days_from_tstzrange).
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__whole_days_from_tstzrange()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
declare
    _tstzrange tstzrange;
    _2nd_arg float;
    _expected_int int;
begin
    -- First, we test the truncating without awareness of bound in/exclusivity.
    for _tstzrange, _expected_int in
        select
            tstzrange(lower_bound::timestamptz, upper_bound::timestamptz, bound_type)
            ,expected_int
        from (
            values
                ('2024-06-15 01:10', '2024-06-16 01:10', 1)
                ,('2021-12-01', '2022-01-01', 31)
                ,('2022-01-01', '2022-01-10', 9)
                ,('2022-01-01', '2022-01-01', 0)
                ,('2022-01-01', '2022-01-01 23:59:59.999999', 0)
        ) as without_bound_types (lower_bound, upper_bound, expected_int)
        cross join (
            values ('[]'), ('[)'), ('(]'), ('()')
        ) as bound_types (bound_type)
    loop
        assert whole_days(_tstzrange) = _expected_int,
            format('whole_days(%L::tstzrange) ≠ %s', _tztzrange, _expected_int);

        assert whole_days(_tstzrange, 0.0) = _expected_int,
            format('whole_days(%L::tstzrange, %s) ≠ %s', _tztzrange, 0.0, _expected_int);
    end loop;

    -- Then we test treating the ranges as discrete ranges with a certain precision.
    assert whole_days('[2022-01-01, 2022-01-01 23:59:59.999999]'::tstzrange, 1.0) = 0;
    assert whole_days('[2022-01-01, 2022-01-02]'::tstzrange, 1.0) = 1;
    assert whole_days('[2022-01-01, 2022-01-02)'::tstzrange, 1.0) = 0;
    assert whole_days('[2022-01-01, 2022-01-02 00:00:00.000001]'::tstzrange, 0.000001) = 1;
    assert whole_days('[2022-01-01, 2022-01-02 00:00:00.000001)'::tstzrange, 0.000001) = 1;
    assert whole_days('[2022-01-01, 2022-01-02 00:00:00.000001)'::tstzrange, 0.000010) = 0;
    assert whole_days('[2022-01-01, 2022-01-02 00:00:00.000010)'::tstzrange, 0.000010) = 1;

    -- PostgreSQL integers do not support positive or negative infinity; `null` will have to do.
    assert whole_days('[,)'::tstzrange) is null;
    assert whole_days('[2024-06-15,)'::tstzrange) is null;
    assert whole_days('[,2024-06-15)'::tstzrange) is null;
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
$md$Deprecated function to get the number of whole days between the two points in the given range.

This function has a rather peculiar interpretation of inclusivity of the given
`tstzrange` bounds: it interprets inclusivity and exclusivity of these bounds
as representing the absence or presence of that day.  The sensible thing to do
is to either:

1. ignore inclusivity altogether, since `tstzrange`s are continuous and
   therefore ambiguous as to where they should be cut off, which is what the
   new [`days(tstzrange)`](#function-days-tstzrange) and
   [`whole_days(tstzrange)`](#function-whole_days-tstzrange) functions do; _or_
2. treat the range as discrete, and interpret inclusivity at some given level
   of subsecond precision, which is what the new [`days(tstzrange,
   float)`](#function-days-tstzrange-double_precision) and
   [`whole_days(tstzrange, float)`](#function-whole_days-tstzrange-double_precision)
   functions do.

Other reasons for deprecating this function (and its name) were:

1. Postgres its built-in `extract()` function has different semantics—a good
   reason to drop `extract_` from this function's name; and
2. it needed to be distinguishable from the new
   [`days(tstzrange)`](#function-days-tstzrange) function, which will also
   return fractions of a day in its `double precision` return value.

For example usage of `extract_days(tstzrange)`, see the
[`test__extract_days_from_tstzrange()`] procedure (but don't use it).

[`test__extract_days_from_tstzrange()`]:
#procedure-test__extract_days_from_tstzrange
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
-- Functions to convert `timestamp` (`with time zone`) and `interval`  values to a number of days with a
-- `double precision` fractional part.
--------------------------------------------------------------------------------------------------------------

create function days(tstzrange)
    returns float
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    return case
        when isempty($1) then 0
        when lower_inf($1) and not upper_inf($1) then '-infinity'
        when upper_inf($1) then '+infinity'
        else extract(
            'epoch' from (upper($1) - lower($1))
        ) / 86400
    end;

comment on function days(tstzrange) is
$md$Get the number of days, including the fraction of the remainder day, between the start and end of the given `tstzrange`.

Inclusivity or exclusivity of the range is ignored. If you want to treat a
`tstzrange` as discrete and have inclusivity/exclusivity interpreted as the
inclusion or not of a (sub)second, instead see the [`days(tstzrange,
integer)`](#function-days-tstzrange-integer) function.

For example usage of `days(tstzrange)`, see the test procedure
[`test__days_from_tstzrange()`](#procedure-test__days_from_tstzrange).

Note that when _casting_ to float, it's not this present function, but the
[`to_float(tstzrange)`](#function-to_float-tstzrange)` function that is used,
which puts the seconds rather than the days in front of the decimal point.
$md$;

--------------------------------------------------------------------------------------------------------------

create function days(tstzrange, double precision)
    returns float
    returns null on null input
    language sql
    immutable
    leakproof
    parallel safe
    return case
        when isempty($1) then 0
        when lower_inf($1) and not upper_inf($1) then '-infinity'
        when upper_inf($1) then '+infinity'
        else (
            (
                extract('epoch' from upper($1))
                - extract('epoch' from lower($1))
                - $2 * (not upper_inc($1))::int
                - $2 * (not lower_inc($1))::int
            )::numeric / 86400
        )
    end;

comment on function days(tstzrange, double precision) is
$md$Get the number of days, including the fraction of the remainder day, between the start and end of the given `tstzrange`, and treat range bounds as discrete values with a subtraction of the amount of (sub)seconds in the second argument for each exclusive bound.

The first argument is a `tstzrange` value that will be treated as discrete
rather than continuous as per the precision (between 0 and 6) given in the
second argument.  `1.0/10^$2` seconds are subtracted for each exlusive
`tstzrange` bound.

Postgres' built-in `tstzrange` type has microsecond precision; thus you may
wish to pass `10.0^(-6)` to have exclusivity of the lower and upper bounds be
interpreted as the subtraction or not of a microsecond at either end.

If you have your own custom `tstzrange*` domains based on `timestamptz`
subtypes of other precisions, you may want to pass `p` as the second argument
instead.

For example usage of `days(tstzrange, integer)`, see the test procedure
[`test__days_from_tstzrange()`](#procedure-test__days_from_tstzrange).

Note that when _casting_ to float, it's not this present function, but the
[`to_float(tstzrange)`](#function-to_float-tstzrange)` function that is used,
which puts the seconds rather than the days in front of the decimal point.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__tstzrange_to_days()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert days('[2021-12-01,2022-01-01)'::tstzrange) = 31.0;

    assert days('[2021-12-01,)'::tstzrange) = '+infinity'::float;
    assert days('[,)'::tstzrange) = '+infinity'::float;
    assert days('[,2021-12-31)'::tstzrange) = '-infinity'::float;

    -- Without a `range_bound_exclusivity_penalty_secs` argument, `days()` will ignore inclusivity/exclusivity
    -- of both the `lower(tstzrange)` and the `upper(tstzrange)` bounds.
    assert days('[2021-12-01,2021-12-02)'::tstzrange) = 1.0;
    assert days('[2021-12-01,2021-12-02)'::tstzrange, 0) = 1.0;
    assert days('[2021-12-01,2021-12-02)'::tstzrange) = days('[2021-12-01,2021-12-02]'::tstzrange);
    assert days('[2021-12-01,2021-12-02)'::tstzrange, 0) = days('[2021-12-01,2021-12-02]'::tstzrange, 0);
    assert days('[2021-12-01,2021-12-02)'::tstzrange) = days('(2021-12-01,2021-12-02]'::tstzrange);
    assert days('[2021-12-01,2021-12-02)'::tstzrange, 0) = days('(2021-12-01,2021-12-02]'::tstzrange, 0);
    assert days('[2022-01-01,2022-01-09 12:00)'::tstzrange) = 8.5;
    assert days('[2022-01-01,2022-01-09 12:00)'::tstzrange, 0) = 8.5;
    assert days('[2022-01-01,2022-02-01 06:00)'::tstzrange) = 31.25;
    assert days('[2022-01-01,2022-02-01 06:00)'::tstzrange, 0) = 31.25;

    assert days('(2021-12-01,2021-12-02)'::tstzrange, 1.0) = 1.0 - (2.0/86400)/10^0,
        '1 second should have been subtracted for both exclusive `tstzrange` bounds.';
    assert days('(2021-12-01,2021-12-02)'::tstzrange, 10^(-6)) = 1.0 - (2.0/86400)/10^6,
        '1 microsecond should have been subtracted for both exclusive `tstzrange` bounds.';
    assert days('[2021-12-01,2021-12-02)'::tstzrange, 10^(-6)) = 1.0 - (1.0/86400)/10^6,
        '1 microsecond should be subtracted for either exclusive `tstzrange` bound.';
    assert days('(2021-12-01,2021-12-02]'::tstzrange, 10^(-6)) = 1.0 - (1.0/86400)/10^6,
        '1 microsecond should be subtracted for either exclusive `tstzrange` bound.';

    assert days('[2021-12-01,2021-12-02]'::tstzrange, 10^(-6)) = 1.0,
        'Nothing should be subtracted when both bounds are inclusive.';

    declare
        _p int;
    begin
        foreach _p in array array[0, 1, 2, 3, 4, 5, 6] loop
            assert days('[2021-12-01,2021-12-02 00:00:00)'::tstzrange, 10^(-_p)) = 1.0 - (1.0/86400)/10^_p;
            assert days('[2022-01-01,2022-01-09 12:00:00)'::tstzrange, 10^(-_p)) = 8.5 - (1.0/86400)/10^_p;
            assert days('[2022-01-01,2022-02-01 06:00:00)'::tstzrange, 10^(-_p)) = 31.25 - (1.0/86400)/10^_p;
        end loop;
    end;
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
    set pg_readme.include_this_routine_definition to true
    return upper($1) - lower($1) - 1;

comment on function days(daterange) is
$md$Get the number of days in the given `daterange`.

Given the simplicity of this function, you may (and probably should) just as
well use the `upper($1) - lower($1) - 1` expression in your code directly.

Still, it is useful to have the function here in `pg_extra_time` from a
librarian perspective, to remind us that, as stated under [_Discrete Range
Types_](https://www.postgresql.org/docs/current/rangetypes.html#RANGETYPES-DISCRETE)
in the Postgres docs:

> The built-in range type[…] `daterange` […] use[s] a canonical form that
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

“Bound-inclusivity aware” in this context means that the cast takes into
account that the `daterange` lower bound is always _inclusive_ and the
`daterange` upper bound always _exclusive_.  (Yeah, that just means subtracting
1 from the delta in days between the days; indeed see the extremely simplistic
definition of this cast's [`days(daterange)`](#function-days-daterange).
support function.)
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__daterange_to_days()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert days('[2022-06-01,2022-06-01)'::daterange) is null;
    assert days('[2022-06-01,2022-06-02)'::daterange) = 0;
    assert days('[2022-06-01,2022-06-22)'::daterange) = 20;
    assert '[2022-06-01,2022-06-22]'::daterange::text = '[2022-06-01,2022-06-23)'::daterange::text,
        '“The built-in range type[…] daterange […] use[s] a canonical form that includes the lower bound and excludes the upper bound; that is, `[)`”.';
    assert days('[2022-06-01,2022-06-22]'::daterange) = 21;

    -- Now that we tested its supporting function, we now only need to test that the cast is working at all.
    assert '[2022-06-01,2022-06-03)'::daterange::int = 1;
    assert cast('[2022-06-01,2022-06-03)'::daterange as integer) = 1;
end;
$$;

--------------------------------------------------------------------------------------------------------------
-- Functions and casts to get the number days in an `interval`.
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

If you want to convert an `interval` to (sub)seconds, use the Postgres-standard:

```
extract('epoch' from interval)
```

Or you can use the `cast(interval as float)` functionality provided by this
extension (that _uses_ the above technique, via the
[`to_float(interval)`](#function-to_float-interval) function.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__days_from_interval()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert days('0'::interval) = 0;
    assert days('1 day'::interval) = 1;
    assert days('12 hours'::interval) = 0.5;
    assert days('1 day 12 hours'::interval) = 1.5;
    assert days('3 days 6 hours'::interval) = 3.25;
    assert days('720 minutes'::interval) = 0.5;
    assert days('-1 day'::interval) = -1;
    assert days('-1 day - 23 seconds'::interval) = -1 - (23.0/86400);
    assert days('12 hours - 1 day'::interval) = -0.5;
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
    return sign(extract(epoch from $1)) * floor(abs(extract(epoch from $1) / 86400));

comment on function whole_days(interval) is
$md$Get the number of whole days (rounded down) present in a given `interval` value.

If you want to convert an `interval` to (sub)seconds, use the Postgres-standard:

```
extract('epoch' from interval)`
```

For example usage of this function, see the
[`test__whole_days_from_interval()`](#procedure-test__whole_days_from_interval)
procedure.

Please don't be clever (and overly DRY) and make this function reuse
[`days(interval)`](#function-days-interval):

1. The functions in this extensions are meant to be copy-pastable apart from
   each other independently.
2. Individual SQL functions can be inlined by the planner, but not nested
   functions.
3. These functions are way to simple to justify reuse.
4. And we have test cases.
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
    assert whole_days(interval '1 day 23 hours') = 1;
    assert whole_days(interval '1 day 24 hours') = 2;
    assert whole_days('-1 day'::interval) = -1;
    assert whole_days('-1 day -10 minutes'::interval) = -1, whole_days('-1 day 10 minutes'::interval);
    assert whole_days('-1 day -23 hours -59 minutes'::interval) = -1;
    assert whole_days('+12 hours - 1 day'::interval) = 0;
end;
$$;

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

    return floor(extract(epoch from $1) / 86400);
end;
$$;

comment on function extract_days(interval) is
$md$Deprecated function, as of `pg_extra_time` 2.0—then reincarnated as the more correct `whole_days(interval)`.

Contrary to this (_deprecated_) function,
[`whole_days(interval)`](#function-whole_days-interval) also does the right
thing with negative intervals.
$md$;

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
    assert extract_days(interval '1 day 23 hours') = 1;
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

create function date_part_parts(text, text, timestamptz, text = current_setting('timezone'))
    returns int
    returns null on null input
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    language sql
    return (
        select count(*) - 1 from generate_series(
            date_trunc($1, $3)
            ,date_trunc($1, $3) + format('1 %s', $1)::interval
            ,format('1 %s', $2)::interval
            ,$4
        )
    );

comment on function date_part_parts(text, text, timestamptz, text) is
$md$Extract the number of date parts that exist in the other given date part for the given date.

Use this function:

* if you want to know the number of days in the month for the month that the given date falls in;
* if you want to know the number of days in the year for the year that the given date falls in;
* if you need to be reminded that really _every_ year has 12 months;
* if you want to know the number of hours in a day (which is _not_ always 24);
* etc.

This function is primarily useful to avoid conditional nightmares in other
date-time-related calculations.

The names of the date parts are those supported by the standard PostgreSQL
[`date_part()`] and [`date_trunc()`] functions.

See the [`test__date_part_parts()`](#procedure-test__date_part_parts) routine
for example use of this function.

[`date_part()`]:
https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-EXTRACT

[`date_trunc()`]:
https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-TRUNC
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__date_part_parts()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
declare
    _tz constant text := 'Europe/Amsterdam';
    _dst_day constant timestamptz := ('2024-03-31 '||_tz)::timestamptz;
begin
    perform set_config('timezone', _tz, true);

    assert date_part_parts('year', 'days', make_date(2022,8,23)) = 365;
    assert date_part_parts('year', 'days', make_date(2024,8,23)) = 366;
    assert date_part_parts('year', 'months', make_date(1900,1,1)) = 12;
    assert date_part_parts('month', 'days', make_date(2024,2,12)) = 29;
    assert date_part_parts('day', 'hours', _dst_day - interval '1 day', _tz) = 24;
    assert date_part_parts('day', 'minutes', _dst_day - interval '1 day', _tz) = 24 * 60;
    assert date_part_parts('day', 'hours', _dst_day, _tz) = 23, format(
        'The day that the switch to summertime happens in %s should have only 23 hours, not %s.'
        ,_tz
        ,date_part_parts('day', 'hours', _dst_day, _tz)
    );
    assert date_part_parts('day', 'minutes', _dst_day, _tz) = 23 * 60;
    assert date_part_parts('day', 'hours', _dst_day + interval '1 day', _tz) = 24;

    reset timezone;
end;
$$;

--------------------------------------------------------------------------------------------------------------
-- `each_subperiod()` function and test procedure.
-------------------------------------------------------------------------------------------------------------

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

See the official Postgres documentation for the
[`pg_timezone_names`](https://www.postgresql.org/docs/current/view-pg-timezone-names.html)
view for the precise record structure returned by this function.
$md$;

--------------------------------------------------------------------------------------------------------------
