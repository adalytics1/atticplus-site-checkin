# Reading today's appointments

```
GET /calendars/events
Header: Version: 2021-04-15
```

Query parameters:

| Param | Value |
|---|---|
| `locationId` | Attic Plus sub-account ID |
| `calendarId` | The `Installations` calendar ID from `../calendar-setup.md` |
| `startTime` | Start of today, epoch ms, AEST |
| `endTime` | End of today, epoch ms, AEST |

## What comes back, and what n8n does with it

| Field in response | Goes to | If missing |
|---|---|---|
| `id` | `jobs.ghl_appointment_id` | Skip the record — nothing to key on |
| `contactId` | `jobs.ghl_contact_id` | Sync it anyway; the note push will be skipped |
| `assignedUserId` | Looked up → `jobs.assigned_installer_id` | **Skip.** An unassigned job cannot appear in anyone's list |
| `address` | `jobs.address`, then geocoded | **Sync but flag.** No address means no distance measurement |
| `startTime` / `endTime` | `jobs.scheduled_start` / `_end` | Skip |
| `appointmentStatus` | Filter: keep `confirmed` and `new`, drop `cancelled` | — |

## Timezone

The sub-account is Australia/Sydney. Everything the installer sees should be
in their local time. Store UTC in Postgres (`timestamptz` does this
automatically) and format on display — never store a naive local time.

Sydney observes daylight saving; Adalytics in Queensland does not. During
DST the two are an hour apart, which is a reliable source of "the job shows
at the wrong time" bugs when testing from the Gold Coast.
