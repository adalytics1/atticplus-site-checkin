# Attic Plus — Job Site Clock-In / Clock-Out

Build spec and runnable artifacts for a phone-based clock-in / clock-out card for Attic Plus installers.

An installer arrives at a booked job, opens a web app on their phone, and taps **Clock in** — the app takes a live selfie and simultaneously records GPS location and the server's timestamp. When the job is done they tap **Clock out**, which captures a photo of the completed work. Both records land in Attic Plus's GoHighLevel account against the customer.

**Client:** Attic Plus (Nuspace Sydney Pty Ltd) · **Built by:** Adalytics · **Cost to client:** $0/month

---

## This repo is built to be actioned, not just read

Every folder contains working artifacts, not descriptions of artifacts:

| Folder | Contains | Who runs it |
|---|---|---|
| `docs/` | Brief, architecture, hard constraints, compliance | Read first |
| `01-supabase/` | SQL migrations you can run as-is, RLS policies, edge function | Supabase MCP / SQL editor |
| `02-gohighlevel/` | Calendar setup guide, custom object spec, API payloads | HighLevel MCP / GHL UI |
| `03-n8n/` | Importable workflow JSON | n8n MCP / n8n UI |
| `04-lovable/` | Paste-ready prompts + reference implementation of the hard part | Lovable |
| `05-deployment/` | Domain, env vars, PWA config | You |
| `06-testing/` | Test plan and field-test checklist | You |

**Start here:** [`AGENTS.md`](AGENTS.md) if you are an AI agent. [`docs/01-brief.md`](docs/01-brief.md) if you are a human.

---

## Locked decisions

Do not re-open these without a reason. They came from the client.

| Decision | Value |
|---|---|
| What is "a job"? | A booked **calendar appointment** in GoHighLevel |
| Installers | **Employees**, under 10, mixed iPhone/Android |
| Clock-in photo | **Selfie** at the job — proves the person is there |
| Clock-out photo | **Completed work** — proves the job, doubles as documentation |
| Login | **4-digit PIN** per installer, no email required |
| App address | `crew.atticplus.com.au` |
| Exception alerts | **Out of scope** for v1 |
| Ongoing cost | **$0/month** — all free tiers or existing plans |

---

## Build order

Each phase produces something testable. Do not skip ahead.

```
00  Read docs/03-critical-constraints.md          ← the EXIF trap. Non-negotiable.
01  GoHighLevel test calendar        02-gohighlevel/calendar-setup.md
02  Supabase foundation              01-supabase/
03  Lovable capture screen           04-lovable/02-capture-screen-prompt.md
04  n8n job sync                     03-n8n/workflows/01-sync-jobs-from-ghl.json
05  GHL custom object + push back    02-gohighlevel/ + 03-n8n/workflows/02-*
06  Domain + PWA                     05-deployment/
07  Field test                       06-testing/
```

---

## The single most important thing in this repo

**Do not build this on photo EXIF metadata.** iOS strips GPS from photos uploaded via web forms, staff can pick old photos from the camera roll, and apps exist that write fake GPS into image files. The location must be read from the browser geolocation API separately, at capture time, and the timestamp must come from the server.

Full explanation and the correct approach: [`docs/03-critical-constraints.md`](docs/03-critical-constraints.md)

---

## Status

| Component | State |
|---|---|
| Project brief | ✅ Complete |
| Supabase migrations | ✅ Written, not yet run |
| GHL calendar | ⬜ To set up (guide included) |
| GHL custom object | ⬜ To create |
| n8n workflows | ✅ Written, not yet imported |
| Lovable app | ⬜ Not started |
| NSW surveillance notice | ⬜ Not drafted — 14-day clock, start early |
