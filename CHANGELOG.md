# `pg_extra_time` changelog / release notes

All notable changes to the `pg_extra_time` PostgreSQL extension will be
documented in this changelog.

The format of this changelog is based on [Keep a
Changelog](https://keepachangelog.com/en/1.1.0/).  `pg_extra_time` adheres to
[semantic versioning](https://semver.org/spec/v2.0.0.html).

This changelog is **automatically generated** and is updated by running `make
CHANGELOG.md`.  This preamble is kept in `CHANGELOG.preamble.md` and the
remainded of the changelog below is synthesized (by `sql-to-changelog.md.sql`)
from special comments in the extension update scripts, put in the right sequence
with the help of the `pg_extension_update_paths()` functions (meaning that the
extension update script must be installed where Postgres can find them before an
up-to-date `CHANGELOG.md` file can be generated).

---

## [2.0.0] – 2025-01-18

[2.0.0]: https://github.com/bigsmoke/pg_extra_time/compare/v1.1.3…v2.0.0

- `unix_epoch()`, `mssql_epoch()`, and `nt_epoch()` functions have been
  added, mainly for documentation/reference purposes, to easily look up
  these epochs. (And then just copy-paste them, for f's sake; it's not like
  these epochs will change all of a sudden; don't be a Node.js developer,
  please.  Don't turn every little thing in a dependency!)

- The `extract_interval()` functions have been **deprecated** in favor of the
  functionally identical `to_interval()` functions, the reason being that the
  Postgres core already contains an `extract()` function with confliciting
  semantics – namely the extraction of a specific `date(time)`/`interval`
  field without converting the other fields to that same unit.

  - `to_interval(tstzrange, interval[])` replaces
    `extract_interval(tstzrange, interval[])`,
    - with much-improved documentation in its new incarnation.

  - `to_interval(tstzrange)` replaces `extract_interval(tstzrange)`, with
    its implementation simplified by only including those units that are
    actually part of `interval` its internal representation in PostgreSQL,
    - and its documentation much improved.

  - `cast(tstzrange as interval)`, naturally, is now powered by the new
    `to_interval(tstzrange)` function, rather than the deprecated
     `extract_interval(tstzrange)`.

  - `extract_interval(tstzrange, interval[])` is now an (inefficient)
    wrapper around `to_interval(tstzrange, interval[])` and produces a
    **`deprecated_feature` warning** upon invocation.

  - `extract_interval(tstzrange)` also has been reduced to a mere wrapper
     around `to_interval(tstzrange)` and produces similar
     **`deprecated_feature` warnings**.

- A whole new class of functions and casts has been added to convert
  timestamp, timestamp ranges and intervals to the number of seconds (since
  the Unix epoch, between the points in the range or in the interval,
  respectively).

  - `to_float(timestamp)` returns the number of seconds (including
     fractions) that elapsed between the Unix epoch and the given
     timestamp.
    - Its sole function is to power the new `timestamp::float` cast.

  - The `to_float(timestamptz)` function does the same, but for a
    `timestamp with time zone` input, instead of a naive `timestamp`,
    - and `cast(timestamptz as float)` is powered by this function.

  - `to_float(tsrange)` converts a datetime range to the number of seconds
     (including the fractional part) between the two points.
    - `cast(tsrange as float)` uses this function.

  - `to_float(tstzrange)` converts a non-naive datetime range to the number
     of seconds between the two points,
    - which is available via `cast(tstzrange as float)` as well.

  - `to_float(interval)` returns the number of seconds contained in the
     given interval.
    - Its sole purpose is to power `cast (interval as float)`.

- The `extract_days()` family of functions have been **deprecated** and
  succeeded by functions called `whole_days()`, with slightly
  different—more correct—semantics.
  ~
  Postgres its built-in `extract()` function has different semantics from
  what `extract_days()` meant in pre-2.0 `pg_extra_time`—a good reason to
  drop `extract_` from these functions their names.  Instead, the `whole_`
  prefix was added, to distinguish this function from its new
  [`days(tstzrange)`](#function-days-tstzrange) counterpart, that also
  returns the possibly remaining day fraction.

   - The `whole_days(tstzrange)` function, like its predecessor
     `extract_days(tstzrange)`, returns the number of whole days
     (rounded down) between the two points in the given datetime range,
     but _unlike_ its predecessor, it respects

   - `whole_days(tstzrange, float)` takes a second argument as well, to
     determine at what level of precision to interpret the inclusivity
     of the lower and upper bounds of the given `tstzrange`.

  - `extract_days(tstzrange)` now, besides its strange (but unchanged) result,
    produces a **`deprecated_feature` warning**.

  - `cast(tstzrange as integer)` has been dropped entirely.  This **backwards
    incompatible change** was made because of:
     1. the realization that the old semantics of converting to days rather
        than seconds were misguided;
     2. that the old semantics of rounding up or down a _whole_ days
        depending on the in or exclusivity of the `tstzrange` were even more
        misguided;
     3. that, when converting to seconds, whether you should round up or down,
        is ambiguous anyhow and the more ambiguous in the context of upper
        and lower bounds that may or may not be inclusive;
     4. that, when suddenly changing the semantics of the cast to seconds
        instead of days can cause downstream havoc; and
     5. that, even when deciding to continue to convert to _days_ but using
        the new `whole_days(tstzrange)` function instead of the faulty,
        now-deprecated, `extract_days(tstzrange)` function, the behaviour of
        the cast would subtly change, possibly causing even nastier, more
        difficult to detect downstream bugs; it's better to crash than it is
        to invisibly break!

  - `whole_days(interval)` functions precisely the same as its predecessor
    `extract_days(interval)`.

  - `extract_days(interval)` still produces the same return value as before,
    but now also produces a **`deprecated_feature` warning**.

  - In another **backwards incompatible** move forward, Its associated
    `cast(interval as integer)` has been dropped for pretty much the same
    reasons as `cast(tstzrange as integer)`, except that the conversion of a
    `interval::integer` was not plagued by ambiguity about inclusivity or
    exclusivity of bounds as conversions from range types were.

- Each of the new `whole_days()` functions also has a `days()` correlary that
  returns a `double precision` floating point number rather than an `integer`
  and thus:
  1. may include the fraction of a day in its return value; and
  2. may return positive or negative infinity (which is supported in Postgres
     for `float` but not `int` values).

  - `days(tstzrange)` is the `float` corollary of `whole_days(tstzrange)`,

  - and `days(tstzrange, float)` the `float` corollary of `whole_days(tstzrange, float)`.

  - `days(daterange)` returns the number of days in the given `daterange`.
    There is no distinct `whole_days(daterange)` needed, because there can
    only be whole days in a `daterange`.
    - It can be used via the `daterange::int` cast.

  - `days(interval)` is the `float` corollary of `whole_days(interval)`.

- `date_part_parts(text, text, timestmaptz)` has been replaced by a function
  with one extra argument of type `text` to pass the time zone to use when
  projecting forward from the given `timestamp with time zone` value.  The
  time zone argument defaults to the `timezone` setting for the current
  transaction, so that the new function still supports the old call
  signature.
  ~
  `date_part_parts(text, text, timestamptz, text)` **fixes** a
  number of bugs that existed in its predecessor function.  For example:
  - the number of months in a year was always zero; and
  - daylight saving times were wholly ignored.
  - `date_part_parts()` documentation has been improved.
  - The `test__date_part_parts()` procedure was extended.

- `current_timezone()` documentation has been improved.

## [1.1.3] – 2024-05-23

[1.1.3]: https://github.com/bigsmoke/pg_extra_time/compare/v1.1.2…v1.1.3

- Improved documentation of `each_subperiod(tstzrange, interval, int)`
  function.

## [1.1.2] – 2023-12-21

[1.1.2]: https://github.com/bigsmoke/pg_extra_time/compare/v1.1.1…v1.1.2

- Deal better with negative intervals in the `modulo(interval, interval)`
  function and it's associated `interval % interval` operator.
- Improved explanation of signedness behavior of said `modulo(interval,
  interval)` function.
- Add tests for negative intervals.

## [1.1.1] – 2023-11-28

[1.1.1]: https://github.com/bigsmoke/pg_extra_time/compare/v1.1.0…v1.1.1

- Rather than redefining it, the `Makefile` now respects the `PG_CONFIG`
  environment variable when set.

## [1.1.0] – 2023-11-04

[1.1.0]: https://github.com/bigsmoke/pg_extra_time/compare/v1.0.0…v1.1.0

- Got rid of installation time `search_path` settings bound to routines,
  because the `pg_extra_time` extension is marked as `relocatable` and
  should make no assumptions about where objects are located.
- The new `modulo(interval, interval)` function returns the remainder of the
  first given interval after dividing it into as many of the intervals given
  in the second argument as possible.
- In addition, the new `interval % interval` (modulo) operator allows
  intuitive usage of that new `modulo(interval, interval)` function.

## [1.0.0] – 2023-09-28

[1.0.0]: https://github.com/bigsmoke/pg_extra_time/compare/v0.7.1…v1.0.0

Version 1.0.0—the first official stable release of `pg_extra_time`—didn't
entail any functional changes, just a commitment, following the [semantic
versioning](https://semver.org/) semantics, to henceforth increment the
major version number in the case of any changes that break backward
compatibility for users of this extension.

## [0.7.1] – 2023-05-12

[0.7.1]: https://github.com/bigsmoke/pg_extra_time/compare/v0.7.0…v0.7.1

- Extended author section in `README.md`.
- Add `WITH CASCADE` option to `CREATE EXTENSION` statement when temporarily
  installing `pg_readme` extension during `README.md` generation.

## [0.7.0] – 2023-02-26

[0.7.0]: https://github.com/bigsmoke/pg_extra_time/compare/v0.6.0…v0.7.0

- The new `make_tstzrange()` function constructs a `tstzrange` value
  spanning from the given `timestamp with time zone` until that time plus
  the given `interval`.
- Similarly, the new `make_tsrange()` function can be used to construct
  a `tsrange` spanning from a given `timestamp without time zone`
  instead of a naive `timestamp`.

## [0.6.0] – 2023-02-20

[0.6.0]: https://github.com/bigsmoke/pg_extra_time/compare/v0.5.0…v0.6.0

- The new `each_subperiod()` function divides a given `tstzrange` into given
  `interval`-sized chunks, with the remainder either rounded up down or
  discarded (depending on the third argument, which defaults to cutting the
  remainder off).

## [0.5.0] – 2023-02-14

[0.5.0]: https://github.com/bigsmoke/pg_extra_time/compare/v0.4.0…v0.5.0

- `current_timezone()` is a new convenience function that returns the record
  from Postgres its [`pg_catalog.pg_timezone_names`] system view that matches
  the name from the session (or transaction) its current time zone.

[`pg_catalog.pg_timezone_names`]:
https://www.postgresql.org/docs/current/view-pg-timezone-names.html
