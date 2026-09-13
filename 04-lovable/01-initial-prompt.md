# Lovable prompt 1 — app shell, login, job list

Paste everything inside the block below into Lovable as the **initial project message**. Do not add the capture screen yet — that is prompt 2, and mixing them produces a worse result in both.

---

```
Build a mobile-first web app for tradespeople to clock in and out of job sites.
It is used one-handed, outdoors, in bright sun, often wearing gloves. Everything
must be large, high contrast and thumb-reachable. It is not a dashboard.

STACK
Connect to my existing Supabase project. Do not create new tables — the schema
already exists. Use the anon key only; never the service role key.

EXISTING SCHEMA (read-only reference — do not modify)
  installer_directory  view: id, full_name           (readable without login)
  installers           id, full_name, auth_user_id
  jobs                 id, customer_name, address, lat, lng,
                       scheduled_start, scheduled_end, assigned_installer_id
  site_visits          id, job_id, installer_id,
                       clockin_at, clockin_lat, clockin_lng,
                       clockin_accuracy_m, clockin_photo_path,
                       clockout_at, clockout_lat, clockout_lng,
                       clockout_accuracy_m, clockout_photo_path,
                       duration_minutes
Row-level security is already configured. An installer can only see their own
jobs and visits. Do not write any filtering logic that duplicates this — just
query and let RLS do its job.

SCREEN 1 — LOGIN (no email, no password)
Query `installer_directory` for the list of names. Show them as a vertical list
of large tappable cards, first names prominent.
After tapping a name, show a numeric PIN pad: big round 0-9 buttons in a 3x4
grid, four filled dots showing progress, and a back button.
On the 4th digit, POST automatically (no submit button) to the edge function:

  POST {SUPABASE_URL}/functions/v1/pin-login
  body: { installer_id, pin }

  200 -> { session, installer }  — call supabase.auth.setSession(session)
  401 -> "Wrong PIN." Clear the dots, shake them, stay on the pad.
  429 -> "Too many wrong PINs. Try again in 15 minutes." Return to the name list.

Persist the session so the app stays logged in for weeks. These are work phones
used daily; making someone re-enter a PIN every morning will get the app deleted.
Put a small "Not you?" link in the header to sign out.

SCREEN 2 — TODAY'S JOBS
Query `jobs` where scheduled_start is today, ordered by scheduled_start.
RLS already limits this to the logged-in installer's jobs.

Each job is a large card showing:
  - Customer name, large and bold
  - Address, one line, smaller
  - Scheduled time, e.g. "8:00 AM - 12:00 PM"
  - A status pill: "Not started" / "On site" / "Done"

Card states:
  Not started -> full-width green "CLOCK IN" button
  On site     -> full-width amber "CLOCK OUT" button, plus a live running timer
                 ("On site 1h 12m") counting from clockin_at
  Done        -> muted card, shows total time, no button

Determine state by querying `site_visits` for today's visits by this installer:
no row = Not started, row with clockout_at null = On site, row with clockout_at
= Done.

If the installer has an open visit on one job, every OTHER job's clock-in button
is disabled with the caption "Clock out of [customer name] first." The database
enforces one open visit per installer; the UI should explain it rather than let
someone hit the error.

EMPTY STATE
"No jobs booked for you today." Plus a "Refresh" button. Do not show a spinner
forever — tradies will assume it is broken and stop using it.

VISUAL DIRECTION
Dark UI. Job sites are bright and phone screens wash out; a dark ground with
high-contrast type reads better outdoors than a white one, and it does not
strobe when someone opens the app in a dark roof space.
  background   #12171A
  cards        #1B2328
  primary text #F2F6F8
  muted text   #8D9BA4
  clock in     #2E9E63
  clock out    #C98A22
  danger       #C4553F
Minimum tap target 56px. Base font 17px, job names 22px+. System font stack.
No icon-only buttons anywhere — always a word.

PWA
Installable to the home screen. Name "Attic Plus Crew", short name "Crew".
Standalone display, portrait lock, dark theme colour #12171A.
Add an install prompt banner the first time someone opens it in a browser tab.

DO NOT BUILD YET
Do not build the camera or photo capture. The CLOCK IN and CLOCK OUT buttons
should navigate to a placeholder screen that says "Camera goes here". I will
give you the capture screen as a separate, detailed prompt.
```

---

## After Lovable finishes

Check these before moving to prompt 2:

- [ ] The name list loads **without being logged in** (that is `installer_directory` working)
- [ ] A correct PIN logs in; a wrong PIN says "Wrong PIN" and does not log in
- [ ] Five wrong PINs produce the 15-minute lockout message
- [ ] Today's jobs appear, and **only** the logged-in installer's jobs
- [ ] Closing and reopening the app keeps you logged in
- [ ] It installs to a phone home screen and opens without browser chrome

If the job list is empty, run `01-supabase/seed/manual_test_jobs.sql` — you need jobs dated today.
