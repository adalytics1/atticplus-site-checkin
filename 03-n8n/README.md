# 03 — n8n

Three workflows. Import each via **Workflows → Import from File**.

| File | Trigger | What it does |
|---|---|---|
| `01-sync-jobs-from-ghl.json` | Every 15 min | Pulls today's appointments from the GHL calendar, geocodes new addresses, upserts into Supabase `jobs` |
| `02-push-visit-to-ghl.json` | Supabase webhook | On clock-in and clock-out: writes the `site_visit` custom object record and a note on the contact |
| `03-prune-old-photos.json` | 1st of the month, 3am | Deletes photos older than 12 months |

## Environment variables

Set these in n8n (**Settings → Variables**, or your n8n Cloud environment). The workflows read them via `$env`.

| Variable | Value | Where to get it |
|---|---|---|
| `GHL_PIT` | Private Integration Token | GHL → Attic Plus sub-account → Settings → Private Integrations |
| `GHL_LOCATION_ID` | Attic Plus sub-account ID | GHL → Settings → Business Profile |
| `GHL_CALENDAR_ID` | The `Installations` calendar | See `../02-gohighlevel/calendar-setup.md` |
| `SUPABASE_URL` | `https://<project>.supabase.co` | Supabase → Project Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key | Same page. **Service role bypasses RLS — n8n only, never the app** |

> The existing **"Adalytics - SMS Lead Qualifier (GoHighLevel)"** workflow already calls the GHL API from HTTP Request nodes. These workflows follow the same pattern deliberately — same auth header shape, same node type — so there is one way of doing it in this n8n instance, not two.

## Wiring the Supabase webhook

After importing workflow 02, copy its **production webhook URL**. Then in Supabase:

**Database → Webhooks → Create a new hook**

| Setting | Value |
|---|---|
| Name | `site_visit_to_ghl` |
| Table | `public.site_visits` |
| Events | Insert, Update |
| Type | HTTP Request |
| Method | POST |
| URL | the n8n production webhook URL |

Workflow 02 handles both cases from one hook: an insert is a clock-in, an update with `clockout_at` set is a clock-out. It upserts the same GHL record rather than creating two.

## Geocoding

Addresses are geocoded with **Nominatim** (OpenStreetMap) — free, no API key. Two rules the workflow already follows and which you must not remove:

- **Max 1 request per second.** The code sleeps 1,100 ms between calls.
- **Identifying User-Agent.** Currently `AtticPlus-SiteCheckin/1.0 (info@adalytics.com.au)`.

Breaking either gets the IP blocked, which silently stops distance measurement. Results are cached by address in the `jobs` table, so a repeat address never geocodes twice.

At ~10 jobs a day this sits far inside acceptable use. If Attic Plus ever scales past a few hundred jobs a day, move to a paid geocoder — do not simply raise the rate.

## Things that will bite you

- **Cancelled appointments still come back from the GHL API.** Workflow 01 filters them; if you rewrite that filter, keep it.
- **An appointment with no assigned user is skipped**, and the reason is logged to the execution console. If a job is "missing" from an installer's app, check there first.
- **An appointment with no address syncs but cannot be measured.** `distance_from_job_m` will be null. That is a booking-habit problem, not a bug.
- **Signed photo URLs are minted for 5 years.** If the 12-month prune deletes the file, the link 404s. That is expected.
- **Sydney is on daylight saving, Queensland is not.** Workflow 01 uses `Australia/Sydney` explicitly. Do not replace it with server-local time.
