# Test plan

Work top to bottom. Each section gates the next.

## 1. Database integrity

| Test | Expected |
|---|---|
| Insert a `site_visits` row with `clockin_at` set to last week | Row saves with `clockin_at` = **now**, not last week |
| Update a closed visit | Error: "This visit is already closed" |
| Update `clockin_lat` on an open visit | Error: "Clock-in data is immutable once recorded" |
| Insert a second open visit for the same installer | Unique constraint violation (23505) |
| Insert a visit for a job assigned to a different installer | RLS blocks it |
| Query `jobs` as installer A | Only A's jobs come back |
| Query `installer_directory` with no session | Names come back; no PINs, emails or auth ids |

## 2. PIN login

| Test | Expected |
|---|---|
| Correct PIN | Session returned, app logs in |
| Wrong PIN | 401, "Wrong PIN.", no session |
| 5 wrong PINs in a row | 429, 15-minute lockout |
| Correct PIN during lockout | Still 429 — the limit applies before verification |
| Wait 15 minutes, correct PIN | Logs in |
| 3-digit or 5-digit PIN | 400, rejected before hitting the database |

## 3. Capture — on real phones only

Run the full list in `../04-lovable/02-capture-screen-prompt.md`, on an iPhone and an Android, **inside the installed home-screen app**.

The single most important case: **set the phone's clock an hour wrong, clock in, and confirm `clockin_at` is correct in the database.** If it is wrong, stop — the system has no evidentiary value until it is fixed.

## 4. Photo size

After a handful of test captures, check the actual file sizes in the storage bucket. Anything consistently over 400 KB means compression is not working, and the free tier will be gone within months.

## 5. GoHighLevel push-back

| Test | Expected |
|---|---|
| Clock in | `site_visit` record appears in GHL, status "On site", note on the contact |
| Clock out | Same record updated (not a duplicate), status "Complete", `time_on_site` populated |
| Click `selfie_url` in GHL | Photo opens |
| Click `map_link` | Google Maps opens at the right pin |
| Job with no contact | Record still created, note skipped, no error |

## 6. Sync edge cases

| Test | Expected |
|---|---|
| Appointment with no assigned user | Skipped, reason logged in the n8n execution |
| Appointment with no address | Job syncs, `lat`/`lng` null, distance null |
| Appointment cancelled in GHL | Dropped from sync |
| Same address on two jobs | Geocoded once, cached |
| Job booked mid-morning | Appears within 15 minutes, or immediately on pull-to-refresh |
