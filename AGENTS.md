# Instructions for AI agents working this repo

You are building a job-site clock-in system for Attic Plus. This file tells you how to work. Read it fully before touching anything.

---

## Your connectors and what each is for

| Connector | Use it for | Do NOT use it for |
|---|---|---|
| **Supabase** | Run migrations, create the storage bucket, deploy the edge function, inspect data | Storing GHL credentials |
| **HighLevel** (OAuth) | Create the custom object, read calendars, inspect contacts | Runtime — that's n8n's job |
| **n8n** | Import and activate the two workflows, hold the GHL credential | Business logic that belongs in SQL |
| **Lovable** | Build the phone app from the prompts in `04-lovable/` | Anything server-side |

**HighLevel connector URL** (claude.ai → Settings → Connectors → Add custom connector):
```
https://services.leadconnectorhq.com/mcp/anthropic/v2
```
It is OAuth — paste the URL, sign in, pick the Attic Plus sub-account. The claude.ai dialog has **no custom-header field**, so any instruction telling you to set an `Authorization` header there is wrong and applies only to desktop/CLI JSON config.

---

## Rules

1. **Read `docs/03-critical-constraints.md` before writing any capture code.** If your implementation reads GPS from the image file, you have built the wrong thing.

2. **Server timestamps only.** `clockin_at` and `clockout_at` are set by Postgres `default now()`. The client must never send a timestamp. If you see a timestamp in a request body from the phone, reject it.

3. **Never hard-block on distance.** Record `distance_m` and let the office judge. Installers work inside metal-roofed cavities where GPS drifts badly. A blocked installer is a dead product.

4. **Run migrations in numerical order.** They are not idempotent by design — each assumes the previous one succeeded.

5. **Do not put secrets in this repo.** `.env.example` shows the shape; real values go in Supabase secrets, n8n credentials, and Lovable env vars.

6. **Photos are compressed client-side before upload.** Max 1280px wide, JPEG quality 0.7, target ≤250 KB. Skipping this exhausts the Supabase free tier within months. This is not optional polish.

7. **When something is ambiguous, check `docs/01-brief.md` first.** If it is not answered there, ask — do not invent a decision and proceed.

---

## Order of operations

Work top to bottom. Each step has a verification you must pass before moving on.

### Step 1 — GoHighLevel test calendar
Follow `02-gohighlevel/calendar-setup.md`.
**Verify:** you can list at least one appointment for today via the HighLevel connector, and it has an address.

### Step 2 — Supabase foundation
Run `01-supabase/migrations/*.sql` in order, then `01-supabase/seed/seed_installers.sql`, then deploy `01-supabase/functions/pin-login/`.
**Verify:** `select * from installers;` returns rows, and calling the `pin-login` function with a correct PIN returns a session while a wrong PIN returns 401.

### Step 3 — Lovable app shell + capture screen
Use `04-lovable/01-initial-prompt.md`, then `04-lovable/02-capture-screen-prompt.md`.
**Verify on a real iPhone AND a real Android.** Camera opens, location is captured, the stamp is burned onto the image, the upload lands in the storage bucket. Do not proceed on desktop-browser testing alone — permissions behave differently on phones.

### Step 4 — n8n job sync
Import `03-n8n/workflows/01-sync-jobs-from-ghl.json`.
**Verify:** the `jobs` table fills with today's appointments, each with lat/lng.

### Step 5 — GHL custom object + push-back
Create the object per `02-gohighlevel/custom-object-site_visit.md`, then import `03-n8n/workflows/02-push-visit-to-ghl.json`.
**Verify:** a test clock-in produces a `site_visit` record in GHL and a note on the contact, with a working photo link.

### Step 6 — Domain and PWA
Follow `05-deployment/`.
**Verify:** `crew.atticplus.com.au` loads, installs to a phone home screen, and the camera still works from the installed app (not just the browser tab).

### Step 7 — Field test
`06-testing/field-test-checklist.md`. One installer, one real job, one full day.

---

## What "done" means

- An installer can complete a clock-in and clock-out with two taps and a photo at each end.
- Terry can open a customer in GoHighLevel and see who was on site, when, for how long, how far from the address, and both photos.
- The NSW surveillance notice has been issued and the 14 days have elapsed. **The system does not go live before this.** See `docs/04-compliance-nsw.md`.
