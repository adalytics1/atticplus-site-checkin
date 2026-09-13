# Critical constraints — read before writing any capture code

## 1. Do not build this on photo EXIF metadata

The instinct is that a photo already carries its GPS coordinates inside the file, so you just read them out. That falls apart in practice:

- **iOS strips GPS metadata** from any photo uploaded through a web form. The data simply is not there when it arrives. ([WebKit bug 257534](https://bugs.webkit.org/show_bug.cgi?id=257534))
- On any platform, a staff member can **pick an old photo out of their camera roll** instead of taking a new one.
- There are App Store and Play Store apps that **write a fake GPS location** into a photo file.

A system built on EXIF gives the client confidence that is not warranted, which is worse than giving them nothing.

## 2. The correct approach — three independent captures

At the moment of the tap, capture three things *independently of the image file*:

| What | How | Why |
|---|---|---|
| **A live camera frame** | `getUserMedia()` → draw to canvas | There is no "choose existing photo" path in the UI. The frame comes from the sensor, not the gallery. |
| **Device location** | `navigator.geolocation.getCurrentPosition()` with `enableHighAccuracy: true` | Read separately from the image. Returns lat, lng, and an accuracy radius. |
| **Server time** | Postgres `default now()` on insert | The phone's clock can be changed. The server's cannot. |

Then **burn the stamp onto the image** — date, time, coordinates, accuracy — via canvas before upload, so the photo is self-evidencing when Terry opens it in GoHighLevel.

Reference implementation: [`../04-lovable/reference/capture-logic.js`](../04-lovable/reference/capture-logic.js)

## 3. Never hard-block on distance

Phone GPS drifts 5-50 m in the open and considerably worse under a metal roof or inside a roof cavity — which is exactly where these people spend their working day.

- Geofence radius: **150 m**
- Behaviour: **record the distance, flag it, let it through**
- Do not add a "you are too far away" wall

The first time a legitimate installer is blocked from starting work by GPS drift, the crew stops trusting the tool and starts working around it.

## 4. Compression is not optional

Max width **1280px**, JPEG quality **0.7**, target **≤250 KB**.

10 installers x 2 photos/day x 250 KB ≈ 1.2 GB/year against a 1 GB free allowance, which is why migration `004` also prunes at 12 months. Ship without compression and the free tier is gone in under two months, and the $0/month promise to the client breaks.

## 5. Location permission must block submission, clearly

If `getCurrentPosition()` fails or is denied, the clock-in button must not submit, and the app must say why in plain language — *"Location is off. Tap to turn it on — we can't record your clock-in without it."* Silently submitting without coordinates produces a record that looks valid and proves nothing.

## 6. A 4-digit PIN needs rate limiting

10,000 combinations is trivially brute-forceable without a limit. The `pin-login` edge function enforces **5 attempts per installer per 15 minutes**, then locks that installer out for 15 minutes and logs it.

This is an accepted tradeoff, made deliberately: the PIN is a convenience gate for a small crew, and the real evidence is the GPS-stamped live photo. Do not remove the rate limit — it is what makes the tradeoff acceptable rather than negligent.

## 7. Test on real phones, not desktop browsers

Camera and location permission behave differently on iOS Safari, Android Chrome, and inside an installed PWA versus a browser tab. In particular, a PWA installed to the iOS home screen re-prompts for permissions independently of Safari. Test in the installed app, on both platforms, before declaring the capture screen done.
