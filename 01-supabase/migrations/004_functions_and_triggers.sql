-- 004_functions_and_triggers.sql
-- Distance, duration, immutability guards, and the retention query.

-- ---------------------------------------------------------------------------
-- Haversine distance in metres. No PostGIS needed at this scale.
-- ---------------------------------------------------------------------------
create or replace function public.distance_m(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371000 * 2 * asin(sqrt(
      power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2))
    * power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;

-- ---------------------------------------------------------------------------
-- Fill distance from the job's cached coordinates, and duration on clock-out.
-- ---------------------------------------------------------------------------
create or replace function public.site_visits_compute()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  j_lat double precision;
  j_lng double precision;
begin
  select lat, lng into j_lat, j_lng from public.jobs where id = new.job_id;

  if j_lat is not null and j_lng is not null then
    if new.clockin_lat is not null then
      new.clockin_distance_m :=
        public.distance_m(new.clockin_lat, new.clockin_lng, j_lat, j_lng);
    end if;
    if new.clockout_lat is not null then
      new.clockout_distance_m :=
        public.distance_m(new.clockout_lat, new.clockout_lng, j_lat, j_lng);
    end if;
  end if;

  if new.clockout_at is not null and new.clockin_at is not null then
    new.duration_minutes :=
      round(extract(epoch from (new.clockout_at - new.clockin_at)) / 60)::int;
  end if;

  return new;
end;
$$;

create trigger site_visits_compute_trg
  before insert or update on public.site_visits
  for each row execute function public.site_visits_compute();

-- ---------------------------------------------------------------------------
-- Immutability guard.
-- The client supplies coordinates and photo paths but NEVER a timestamp, and
-- must not be able to rewrite a clock-in after the fact. RLS alone cannot
-- express "these specific columns are frozen", so enforce it here.
-- ---------------------------------------------------------------------------
create or replace function public.site_visits_guard()
returns trigger
language plpgsql
as $$
begin
  if new.clockin_at        is distinct from old.clockin_at
  or new.clockin_lat       is distinct from old.clockin_lat
  or new.clockin_lng       is distinct from old.clockin_lng
  or new.clockin_photo_path is distinct from old.clockin_photo_path
  or new.job_id            is distinct from old.job_id
  or new.installer_id      is distinct from old.installer_id then
    raise exception 'Clock-in data is immutable once recorded';
  end if;

  if old.clockout_at is not null then
    raise exception 'This visit is already closed';
  end if;

  -- Clock-out time is the server's, never the client's.
  if new.clockout_at is not null then
    new.clockout_at := now();
  end if;

  return new;
end;
$$;

create trigger site_visits_guard_trg
  before update on public.site_visits
  for each row execute function public.site_visits_guard();

-- Clock-in time is the server's too. Overwrite whatever the client sent.
create or replace function public.site_visits_server_clock()
returns trigger
language plpgsql
as $$
begin
  new.clockin_at := now();
  new.clockout_at := null;
  return new;
end;
$$;

create trigger site_visits_server_clock_trg
  before insert on public.site_visits
  for each row execute function public.site_visits_server_clock();

-- ---------------------------------------------------------------------------
-- Retention: photos older than 12 months.
-- n8n reads this view monthly, deletes the objects via the storage API, then
-- nulls the paths. See 03-n8n/workflows/03-prune-old-photos.json.
-- ---------------------------------------------------------------------------
create or replace view public.expired_photos as
  select
    id as visit_id,
    installer_id,
    clockin_photo_path,
    clockout_photo_path
  from public.site_visits
  where clockin_at < now() - interval '12 months'
    and (clockin_photo_path is not null or clockout_photo_path is not null);

revoke all on public.expired_photos from anon, authenticated;
