# Project brief

**Client:** Attic Plus (Nuspace Sydney Pty Ltd) — director Terry Matthews
**Built by:** Adalytics
**Last updated:** 13 September 2026

## What we're building

A phone-based clock-in / clock-out card for Attic Plus installers. The installer arrives at a booked job, opens a web app on their phone, and taps **Clock in** — the app takes a live selfie and simultaneously records their GPS location and the server's timestamp. When the job is finished they tap **Clock out**, which captures a photo of the completed work. Both records are written back into Attic Plus's GoHighLevel account, against the customer, so the office can see who was on site, when they arrived, when they left, how long the job took, and photographic proof of both.

**Three things from two taps:** attendance proof, a timesheet, and completed-work documentation.

## Confirmed decisions

| Question | Decision |
|---|---|
| What counts as "a job"? | A **booked calendar appointment** in GoHighLevel |
| Employees or subcontractors? | **Employees** — triggers the NSW notice obligation, see `04-compliance-nsw.md` |
| Selfie or photo of the work? | **Both, at different moments.** Clock-in = selfie (proves the person is there). Clock-out = completed job (proves the work) |
| How do installers log in? | **4-digit PIN** per installer. No work email required |
| App address | `crew.atticplus.com.au` |
| Exception alerts? | **Not in scope for v1.** (Meaning: auto-notifying the office when someone clocks in far from the job, or hasn't clocked in by a set time. Easy to add later) |
| Team size | Under 10 installers, mixed iPhone and Android |
| Budget | Zero ongoing cost to the client |

## What the installer actually does

1. Opens the app from their home screen. Picks their name, taps their 4-digit PIN.
2. Sees **only their own appointments for today**, pulled from the GoHighLevel calendar.
3. Taps the job → **Clock in** → camera opens (front-facing) → takes a selfie → uploads.
4. Does the job.
5. Taps **Clock out** → camera opens (rear-facing) → photographs the finished work → uploads.

If location permission is denied, the button will not submit and the app explains why in plain language.

## Running cost

| Component | Plan | Cost to client |
|---|---|---|
| Lovable (build + hosting) | Existing Adalytics Pro plan | $0 |
| Supabase (database, storage, auth) | Free tier | $0 |
| n8n (automation) | Existing Adalytics n8n Cloud | $0 |
| GoHighLevel custom object | Included on all tiers | $0 |
| Geocoding | Nominatim (OpenStreetMap), free | $0 |
| Maps | Plain Google Maps links, no API key | $0 |
| **Total ongoing** | | **$0 / month** |

**Storage headroom:** 10 staff x 2 photos/day at ~250 KB compressed is roughly 1.2 GB a year against Supabase's 1 GB free allowance. Migration `004` therefore includes a job that deletes photos older than twelve months. If Attic Plus later wants longer retention, paid Supabase is US$25/month — the only cost lever that ever moves.

**For comparison:** Connecteam or Timero run roughly $10-30 per user per month. Ten installers is $1,200-3,600 a year, forever, with no link into GoHighLevel.

## Out of scope for v1

- Exception alerts (client declined)
- Payroll export
- Customer-facing booking
- Offline capture with deferred upload — the app requires a connection at the moment of capture
- Multi-tenant / reselling this to other clients (see `docs/02-architecture.md` for what would need to change)
