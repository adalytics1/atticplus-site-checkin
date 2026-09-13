# Field test — one installer, one real job, one full day

Everything before this was tested in a yard or on a desk. This is the first time the system meets a real roof cavity, real signal, and a real person in a hurry.

## Before the day

- [ ] The installer has the app installed, logged in, and has granted camera + location **in the installed app**
- [ ] They have done one practice clock-in and clock-out already
- [ ] They have your phone number and know to text you rather than work around a problem
- [ ] Terry knows to check GoHighLevel at the end of the day
- [ ] The NSW surveillance notice has been issued and the 14 days have elapsed — see `../docs/04-compliance-nsw.md`

## On the day — what to watch

| Check | Why it matters |
|---|---|
| Time from opening the app to clocking in | Over 30 seconds and it will get skipped when they are busy |
| GPS accuracy figure at each site | Establishes what "normal" drift looks like for this crew |
| Distance from job at clock-in | If routinely over 150 m, the geofence number needs revisiting — not the installer |
| Did location resolve inside the roof space? | If not, the clock-out flow needs to happen outside, and the crew needs telling |
| Battery draw across the day | High-accuracy GPS is expensive; two short reads should be negligible, but confirm |
| Signal at the sites | Any dead spots mean a failed upload, which is the worst failure mode |

## At the end of the day

Open the job in GoHighLevel as Terry would, and check it reads as a story: who, when, how long, how far, and two photos that make sense.

- [ ] Both photos load and are legible
- [ ] The stamp is readable on the attic photo, not lost in shadow
- [ ] `time_on_site` matches what actually happened
- [ ] The note is in the contact timeline where the office looks

## Ask the installer three questions

Not "did it work" — they will say yes.

1. **What was annoying?**
2. **Was there a moment you nearly didn't bother?**
3. **What would make you stop using it?**

The third one is the important one. Whatever they say is the next thing to fix.
