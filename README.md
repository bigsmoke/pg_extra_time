---
pg_extension_name: pg_extra_time
pg_extension_version: 0.4.0
pg_readme_generated_at: 2023-01-18 09:34:50.236633+00
pg_readme_version: 0.4.0
---

# `pg_extra_time` PostgreSQL extension

The `pg_extra_time` PostgreSQL extension contains some date time functions and operators that, according to the extension author, ought to be part of the PostgreSQL standard distribution.

## Object reference

### Routines

#### Function: `date_part_parts (text, text, timestamp with time zone)`

Extract the number of date parts that exist in the other given date part for the given date.

Use this function:

* if you want to know the number of days in the month for the month that the given date falls in;
* if you want to know the number of days in the year for the year that the given date falls in;
* if you need to be reminded that really _every_ year has 12 months;
* etc.

Of course, this function is mostly useful to avoid conditional nightmares in other date-time-related calculations.

The names of the date parts follow those of the standard PostgreSQL [`date_part()`](https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-EXTRACT) and [`date_trunc()`](https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-TRUNC) functions.

See the `test__date_part_parts()` routine for examples.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `text`                                                               |  |
|   `$2` |       `IN` |                                                                   | `text`                                                               |  |
|   `$3` |       `IN` |                                                                   | `timestamp with time zone`                                           |  |

Function return type: `integer`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`

```
CREATE OR REPLACE FUNCTION public.date_part_parts(text, text, timestamp with time zone)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE STRICT LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
RETURN date_part($2, ((date_trunc($1, $3) + (format('1 %s'::text, $1))::interval) - date_trunc($1, $3)))
```

#### Function: `extract_days (interval)`

Extract the number of whole days (rounded down) from a given `interval` value.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `interval`                                                           |  |

Function return type: `integer`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`

```
CREATE OR REPLACE FUNCTION public.extract_days(interval)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE STRICT LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
RETURN floor((EXTRACT(epoch FROM $1) / (86400)::numeric))
```

#### Function: `extract_days (tstzrange)`

Extract the number of whole days from a given `tstzrange` value.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `tstzrange`                                                          |  |

Function return type: `integer`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

#### Function: `extract_interval (tstzrange)`

Extract an interval from a datetime range, starting with the largest interval unit possible, and down to the microsecond.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `tstzrange`                                                          |  |

Function return type: `interval`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`

```
CREATE OR REPLACE FUNCTION public.extract_interval(tstzrange)
 RETURNS interval
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE STRICT LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
RETURN extract_interval($1, ARRAY['1 year'::interval, '1 mon'::interval, '1 day'::interval, '01:00:00'::interval, '00:01:00'::interval, '00:00:01'::interval, '00:00:00.001'::interval, '00:00:00.000001'::interval])
```

#### Function: `extract_interval (tstzrange, interval[])`

Extract all the rounded intervals given in the second argument from the datetime range in the first argument.

The function starts with as many of the biggest units given as fit in the datetime range, then tries the next-biggest unit with the remainder, etc.

See the `test__extract_interval()` procedure for examples.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `tstzrange`                                                          |  |
|   `$2` |       `IN` |                                                                   | `interval[]`                                                         |  |

Function return type: `interval`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

#### Function: `modulo (tstzrange, interval)`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `tstzrange`                                                          |  |
|   `$2` |       `IN` |                                                                   | `interval`                                                           |  |

Function return type: `interval`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `PARALLEL SAFE`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`

```
CREATE OR REPLACE FUNCTION public.modulo(tstzrange, interval)
 RETURNS interval
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $function$
select
    upper($1) - max(i)
from
    generate_series(lower($1), upper($1), $2) as i
;
$function$
```

#### Function: `pg_extra_time_meta_pgxn ()`

Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to refresh the meta file with the function's current output, including the `default_version`.

`pg_extra_time` can indeed be found on PGXN: https://pgxn.org/dist/pg_readme/

Function return type: `jsonb`

Function attributes: `STABLE`

Function-local settings:

  *  `SET search_path TO public, pg_temp`

#### Function: `pg_extra_time_readme ()`

Fire up the `pg_readme` extension to generate a thorough README for this extension, based on the `pg_catalog` and the `COMMENT` objects found therein.

Function return type: `text`

Function-local settings:

  *  `SET search_path TO public, pg_temp`
  *  `SET pg_readme.include_view_definitions TO true`
  *  `SET pg_readme.include_routine_definitions_like TO {test__%}`
  *  `SET pg_readme.readme_url TO https://github.com/bigsmoke/pg_extra_time/blob/master/README.md`

#### Procedure: `test__date_part_parts ()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```
CREATE OR REPLACE PROCEDURE public.test__date_part_parts()
 LANGUAGE plpgsql
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET "plpgsql.check_asserts" TO 'true'
AS $procedure$
begin
    assert date_part_parts('year', 'days', make_date(2022,8,23)) = 365;
    assert date_part_parts('year', 'days', make_date(2024,8,23)) = 366;
    assert date_part_parts('month', 'days', make_date(2024,2,12)) = 29;
end;
$procedure$
```

#### Procedure: `test__extract_days_from_interval ()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```
CREATE OR REPLACE PROCEDURE public.test__extract_days_from_interval()
 LANGUAGE plpgsql
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET "plpgsql.check_asserts" TO 'true'
AS $procedure$
begin
    assert extract_days(interval '1 month') = 30;
    assert extract_days(interval '1 week') = 7;
    assert extract_days(interval '3 month 1 week 2 days') = 99;
end;
$procedure$
```

#### Procedure: `test__extract_days_from_tstzrange ()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```
CREATE OR REPLACE PROCEDURE public.test__extract_days_from_tstzrange()
 LANGUAGE plpgsql
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET "plpgsql.check_asserts" TO 'true'
AS $procedure$
begin
    assert extract_days('[2021-12-01,2022-01-01)'::tstzrange) = 31;
    assert extract_days('[2021-12-01,2022-01-01]'::tstzrange) = 32;
    assert extract_days('(2021-12-01,2022-01-01)'::tstzrange) = 30;
    assert extract_days('(2021-12-01,2021-12-02)'::tstzrange) = 0;
    assert extract_days('[2021-12-01,2021-12-02)'::tstzrange) = 1;
end;
$procedure$
```

#### Procedure: `test__extract_interval ()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```
CREATE OR REPLACE PROCEDURE public.test__extract_interval()
 LANGUAGE plpgsql
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET "plpgsql.check_asserts" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__modulo__tsttzrange__interval ()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```
CREATE OR REPLACE PROCEDURE public.test__modulo__tsttzrange__interval()
 LANGUAGE plpgsql
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET "plpgsql.check_asserts" TO 'true'
AS $procedure$
begin
    assert (tstzrange(make_date(2022,7,1), make_date(2022,8,2)) % interval '1 month') = interval '1 day';
end;
$procedure$
```

## Extension origins

`pg_extra_time` was developed to simplify quite a bit of code in the PostgreSQL backend of the [FlashMQ MQTT hosting platform](https://www.flashmq.com/), especially for financial calculations regarding subscription durations, etc..  Datetime calculations are notoriously easy to get wrong, and therefore better to isolate and test well rather than mix into the business logic on an ad hoc basis.

## Extension author(s)

* Rowan Rodrik van der Molen
  - [@ysosuckysoft](https://twitter.com/ysosuckysoft)

## Colophon

This `README.md` for the `pg_extra_time` `extension` was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.
