-- Training-sync foundation. This migration is additive and safe to re-run.
-- It intentionally does not backfill or rewrite existing workout rows.

begin;

alter table public.workout_logs
  add column if not exists program_id text,
  add column if not exists program_day_id text,
  add column if not exists program_exercise_id text,
  add column if not exists updated_at timestamptz not null default now();

do $$
declare
  id_type text;
  owner_type text;
begin
  select udt_name into id_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'workout_logs'
    and column_name = 'id';
  select udt_name into owner_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'workout_logs'
    and column_name = 'user_id';
  if id_type is distinct from 'uuid' or owner_type is distinct from 'uuid' then
    raise exception
      'FitForge training sync requires workout_logs.id and user_id to be uuid';
  end if;
end
$$;

alter table public.workout_logs
  drop constraint if exists workout_logs_program_slot_all_or_none;
alter table public.workout_logs
  add constraint workout_logs_program_slot_all_or_none check (
    (
      program_id is null
      and program_day_id is null
      and program_exercise_id is null
    )
    or
    (
      nullif(btrim(program_id), '') is not null
      and nullif(btrim(program_day_id), '') is not null
      and nullif(btrim(program_exercise_id), '') is not null
    )
  );

-- The unique owner/id pair lets child rows enforce that their workout belongs
-- to the same user. Existing globally unique workout ids satisfy this index.
create unique index if not exists workout_logs_user_id_id_uidx
  on public.workout_logs (user_id, id);

create unique index if not exists workout_logs_owner_slot_uidx
  on public.workout_logs (
    user_id,
    id,
    program_id,
    program_day_id,
    program_exercise_id
  );

create index if not exists workout_logs_program_slot_idx
  on public.workout_logs (
    user_id,
    program_id,
    program_day_id,
    program_exercise_id,
    date
  )
  where program_id is not null;

create table if not exists public.training_programs (
  user_id uuid not null references auth.users (id) on delete cascade,
  id text not null,
  document jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint training_programs_pkey primary key (user_id, id),
  constraint training_programs_id_nonempty check (nullif(btrim(id), '') is not null),
  constraint training_programs_document_identity check (
    jsonb_typeof(document) = 'object'
    and document ? 'id'
    and document ? 'userId'
    and (document ->> 'id' = id) is true
    and (document ->> 'userId' = user_id::text) is true
  )
);

create table if not exists public.progression_rules (
  user_id uuid not null references auth.users (id) on delete cascade,
  id text not null,
  document jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint progression_rules_pkey primary key (user_id, id),
  constraint progression_rules_id_nonempty check (nullif(btrim(id), '') is not null),
  constraint progression_rules_document_identity check (
    jsonb_typeof(document) = 'object'
    and document ? 'id'
    and document ? 'userId'
    and document ? 'exerciseId'
    and (document ->> 'id' = id) is true
    and (document ->> 'userId' = user_id::text) is true
    and nullif(btrim(document ->> 'exerciseId'), '') is not null
  )
);

create table if not exists public.workout_set_logs (
  user_id uuid not null references auth.users (id) on delete cascade,
  id text not null,
  workout_log_id uuid not null,
  program_id text not null,
  program_day_id text not null,
  program_exercise_id text not null,
  set_index integer not null,
  reps integer not null,
  weight_kg double precision not null,
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_set_logs_pkey primary key (user_id, id),
  constraint workout_set_logs_identity_nonempty check (
    nullif(btrim(id), '') is not null
    and nullif(btrim(program_id), '') is not null
    and nullif(btrim(program_day_id), '') is not null
    and nullif(btrim(program_exercise_id), '') is not null
  ),
  constraint workout_set_logs_workout_slot_fkey
    foreign key (
      user_id,
      workout_log_id,
      program_id,
      program_day_id,
      program_exercise_id
    )
    references public.workout_logs (
      user_id,
      id,
      program_id,
      program_day_id,
      program_exercise_id
    )
    on delete cascade,
  constraint workout_set_logs_workout_index_key
    unique (user_id, workout_log_id, set_index),
  constraint workout_set_logs_set_index_nonnegative check (set_index >= 0),
  constraint workout_set_logs_reps_nonnegative check (reps >= 0),
  constraint workout_set_logs_weight_nonnegative check (weight_kg >= 0)
);

create index if not exists training_programs_user_updated_idx
  on public.training_programs (user_id, updated_at desc);

create index if not exists progression_rules_user_updated_idx
  on public.progression_rules (user_id, updated_at desc);

create unique index if not exists progression_rules_user_exercise_uidx
  on public.progression_rules (user_id, (document ->> 'exerciseId'));

drop index if exists public.workout_set_logs_workout_idx;

