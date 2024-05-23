-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

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
