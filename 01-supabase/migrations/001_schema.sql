-- 001_schema.sql
-- Attic Plus site check-in — core tables
-- Run first. Migrations are NOT idempotent; run in numerical order, once.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- installers
-- ---------------------------------------------------------------------------
create table public.installers (
  id                uuid primary key default gen_random_uuid(),
  full_name         text not null,
  -- Synthetic Supabase Auth user. Installers never see or type this address.
  auth_user_id      uuid unique references auth.users(id) on delete set null,
  login_email       text unique not null,
  -- bcrypt hash of the 4-digit PIN. Never store the PIN itself.
  pin_hash          text not null,
  ghl_user_id       text,
  active            boolean not null default true,
  created_at        timestamptz not null default now()
);

comment on column public.installers.pin_hash is
  'bcrypt hash, set via crypt(pin, gen_salt(''bf'')). A 4-digit PIN is only acceptable because pin-login rate-limits to 5 attempts / 15 min.';

-- Server-only. Holds the long random password of the synthetic auth user so the
-- pin-login edge function can mint a real session after verifying the PIN.
-- No RLS policies are ever added to this table: service role only.
create table public.installer_secrets (
  installer_id      uuid primary key references public.installers(id) on delete cascade,
  auth_password     text not null
);

-- ---------------------------------------------------------------------------
-- jobs — mirror of GoHighLevel appointments
-- ---------------------------------------------------------------------------
create table public.jobs (
  id                    uuid primary key default gen_random_uuid(),
  -- 'ghl_calendar' once dispatch is live; 'manual' for preliminary testing.
  -- The app does not care which. See docs/02-architecture.md.
  source                text not null default 'ghl_calendar'
                          check (source in ('ghl_calendar', 'manual')),
  ghl_appointment_id    text unique,
  ghl_contact_id        text,
  customer_name         text,
  address               text,
  lat                   double precision,
  lng                   double precision,
  geocoded_at           timestamptz,
  scheduled_start       timestamptz,
  scheduled_end         timestamptz,
  assigned_installer_id uuid references public.installers(id) on delete set null,
  status                text not null default 'scheduled'
                          check (status in ('scheduled', 'cancelled', 'completed')),
  synced_at             timestamptz not null default now()
);

create index jobs_installer_day_idx
  on public.jobs (assigned_installer_id, scheduled_start);

-- ---------------------------------------------------------------------------
-- site_visits — one row per job visit
-- ---------------------------------------------------------------------------
create table public.site_visits (
  id                    uuid primary key default gen_random_uuid(),
  job_id                uuid not null references public.jobs(id) on delete cascade,
  installer_id          uuid not null references public.installers(id) on delete restrict,

  -- CLOCK IN. clockin_at is set by the SERVER. The client must never send it.
  clockin_at            timestamptz not null default now(),
  clockin_lat           double precision not null,
  clockin_lng           double precision not null,
  clockin_accuracy_m    double precision,
  clockin_distance_m    double precision,   -- computed by trigger, see 004
  clockin_photo_path    text not null,

  -- CLOCK OUT. Null until the installer clocks out.
  clockout_at           timestamptz,
  clockout_lat          double precision,
  clockout_lng          double precision,
  clockout_accuracy_m   double precision,
  clockout_distance_m   double precision,
  clockout_photo_path   text,

  duration_minutes      integer,            -- computed by trigger, see 004

  -- Push-back state
  ghl_record_id         text,
  ghl_synced_at         timestamptz,

  created_at            timestamptz not null default now()
);

-- One open visit per installer at a time.
create unique index site_visits_one_open_per_installer
  on public.site_visits (installer_id)
  where clockout_at is null;

create index site_visits_job_idx on public.site_visits (job_id);
create index site_visits_unsynced_idx
  on public.site_visits (ghl_synced_at)
  where ghl_synced_at is null;

-- ---------------------------------------------------------------------------
-- pin_attempts — rate limiting for pin-login
-- ---------------------------------------------------------------------------
create table public.pin_attempts (
  id            bigserial primary key,
  installer_id  uuid not null references public.installers(id) on delete cascade,
  attempted_at  timestamptz not null default now(),
  success       boolean not null
);

create index pin_attempts_window_idx
  on public.pin_attempts (installer_id, attempted_at desc);
