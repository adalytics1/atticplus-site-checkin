# Compliance — NSW Workplace Surveillance Act 2005

> Adalytics is not providing legal advice. This is what the legislation requires on its face; have the client's employment adviser review the notice before it is issued.

Nuspace Sydney Pty Ltd is a **NSW employer** and the installers are **employees**, so the *Workplace Surveillance Act 2005* (NSW) applies to this system.

## The requirement

- **At least 14 days' written notice** before tracking surveillance begins.
- The notice must state:
  - the **kind** of surveillance (here: tracking)
  - **how** it is carried out
  - **when** it starts
  - whether it is **continuous or periodic**
- The 14 days can only be shortened if the employee agrees.

## Why this design is easier to notify

Location is read at **two moments the employee chooses to trigger**. Nothing runs in the background. That makes this **periodic, not continuous** surveillance — a far easier thing to notify and a far easier thing for a crew to accept.

**Say this plainly in the notice.** "The app records your location only at the moment you tap Clock in and Clock out. It does not track you between those taps or outside work hours." That sentence is the difference between a crew that adopts this and a crew that resents it.

## Action

| Step | Owner | When |
|---|---|---|
| Draft the notice | Adalytics | Day 1 of the build |
| Client's employment adviser reviews | Terry | Before issue |
| Notice issued to all installers | Terry | At least 14 days before go-live |
| Crew one-pager (plain-English "what this does") | Adalytics | Issued with the notice |
| Go live | — | Not before the 14 days elapse |

**This starts on day one, not at handover.** It is the only part of the project with a statutory clock attached, and it is the one thing that can delay go-live after everything else is built.

## Reference

- [Workplace Surveillance Act 2005 (NSW) — overview](https://sprintlaw.com.au/articles/workplace-surveillance-act-2005-nsw-explained/)
- [Act text, NSW legislation](https://legislation.nsw.gov.au/view/whole/html/inforce/current/act-2005-047)
