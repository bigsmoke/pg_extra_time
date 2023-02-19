-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_extra_time" to load this file. \quit

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
