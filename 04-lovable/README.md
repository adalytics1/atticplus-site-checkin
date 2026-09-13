# 04 — Lovable

The installer-facing phone app. Two prompts, in order — do not merge them.

| File | What it builds |
|---|---|
| `01-initial-prompt.md` | App shell, PIN login, today's job list, PWA config |
| `02-capture-screen-prompt.md` | Camera + GPS + stamp + upload. The hard part. |
| `03-followup-prompts.md` | Polish and fixes, applied after both work |
| `reference/capture-logic.js` | Working reference implementation of the capture logic |

## Why two prompts and not one

The capture screen has strict rules that make the system trustworthy — live camera only, independent GPS read, server timestamps. Bundled into a big "build me an app" prompt, those rules get diluted and Lovable produces a file-picker upload that looks right and proves nothing. Build the shell, confirm it works, then build the capture screen against a working shell.

## Environment variables in Lovable

| Variable | Value |
|---|---|
| `VITE_SUPABASE_URL` | `https://<project>.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | The anon key |

**Never put the service role key in Lovable.** It bypasses row-level security, and anything in a Lovable app is shipped to the browser. The service role key belongs in n8n and Supabase edge functions only.

## The one thing to verify before handover

Set a test phone's clock an hour wrong, clock in, then check `clockin_at` in the database. It must show the *correct* time, not the phone's. If it shows the phone's time, the app is sending a timestamp and the trigger is not catching it — that breaks the entire evidentiary basis of the system.
