# Architecture

```
Installer's phone                Storage              Glue                 Client's view
┌──────────────────┐      ┌─────────────────┐   ┌──────────────┐   ┌──────────────────┐
│  Lovable web app │  ──► │    Supabase     │──►│     n8n      │──►│  GoHighLevel     │
│                  │      │                 │   │              │   │                  │
│ · live camera    │      │ · photo storage │   │ · distance   │   │ · site_visit     │
│ · geolocation    │      │ · server clock  │   │   from job   │   │   custom object  │
│ · PIN login      │      │ · PIN auth fn   │   │ · formatting │   │ · note on the    │
│ · home-screen    │      │ · RLS           │   │ · writes to  │   │   contact        │
│   PWA            │      │                 │   │   GHL API    │   │                  │
└──────────────────┘      └─────────────────┘   └──────────────┘   └──────────────────┘
         ▲                         ▲                    │
         │                         └────────────────────┘
         │                    jobs synced from GHL calendar every 15 min
         └── crew.atticplus.com.au
```

## Why each piece

**Lovable** — builds the phone app. Already on the Adalytics Pro plan. Installs to the home screen as a PWA, so no App Store submission and no iOS/Android split to maintain.

**Supabase** — free tier. Holds photos, coordinates, and crucially the *server-side* timestamp. Also handles PIN login via an edge function. Row-level security means an installer can only ever see their own jobs and visits.

**n8n** — already running on Adalytics' n8n Cloud, and already holds a working GoHighLevel credential pattern (see the existing "Adalytics - SMS Lead Qualifier (GoHighLevel)" workflow). Two workflows: pull jobs in, push visits out.

**GoHighLevel** — where Terry already works, so that's where the data lands. Nothing new for him to learn or log into.

## Data flow, step by step

### Inbound (jobs)
1. n8n runs every 15 minutes during business hours.
2. Calls the GHL calendar API for today's appointments.
3. For each appointment without cached coordinates, geocodes the address via Nominatim and caches the result.
4. Upserts into Supabase `jobs`, keyed on `ghl_appointment_id`.

### Outbound (visits)
1. Installer taps Clock in. The app captures a frame, reads geolocation, stamps the image, compresses, uploads to storage.
2. App inserts a `site_visits` row. **Postgres sets `clockin_at` — the client never sends a time.**
3. A Postgres trigger computes `clockin_distance_m` from the job's cached coordinates.
4. A Supabase database webhook fires n8n.
5. n8n creates or updates the GHL `site_visit` custom object record and writes a note on the contact.

Clock-out follows the same path and additionally closes the visit, which populates `duration_minutes`.

## Job source abstraction

`jobs.source` is either `ghl_calendar` or `manual`. The app does not care which. This exists because the GoHighLevel calendar/dispatch build is a separate in-flight project: you can seed `jobs` manually today and flip to full calendar sync when dispatch lands, without touching the app.

## What would need to change to resell this

Not v1 scope, but worth knowing before you make decisions that close the door:

- `jobs` and `site_visits` would need a `tenant_id` and RLS scoped to it
- The GHL location ID would move from an n8n credential to a per-tenant config row
- PIN auth would need a per-tenant namespace so PINs can collide across clients
- Storage paths would need tenant prefixes

None of that is hard *if* the tables carry a tenant column from day one. Adding it later means a data migration. **Recommendation: leave it out of v1 — Attic Plus is one client and speculative multi-tenancy is how simple tools get slow.** But make the call knowingly.
