-- manual_test_jobs.sql
-- Seed a couple of jobs by hand so the app can be tested before the
-- GoHighLevel calendar sync is running. source = 'manual'.
--
-- Replace the installer name and the addresses with real ones.

insert into public.jobs
  (source, customer_name, address, lat, lng, geocoded_at,
   scheduled_start, scheduled_end, assigned_installer_id)
select
  'manual',
  'Test Customer — Chatswood',
  '1 Victoria Ave, Chatswood NSW 2067',
  -33.7969, 151.1803, now(),
  date_trunc('day', now()) + interval '8 hours',
  date_trunc('day', now()) + interval '12 hours',
  i.id
from public.installers i
where i.full_name = 'Jake Thompson';

insert into public.jobs
  (source, customer_name, address, lat, lng, geocoded_at,
   scheduled_start, scheduled_end, assigned_installer_id)
select
  'manual',
  'Test Customer — Parramatta',
  '12 Macquarie St, Parramatta NSW 2150',
  -33.8148, 151.0017, now(),
  date_trunc('day', now()) + interval '13 hours',
  date_trunc('day', now()) + interval '16 hours',
  i.id
from public.installers i
where i.full_name = 'Jake Thompson';