create index if not exists workout_set_logs_program_slot_idx
  on public.workout_set_logs (
    user_id,
    program_id,
    program_day_id,
    program_exercise_id
  );

comment on column public.workout_logs.updated_at is
  'Server-owned synchronization metadata; clients must not submit this value.';
comment on column public.training_programs.updated_at is
  'Server-owned synchronization metadata; domain updatedAt remains in document.';
comment on column public.progression_rules.updated_at is
  'Server-owned synchronization metadata; clients must not submit this value.';
comment on column public.workout_set_logs.updated_at is
  'Server-owned synchronization metadata; clients must not submit this value.';

create or replace function public.fitforge_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists fitforge_workout_logs_updated_at
  on public.workout_logs;
create trigger fitforge_workout_logs_updated_at
before update on public.workout_logs
for each row execute function public.fitforge_set_updated_at();

drop trigger if exists fitforge_training_programs_updated_at
  on public.training_programs;
create trigger fitforge_training_programs_updated_at
before update on public.training_programs
for each row execute function public.fitforge_set_updated_at();

drop trigger if exists fitforge_progression_rules_updated_at
  on public.progression_rules;
create trigger fitforge_progression_rules_updated_at
before update on public.progression_rules
for each row execute function public.fitforge_set_updated_at();

drop trigger if exists fitforge_workout_set_logs_updated_at
  on public.workout_set_logs;
create trigger fitforge_workout_set_logs_updated_at
before update on public.workout_set_logs
for each row execute function public.fitforge_set_updated_at();

alter table public.workout_logs enable row level security;
alter table public.training_programs enable row level security;
alter table public.progression_rules enable row level security;
alter table public.workout_set_logs enable row level security;

drop policy if exists fitforge_workout_logs_owner_access
  on public.workout_logs;
drop policy if exists fitforge_workout_logs_owner_guard
  on public.workout_logs;
create policy fitforge_workout_logs_owner_access
  on public.workout_logs as permissive
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy fitforge_workout_logs_owner_guard
  on public.workout_logs as restrictive
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists training_programs_owner_all
  on public.training_programs;
drop policy if exists fitforge_training_programs_owner_access
  on public.training_programs;
drop policy if exists fitforge_training_programs_owner_guard
  on public.training_programs;
create policy fitforge_training_programs_owner_access
  on public.training_programs as permissive
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy fitforge_training_programs_owner_guard
  on public.training_programs as restrictive
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists progression_rules_owner_all
  on public.progression_rules;
drop policy if exists fitforge_progression_rules_owner_access
  on public.progression_rules;
drop policy if exists fitforge_progression_rules_owner_guard
  on public.progression_rules;
create policy fitforge_progression_rules_owner_access
  on public.progression_rules as permissive
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy fitforge_progression_rules_owner_guard
  on public.progression_rules as restrictive
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists workout_set_logs_owner_all
  on public.workout_set_logs;
drop policy if exists fitforge_workout_set_logs_owner_access
  on public.workout_set_logs;
drop policy if exists fitforge_workout_set_logs_owner_guard
  on public.workout_set_logs;
create policy fitforge_workout_set_logs_owner_access
  on public.workout_set_logs as permissive
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy fitforge_workout_set_logs_owner_guard
  on public.workout_set_logs as restrictive
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.workout_logs from anon;
revoke all on table public.training_programs from anon;
revoke all on table public.progression_rules from anon;
revoke all on table public.workout_set_logs from anon;

grant select, insert, update, delete
  on table public.workout_logs to authenticated;
grant select, insert, update, delete
  on table public.training_programs to authenticated;
grant select, insert, update, delete
  on table public.progression_rules to authenticated;
grant select, insert, update, delete
  on table public.workout_set_logs to authenticated;

commit;

-- Rollback guidance (run separately only after exporting any rows written by
-- clients using this schema):
--
-- begin;
-- drop table if exists public.workout_set_logs;
-- drop table if exists public.progression_rules;
-- drop table if exists public.training_programs;
-- drop trigger if exists fitforge_workout_logs_updated_at
--   on public.workout_logs;
-- drop index if exists public.workout_logs_program_slot_idx;
-- drop index if exists public.workout_logs_user_id_id_uidx;
-- alter table public.workout_logs
--   drop constraint if exists workout_logs_program_slot_all_or_none,
--   drop column if exists program_exercise_id,
--   drop column if exists program_day_id,
--   drop column if exists program_id,
--   drop column if exists updated_at;
-- drop function if exists public.fitforge_set_updated_at();
-- commit;
--
-- Dropping the slot columns or new tables is data-destructive. A safer app
-- rollback can leave this additive schema in place while older clients ignore
-- the new nullable columns and tables.
