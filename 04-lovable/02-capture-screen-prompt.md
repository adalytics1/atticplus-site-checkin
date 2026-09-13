# Lovable prompt 2 — the capture screen

This is the hard part and the part everything else depends on. Give Lovable the reference implementation as well as the prompt: paste `reference/capture-logic.js` into the chat alongside this, or upload it to the project.

**Read `../docs/03-critical-constraints.md` before running this prompt.** If the result reads GPS from the image file, it is wrong and must be rebuilt.

---

```
Build the photo capture screen. This is the evidence-gathering part of the app,
so the rules below are not preferences — getting any of them wrong makes the
whole system worthless.

THE THREE RULES

1. The photo must come from a LIVE CAMERA STREAM, never a file picker.
   Use navigator.mediaDevices.getUserMedia() and draw a frame to a canvas.
   There must be NO <input type="file"> anywhere, no "choose from gallery"
   option, and no fallback to one. If the camera cannot open, show an error —
   do not degrade to a file upload.

   Why: photo EXIF metadata cannot be trusted. iOS strips GPS from web uploads,
   and someone can pick an old photo from their camera roll or use an app that
   writes a fake location into the file.

2. Location must be read SEPARATELY from navigator.geolocation at the moment of
   capture, with { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }.
   Never read location from the image. If location fails or is denied, DO NOT
   SUBMIT — show the error and let them retry.

3. The timestamp is the SERVER's. Call supabase.rpc('server_now') to get the
   time for the burned-in stamp. Never send a timestamp in the insert payload —
   the database sets it and overwrites anything the client sends.

CAMERA FACING
  Clock in  -> facingMode 'user'        (a selfie — proves the person is there)
  Clock out -> facingMode 'environment' (the completed work)
On the video element set playsinline and muted, or iOS will not show the preview.

SCREEN LAYOUT
Full-bleed camera preview. Over it:
  Top:    the job name and address, on a dark translucent bar
  Top:    a live location chip — "Location found (±8 m)" in green once
          geolocation resolves, "Finding location..." in amber while waiting,
          "Location off" in red if denied
  Bottom: one large round shutter button, 88px, centred
  Bottom: a "Cancel" text link
The shutter is DISABLED and visibly dimmed until location has resolved. Caption
under it explains why: "Waiting for location..."

AFTER THE SHUTTER
1. Draw the video frame to a canvas, scaled so the width is at most 1280px.
2. Burn a stamp into the bottom of the image with a dark gradient behind it:
     line 1 (semibold): 14 Sep 2026, 07:42 AM      <- server time, Australia/Sydney
     line 2:            -33.796900, 151.180300  (±8 m)
     line 3:            Test Customer - Chatswood
3. Export as JPEG at quality 0.7. If the result is over 250 KB, step the quality
   down by 0.1 and retry, down to a floor of 0.45.
4. Show a confirmation screen with the stamped image, a "Retake" button and a
   "Confirm" button. Nothing uploads until they tap Confirm.

COMPRESSION IS NOT OPTIONAL. Ten installers taking two photos a day at full
resolution fills the Supabase free storage tier in under two months. 1280px
wide at quality 0.7 is the requirement, not a suggestion.

ON CONFIRM — CLOCK IN
  const visitId = crypto.randomUUID();
  path = `${installerId}/${visitId}/clockin.jpg`
  Upload the blob to the 'site-photos' storage bucket at that path.
  Then insert into site_visits:
    { id: visitId, job_id, installer_id,
      clockin_lat, clockin_lng, clockin_accuracy_m, clockin_photo_path: path }
  NO TIMESTAMP IN THIS PAYLOAD.

  If the insert fails with code 23505, show:
  "You're already clocked in on another job."

ON CONFIRM — CLOCK OUT
  path = `${installerId}/${visitId}/clockout.jpg`  (same visitId as the clock-in)
  Upload, then update the existing site_visits row with clockout_lat,
  clockout_lng, clockout_accuracy_m, clockout_photo_path, and clockout_at set to
  any value — the server overwrites it with its own clock.

UPLOAD FEEDBACK
Show a progress state with the word "Uploading..." and block the back button
while it runs. On failure: "Upload failed. Check your signal and try again."
with a Retry that reuses the already-captured image — do not make them
photograph it again.

ERROR MESSAGES — use these words exactly, they are written for the crew:
  Permission denied:  "Location is switched off for this app. Turn it on in your
                       phone settings — we can't record your clock-in without it."
  Position unavailable: "Can't find your location right now. Step outside the
                       roof space and try again."
  Timeout:            "Location is taking too long. Step outside and try again."
  Camera blocked:     "Camera access is off. Turn it on in your phone settings."

DO NOT ADD
  - No geofence check. Do not block or warn the installer for being far from the
    job. The distance is calculated server-side and is information for the
    office, not a gate. GPS drifts badly inside metal-roofed spaces and blocking
    a legitimate installer will kill adoption.
  - No offline queue. The app requires a connection at the moment of capture.
  - No retake limit.

Use the attached capture-logic.js as the reference implementation for the
camera, geolocation, stamping and compression functions.
```

---

## Test this on real phones before moving on

Desktop browser testing will not surface the failures that matter. Test all of the following on **both** a real iPhone and a real Android, and **inside the installed home-screen app**, not just a browser tab:

- [ ] Camera preview appears (iOS fails silently without `playsinline` + `muted`)
- [ ] Front camera on clock-in, rear camera on clock-out
- [ ] Location chip goes green with a plausible accuracy figure
- [ ] Shutter is disabled until location resolves
- [ ] The stamp is legible on both a bright outdoor shot and a dark attic shot
- [ ] Exported file is under 250 KB — check the actual file size in the storage bucket
- [ ] Denying location permission blocks submission and shows the right message
- [ ] Turning location back on and retrying works without restarting the app
- [ ] Killing the app mid-upload and reopening does not create a duplicate visit
- [ ] `clockin_at` in the database is the server's time, not the phone's — test by deliberately setting the phone's clock an hour wrong

That last one is the whole point of the design. Do not skip it.
