# GoHighLevel custom object — `site_visit`

This is what Terry actually looks at. Everything else in the repo exists to fill this in.

Custom objects are included on **every** HighLevel plan (Starter, Unlimited, Pro), capped at 10 objects per location and 300,000 records per object. There is no upgrade to sell the client.

## Create it

**Settings → Objects → Add Custom Object**, or via the HighLevel connector
(`execute_operation` → create object schema).

| Property | Value |
|---|---|
| Object name (singular) | Site Visit |
| Object name (plural) | Site Visits |
| Object key | `custom_objects.site_visit` |
| Primary display field | `visit_label` |
| Related to | **Contact** (many visits to one contact) |

## Fields

| Field key | Type | Contents | Notes |
|---|---|---|---|
| `visit_label` | Text | `Jake Thompson — 14 Sep, Chatswood` | Primary display field. Built by n8n. |
| `installer_name` | Text | Who clocked in | |
| `ghl_appointment_id` | Text | The appointment this visit belongs to | Links back to the calendar |
| `clockin_time` | Date/Time | Server timestamp | AEST. Never the phone's clock. |
| `clockout_time` | Date/Time | Server timestamp | Empty until they clock out |
| `time_on_site` | Text | `3h 42m` | Pre-formatted by n8n — GHL has no duration type |
| `clockin_coords` | Text | `-33.7969, 151.1803` | |
| `distance_from_job_m` | Number | Metres from the appointment address | **Information, not a gate** |
| `gps_accuracy_m` | Number | ± metres the phone reported | Context for the distance figure |
| `map_link` | Text (URL) | `https://maps.google.com/?q=<lat>,<lng>` | Free, no API key |
| `selfie_url` | Text (URL) | Arrival photo | Long-lived signed URL |
| `completed_work_url` | Text (URL) | Departure photo | Long-lived signed URL |
| `status` | Single option | `On site` / `Complete` | Set to `On site` at clock-in |

## Why `distance_from_job_m` is a number and not a pass/fail

Phone GPS drifts 5–50 m in the open and much worse inside a roof cavity, which is where these people work. A boolean "on site / not on site" forces a threshold decision onto data that does not support one. A number lets the office glance at it and use judgement: 12 m is fine, 4,000 m is a conversation.

See `../docs/03-critical-constraints.md`.

## Also: a note on the contact

The custom object is the structured record. The **note** is what the office actually sees when they open a customer, because that is where they already look.

```
Jake Thompson clocked in 7:42am, 12 m from site.
Photo: https://<signed-url>
```

Written by n8n at the same time as the record. Two writes, one workflow.

## Scopes

The n8n Private Integration Token needs:

- Contacts — **View and Edit** (read the customer, write the note)
- Calendars & Events — **View** (pull appointments)
- Objects / Custom Objects — **View and Edit** (create records)
- Locations & Custom Fields — **View**
- Users — **View** (map installers to GHL users)

## Reference

- [Create custom object record](https://marketplace.gohighlevel.com/docs/ghl/objects/create-object-record/index.html)
- [Create contact note](https://marketplace.gohighlevel.com/docs/ghl/contacts/create-note/)
- [Custom objects on all plans](https://help.gohighlevel.com/support/solutions/articles/155000006631-custom-objects-in-all-plans-higher-limit)
