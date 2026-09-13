# Lovable prompt 3 — follow-ups

Apply these **after** both earlier prompts work end to end. One at a time — batching them makes it hard to tell which change broke what.

---

## 3a. Forgot-to-clock-out nudge

```
If an installer has an open visit (clockout_at is null) where clockin_at is more
than 8 hours ago, show a persistent amber banner at the top of the job list:

  "You're still clocked in at [customer name] from [time]. Did you forget to
   clock out?"

with a "Clock out now" button that goes straight to the clock-out capture screen
for that visit. Do not auto-close the visit — an installer genuinely working a
long day should not have their timesheet silently edited.
```

**Why this matters:** installers forget to clock out constantly. Without this, `duration_minutes` fills with 14-hour days and the timesheet becomes noise that nobody trusts. This is not polish.

---

## 3b. Pull to refresh

```
Add pull-to-refresh on the job list. Jobs sync from GoHighLevel every 15
minutes, so a job booked mid-morning will not appear until the next sync. Give
the crew a way to pull it in rather than closing and reopening the app.
```

---

## 3c. Visit history

```
Add a "My week" screen reachable from the header. List this installer's
completed visits for the last 7 days: customer name, date, clock-in time,
clock-out time, and total time on site. Read-only. Group by day with the day's
total hours as a subheading.

This is so an installer can check their own hours before payday without having
to ask the office.
```

---

## 3d. Poor-signal handling

```
Before starting the capture flow, check navigator.onLine. If offline, show:
  "No signal. You need a connection to clock in — the photo and location have
   to be sent straight away."
with a Retry button.

Do not build an offline queue. A photo stored on the phone and uploaded later
cannot prove when or where it was taken, which defeats the purpose.
```

---

## 3e. Accessibility and glove use

```
Audit every interactive element: minimum 56px tap target, visible focus states,
and text contrast of at least 4.5:1 against its background. Make sure the PIN
pad buttons are at least 72px — they are used with dusty or gloved hands.
Test that the app is usable one-handed on a 6.1" screen with the thumb only.
```
