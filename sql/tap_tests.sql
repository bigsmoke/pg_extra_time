begin;

create extension pg_extra_time;

call test__extract_interval();
call test__extract_days_from_tstzrange();
call test__extract_days_from_interval();
call test__modulo__tsttzrange__interval();
call test__each_subperiod();

rollback;
