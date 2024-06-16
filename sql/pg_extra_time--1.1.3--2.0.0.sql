-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on extension pg_extra_time is
$markdown$
# `pg_extra_time` PostgreSQL extension

The `pg_extra_time` PostgreSQL extension contains some date time functions and operators that, according to the extension author, ought to be part of the PostgreSQL standard distribution.

## From `tstzrange` and `interval` to days (not seconds)

`pg_extra_time` has functions to extract the number of days (with or without
fractions) from a `tstzrange` or `interval`.  Each of these functions is also
paired to a cast to convert to either:

  - a `float` representing the number of days including the remainder, or
  - an `integer` representing the number of whole days, rounded down.


| Cast                 | Function                                                                  | Example                                                     |
| -------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `tstzrange::float`   | [`extract_days(tstzrange)`](#function-extract_days-tstzrange)             | `tstzrange('2024-06-06', '2024-06-08 06:00')::float = 3.25` |
| `tstzrange::integer` | [`extract_whole_days(tstzrange)`](#function-extract_whole_days-tstzrange) | `tstzrange('2024-06-06', '2024-06-08 18:00')::int = 3`      |
| `interval::float`    | [`extract_days(interval)`](#function-extract_days-interval)               | `'10 days 12 hours'::float = 10.5`                          |
| `interval::integer`  | [`extract_whole_days(interval)`](#function-extract_whole_days-interval)   | `'10 days 20 hours 20 minutes'::int = 10`                   |

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
older versions of MSSQL, there was also possible to directly `CAST(DATETIME AS
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

create function unix_epoch()
    returns timestamptz
    immutable
    leakproof
    parallel safe
    set pg_readme.include_this_routine_definition to true
    return '1970-01-01 00:00:00 UTC'::timestamptz;

comment on function unix_epoch() is
$md$Constant function to retrieve the Unix epoch as a `timestamptz` value.
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
$md$;

--------------------------------------------------------------------------------------------------------------

alter function extract_days(tstzrange) rename to extract_whole_days;

comment on function extract_whole_days(tstzrange) is
$md$Extract the number of whole days from a given `tstzrange` value.

Prior to `pg_extra_time` 2.0.x, this function was called `extract_days()`, but
the latter name is now occupied by a function that returns a double precision
float; see [`extract_days(tstzrange)`](#function-extract_days-tstzrange).
$md$;

--------------------------------------------------------------------------------------------------------------

comment on cast (tstzrange as integer) is
$md$Convert a `tstzrange` to an `integer` value representing the number of whole days (rounded down) from the interval between the two days.
$md$;

--------------------------------------------------------------------------------------------------------------

alter procedure test__extract_days_from_tstzrange() rename to test__extract_whole_days_from_tstzrange();

create or replace procedure test__extract_whole_days_from_tstzrange()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert extract_whole_days('[2021-12-01,2022-01-01)'::tstzrange) = 31;
    assert extract_whole_days('[2021-12-01,2022-01-01]'::tstzrange) = 32;
    assert extract_whole_days('(2021-12-01,2022-01-01)'::tstzrange) = 30;
    assert extract_whole_days('(2021-12-01,2021-12-02)'::tstzrange) = 0;
    assert extract_whole_days('[2021-12-01,2021-12-02)'::tstzrange) = 1;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create procedure test__extract_days_from_interval()
    set pg_readme.include_this_routine_definition to true
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
begin
    assert extract_whole_days(interval '1 month') = 30;
    assert extract_whole_days(interval '1 week') = 7;
    assert extract_whole_days(interval '3 month 1 week 2 days') = 99;
    assert cast(interval '2 days 10 minutes' as int) = 2;
    assert '1 day 23 hours'::interval::int = 1;

    assert cast('1 day 6 hours'::interval as float) = 1.25;
    assert extract_days('0'::interval) = 0;
    assert extract_days('1 day'::interval) = 1;
    assert extract_days('12 hours'::interval) = 0.5;
    assert extract_days('1 day 12 hours'::interval) = 1.5;
    assert extract_days('3 days 6 hours'::interval) = 3.25;
end;
$$;

--------------------------------------------------------------------------------------------------------------
