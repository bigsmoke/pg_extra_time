---
pg_extension_name: pg_extra_time
pg_extension_version: 1.1.3
pg_readme_generated_at: 2024-05-23 09:38:10.785396+00
pg_readme_version: 0.6.6
---

# `pg_extra_time` PostgreSQL extension

The `pg_extra_time` PostgreSQL extension contains some date time functions and operators that, according to the extension author, ought to be part of the PostgreSQL standard distribution.

## Object reference

### Routines

#### Function: `current_timezone()`

Returns a `pg_timezone_names` record with the currently active timezone.

Function return type: `pg_timezone_names`

Function attributes: `STABLE`, `PARALLEL SAFE`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE FUNCTION public.current_timezone()
 RETURNS pg_timezone_names
 LANGUAGE sql
 STABLE PARALLEL SAFE
 SET "pg_readme.include_this_routine_definition" TO 'true'
RETURN (SELECT ROW(pg_timezone_names.name, pg_timezone_names.abbrev, pg_timezone_names.utc_offset, pg_timezone_names.is_dst)::pg_timezone_names AS "row" FROM pg_timezone_names WHERE (pg_timezone_names.name = current_setting('timezone'::text)))
```

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

```sql
CREATE OR REPLACE FUNCTION public.date_part_parts(text, text, timestamp with time zone)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE STRICT LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
RETURN date_part($2, ((date_trunc($1, $3) + (format('1 %s'::text, $1))::interval) - date_trunc($1, $3)))
```

#### Function: `each_subperiod (tstzrange, interval, integer)`

Divide the given `dividend$` into `divisor$`-sized chunks.

The remainder is rounded:

- up, to a complete `divisor$`, if `round_remainder$ >= 1`;
- down, discarding the remainder, if `round_remainder$ <= -1`; or
- not at all and kept as the remainder, if `round_remainder = 0`.

See the [`test__each_subperiod`](#procedure-test__each_subperiod) routine for
examples.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `dividend$`                                                       | `tstzrange`                                                          |  |
|   `$2` |       `IN` | `divisor$`                                                        | `interval`                                                           |  |
|   `$3` |       `IN` | `round_remainder$`                                                | `integer`                                                            | `0` |
|   `$4` |    `TABLE` | `quotient`                                                        | `tstzrange`                                                          |  |

Function return type: `TABLE(quotient tstzrange)`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `PARALLEL SAFE`, ROWS 1000

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

```sql
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

```sql
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

#### Function: `make_tsrange (timestamp without time zone, interval, text)`

Build a `tsrange` from a given timestamp from or until the given interval.

This function will do the right thing when confronted with negative intervals.

The function name is chosen for consistency with (some of) PostgreSQL built-in
date/time functions.  I would have preferred to call it plainly `tsrange()`,
but that would require users of this extensions to have to become explicit when
calling the existing `tsrange(text)` constructor while relying on an explicit
cast of `unknown` to `text`.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `timestamp without time zone`                                        |  |
|   `$2` |       `IN` |                                                                   | `interval`                                                           |  |
|   `$3` |       `IN` |                                                                   | `text`                                                               | `'[)'::text` |

Function return type: `tsrange`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

#### Function: `make_tstzrange (timestamp with time zone, interval, text)`

Build a `tstzrange` from a given timestamp from or until the given interval.

This function will do the right thing when confronted with negative intervals.

The function name is chosen for consistency with (some of) PostgreSQL built-in
date/time functions.  I would have preferred to call it plainly `tstzrange()`,
but that would require users of this extensions to have to become explicit when
calling the existing `tsrange(text)` constructor while relying on an explicit
cast of `unknown` to `text`.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `timestamp with time zone`                                           |  |
|   `$2` |       `IN` |                                                                   | `interval`                                                           |  |
|   `$3` |       `IN` |                                                                   | `text`                                                               | `'[)'::text` |

Function return type: `tstzrange`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

#### Function: `modulo (interval, interval)`

As one would expect from a modulo operator, this function returns the remainder of the first given interval after dividing it into as many of the intervals given in the second argument as possible.

This function ignores the sign of the second argument.  The sign of the first
argument is preserved.  To take the absolute (intermediate) value of both
arguments, `greatest(interval, -interval)` is used.  According to some, this
[_might_](https://www.postgresql.org/message-id/flat/5ccd53c10910270727m5bf6d4adoa9424f49a397ca5e%40mail.gmail.com)
be a too simplistic approach, but the extension author (Rowan) is of the
opinion that that's okay in this context.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `interval`                                                           |  |
|   `$2` |       `IN` |                                                                   | `interval`                                                           |  |

Function return type: `interval`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `PARALLEL SAFE`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE FUNCTION public.modulo(interval, interval)
 RETURNS interval
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE LEAKPROOF
 SET "pg_readme.include_this_routine_definition" TO 'true'
RETURN ((sign(EXTRACT(epoch FROM $1)))::double precision * ((to_timestamp((0)::double precision) + GREATEST($1, (- $1))) - date_bin(GREATEST($2, (- $2)), (to_timestamp((0)::double precision) + GREATEST($1, (- $1))), to_timestamp((0)::double precision))))
```

#### Function: `modulo (tstzrange, interval)`

As you would expect from a modulo operator, this function returns the remainder of the given datetime range after dividing it in as many of the given whole intervals as possible.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `tstzrange`                                                          |  |
|   `$2` |       `IN` |                                                                   | `interval`                                                           |  |

Function return type: `interval`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `PARALLEL SAFE`

Function-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
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

#### Function: `pg_extra_time_meta_pgxn()`

Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

`pg_extra_time` can indeed be found on PGXN: https://pgxn.org/dist/pg_readme/

Function return type: `jsonb`

Function attributes: `STABLE`

#### Function: `pg_extra_time_readme()`

Fire up the `pg_readme` extension to generate a thorough README for this extension, based on the `pg_catalog` and the `COMMENT` objects found therein.

Function return type: `text`

Function-local settings:

  *  `SET pg_readme.include_view_definitions TO true`
  *  `SET pg_readme.include_routine_definitions_like TO {test__%}`
  *  `SET pg_readme.readme_url TO https://github.com/bigsmoke/pg_extra_time/blob/master/README.md`

#### Procedure: `test__date_part_parts()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```sql
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

#### Procedure: `test__each_subperiod()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE public.test__each_subperiod()
 LANGUAGE plpgsql
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__extract_days_from_interval()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```sql
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

#### Procedure: `test__extract_days_from_tstzrange()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```sql
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

#### Procedure: `test__extract_interval()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```sql
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

#### Procedure: `test__make_tsrange()`

Procedure-local settings:

  *  `SET plpgsql.check_asserts TO true`
  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE public.test__make_tsrange()
 LANGUAGE plpgsql
 SET "plpgsql.check_asserts" TO 'true'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__make_tstzrange()`

Procedure-local settings:

  *  `SET plpgsql.check_asserts TO true`
  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE public.test__make_tstzrange()
 LANGUAGE plpgsql
 SET "plpgsql.check_asserts" TO 'true'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__modulo__interval__interval()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```sql
CREATE OR REPLACE PROCEDURE public.test__modulo__interval__interval()
 LANGUAGE plpgsql
 SET "pg_readme.include_this_routine_definition" TO 'true'
 SET "plpgsql.check_asserts" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__modulo__tsttzrange__interval()`

Procedure-local settings:

  *  `SET pg_readme.include_this_routine_definition TO true`
  *  `SET plpgsql.check_asserts TO true`

```sql
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

## Colophon

This `README.md` for the `pg_extra_time` extension was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.
