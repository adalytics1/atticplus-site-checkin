-- 002_rls.sql
-- Row-level security. An installer can only ever see their own jobs and visits.

-- ---------------------------------------------------------------------------
-- Helper: map the logged-in auth user to an installer row
-- ---------------------------------------------------------------------------
create or replace function public.current_installer_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.installers where auth_user_id = auth.uid() and active;
$$;

-- ---------------------------------------------------------------------------
-- installers
-- ---------------------------------------------------------------------------
alter table public.installers enable row level security;

create policy installers_select_self
  on public.installers for select
  to authenticated
  using (auth_user_id = auth.uid());

-- The login screen needs a list of names BEFORE anyone is authenticated.
-- Expose id + full_name only — never pin_hash, login_email, or auth_user_id.
create view public.installer_directory
with (security_invoker = off) as
  select id, full_name
  from public.installers
  where active
  order by full_name;

grant select on public.installer_directory to anon, authenticated;

-- ---------------------------------------------------------------------------
-- installer_secrets — service role only. No policies, RLS on, nothing granted.
-- ---------------------------------------------------------------------------
alter table public.installer_secrets enable row level security;
revoke all on public.installer_secrets from anon, authenticated;

-- ---------------------------------------------------------------------------
-- jobs
-- ---------------------------------------------------------------------------
alter table public.jobs enable row level security;

create policy jobs_select_own
  on public.jobs for select
  to authenticated
  using (assigned_installer_id = public.current_installer_id());

-- Jobs are written by n8n using the service role, which bypasses RLS.
-- Installers never insert or update jobs.

-- ---------------------------------------------------------------------------
-- site_visits
-- ---------------------------------------------------------------------------
alter table public.site_visits enable row level security;

create policy site_visits_select_own
  on public.site_visits for select
  to authenticated
  using (installer_id = public.current_installer_id());

create policy site_visits_insert_own
  on public.site_visits for insert
  to authenticated
  with check (
    installer_id = public.current_installer_id()
    and job_id in (
      select id from public.jobs
      where assigned_installer_id = public.current_installer_id()
    )
  );

-- An installer may only close their OWN open visit, and may not reopen a
-- closed one or rewrite clock-in data.
create policy site_visits_update_own_open
  on public.site_visits for update
  to authenticated
  using (
    installer_id = public.current_installer_id()
    and clockout_at is null
  )
  with check (installer_id = public.current_installer_id());

-- No delete policy anywhere: visits are a record, not a draft.

-- ---------------------------------------------------------------------------
-- pin_attempts — service role only (the edge function writes these)
-- ---------------------------------------------------------------------------
alter table public.pin_attempts enable row level security;
revoke all on public.pin_attempts from anon, authenticated;
