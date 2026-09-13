# 01 — Supabase

The database, storage, auth and row-level security for the whole system.

## Run order

```
migrations/001_schema.sql              tables
migrations/002_rls.sql                 row-level security + installer_directory view
migrations/003_storage.sql             site-photos bucket + policies
migrations/004_functions_and_triggers.sql   distance, duration, immutability guards
migrations/005_auth_functions.sql      PIN verification + rate limiting
```

Migrations are **not idempotent**. Run each once, in order. If one fails partway, fix it and re-run only the failed statements — do not re-run the whole file.

Then:

```bash
# 1. Create the installers (edit the list inside the file first)
export SUPABASE_URL="https://<project>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<service role key>"
node seed/seed_installers.mjs

# 2. Deploy the PIN login function
supabase functions deploy pin-login --no-verify-jwt

# 3. Optional — seed test jobs so the app works before GHL sync is live
psql < seed/manual_test_jobs.sql
```

## How PIN login works

Supabase Auth has no PIN concept, so:

1. Each installer gets a **synthetic auth user** — `jake.thompson@crew.atticplus.com.au` — with a 32-byte random password they never see. The password lives in `installer_secrets`, which is service-role only.
2. The login screen reads `installer_directory` (a view exposing **only** id and name) to show the name picker. This is the one thing an unauthenticated visitor can read.
3. The installer taps their name and PIN. The app calls the `pin-login` edge function.
4. The function rate-limits, verifies the bcrypt hash, then signs in as the synthetic user and returns a real session.

**The rate limit is load-bearing.** 5 failed attempts per installer per 15 minutes. A 4-digit PIN is 10,000 combinations — without the limit this is not authentication, it is decoration. Do not remove it.

## The things that cannot be faked

| Field | Set by | Why it matters |
|---|---|---|
| `clockin_at` / `clockout_at` | Postgres `now()`, forced by trigger | The phone's clock can be changed; the server's cannot. The client may send a timestamp — it is overwritten. |
| `clockin_distance_m` | Trigger, from the job's cached coordinates | Computed server-side from the job address, not supplied by the app |
| `duration_minutes` | Trigger on clock-out | Derived, never submitted |

`site_visits_guard_trg` additionally refuses any update that would change clock-in data, reassign the job, or reopen a closed visit.

## What is deliberately absent

- **No delete policy on `site_visits`** — a visit is a record, not a draft.
- **No update or delete policy on storage objects** — an installer cannot replace or remove a photo after upload.
- **No RLS policy at all on `installer_secrets` or `pin_attempts`** — service role only.

## Changing someone's PIN

```sql
select public.set_installer_pin('<installer uuid>', '4821');
```

## Storage paths

```
site-photos/{installer_id}/{visit_id}/clockin.jpg
site-photos/{installer_id}/{visit_id}/clockout.jpg
```

The bucket is private. n8n mints long-lived signed URLs when pushing to GoHighLevel, so Terry can click through from a contact record.
