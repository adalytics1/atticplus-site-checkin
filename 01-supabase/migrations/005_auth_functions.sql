-- 005_auth_functions.sql
-- Server-side helpers for PIN login. Called only by the pin-login edge
-- function with the service role key — never exposed to anon or authenticated.

-- ---------------------------------------------------------------------------
-- Verify a PIN against the stored bcrypt hash.
-- ---------------------------------------------------------------------------
create or replace function public.verify_pin(p_installer_id uuid, p_pin text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from public.installers
    where id = p_installer_id
      and active
      and pin_hash = crypt(p_pin, pin_hash)
  );
$$;

-- ---------------------------------------------------------------------------
-- Rate limit: 5 failed attempts per installer per 15 minutes.
-- Returns true if the installer is currently locked out.
-- ---------------------------------------------------------------------------
create or replace function public.pin_locked_out(p_installer_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select count(*) >= 5
  from public.pin_attempts
  where installer_id = p_installer_id
    and success = false
    and attempted_at > now() - interval '15 minutes';
$$;

create or replace function public.log_pin_attempt(p_installer_id uuid, p_success boolean)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.pin_attempts (installer_id, success)
  values (p_installer_id, p_success);
$$;

-- ---------------------------------------------------------------------------
-- Set or change an installer's PIN. Admin use only.
-- ---------------------------------------------------------------------------
create or replace function public.set_installer_pin(p_installer_id uuid, p_pin text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if p_pin !~ '^[0-9]{4}$' then
    raise exception 'PIN must be exactly 4 digits';
  end if;
  update public.installers
     set pin_hash = crypt(p_pin, gen_salt('bf'))
   where id = p_installer_id;
end;
$$;

revoke execute on function public.verify_pin(uuid, text)        from anon, authenticated;
revoke execute on function public.pin_locked_out(uuid)          from anon, authenticated;
revoke execute on function public.log_pin_attempt(uuid, boolean) from anon, authenticated;
revoke execute on function public.set_installer_pin(uuid, text) from anon, authenticated;

-- ---------------------------------------------------------------------------
-- server_now — lets the app stamp the photo with the same clock Postgres will
-- record, instead of the phone's. The authoritative value is still the
-- column default; this is only so the burned-in text matches.
-- ---------------------------------------------------------------------------
create or replace function public.server_now()
returns timestamptz
language sql
stable
as $$ select now(); $$;

grant execute on function public.server_now() to anon, authenticated;
