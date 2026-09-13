# Setting up the GoHighLevel test calendar

The check-in app reads "today's jobs" from a GoHighLevel calendar. The full dispatch build is a separate project — this guide stands up a **minimal working calendar** so the app can be built and tested now, and so the data shape is settled before the bigger build lands.

Do this first. Everything else depends on it.

---

## What the app needs from an appointment

Four things. If an appointment is missing any of them, that job will not appear correctly in the app.

| Needed | Where it comes from in GHL |
|---|---|
| **Who is doing it** | The appointment's assigned user |
| **Where it is** | The meeting location, set to a custom in-person address |
| **Who the customer is** | The contact the appointment is booked against |
| **When** | Start and end time |

---

## Step 1 — Add the installers as users

**Settings → My Staff → Add Employee**, one per installer.

Give each one the **User** role, not Admin. They will never actually log into GoHighLevel — this exists so an appointment can be *assigned* to a named person, which is how the app knows whose job it is.

> Keep the names spelled exactly as you will enter them in Supabase. The two systems are linked by the GHL user ID, but a name mismatch makes every future debugging session harder than it needs to be.

Write down each installer's **User ID** — you will paste them into the `installers.ghl_user_id` column. Find it in the URL when you open that staff member, or via the HighLevel connector.

---

## Step 2 — Create the calendar

**Calendars → Calendar Settings → Create Calendar → Round Robin.**

Round robin is the right type here because it assigns each appointment to **one specific team member**, which is exactly what the app needs to know. (Service calendars also work and are the better long-term fit for trades — but round robin is faster to stand up for testing and produces the same appointment shape.)

Settings to use:

| Setting | Value | Why |
|---|---|---|
| Calendar name | `Installations` | The app filters on this calendar |
| Team members | All installers from step 1 | Only assigned members can be booked |
| Meeting location | **Custom / In person — ask per appointment** | The office types the job address when booking |
| Duration | 240 minutes (4 hrs) | Adjust to a realistic install; it only affects the default |
| Availability | Mon–Fri, business hours | Rough is fine for testing |
| Booking widget | **Do not embed anywhere** | This is internal — the office books, not the customer |

Leave the public booking page unpublished. Terry's team books jobs from inside the CRM.

---

## Step 3 — Book two test appointments

For each one:

1. Open a **contact** (create a dummy one — "Test Customer, Chatswood").
2. **Appointments → Book Appointment.**
3. Choose the `Installations` calendar.
4. Assign it to a specific installer.
5. **Set the location to the real street address of the job.** This is the field the app geocodes and measures distance against — a blank or vague address makes the distance flag meaningless.
6. Set it for **today**, so it shows up in the app immediately.

Book one for this morning and one for this afternoon, both assigned to the same installer. That gives you a realistic two-job day to test against.

---

## Step 4 — Verify before moving on

Using the HighLevel connector, list today's appointments on the `Installations` calendar. Each one must come back with:

- a `calendarId` matching `Installations`
- an `assignedUserId` that matches one of your installers
- an `address` (or `meetingLocation`) containing a real street address
- a `contactId`
- `startTime` and `endTime`

**If `address` is empty, stop and fix the booking.** The whole distance feature depends on it, and it is far cheaper to fix the booking habit now than to discover it during a field test.

Record the **Calendar ID** — n8n needs it. See `../03-n8n/README.md`.

---

## What changes when the real dispatch build lands

Nothing in the app. The app reads from the `jobs` table in Supabase, and n8n fills that table from whatever calendar you point it at. When the proper dispatch calendar exists with real tradie availability, you change the calendar ID in the n8n workflow and that is the whole migration.

This is why `jobs.source` exists — see `../docs/02-architecture.md`.

---

## Notes for later

- **Round robin will auto-assign if the office does not pick someone.** For dispatch you will want explicit assignment every time; worth setting the habit now.
- **Cancelled appointments** still come back from the API. The sync workflow filters on status — see `../03-n8n/workflows/01-sync-jobs-from-ghl.json`.
- **Addresses get typed inconsistently.** "12 Macquarie St Parramatta" and "12 Macquarie Street, Parramatta NSW 2150" geocode to slightly different points. Once this is live, consider a required address format or pulling the address from the contact record instead.

## Reference

- [GoHighLevel calendar types and setup](https://hlgrowthpartner.com/post/gohighlevel-calendars-booking-setup-2026)
