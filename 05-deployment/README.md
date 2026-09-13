# 05 — Deployment

## Domain: crew.atticplus.com.au

DNS for `atticplus.com.au` is managed in **SiteGround Site Tools**, not in GoHighLevel — the website is hosted on SiteGround Cloud.

1. In Lovable: **Settings → Domains → Add custom domain** → `crew.atticplus.com.au`. Lovable gives you a CNAME target.
2. In SiteGround Site Tools: **Domain → DNS Zone Editor** → add a CNAME record.
   - Name: `crew`
   - Points to: the Lovable target
   - TTL: default
3. Wait for propagation (usually minutes, allow an hour), then confirm HTTPS works. `getUserMedia` and `navigator.geolocation` **both require HTTPS** — the app is non-functional without a valid certificate.

> Do not touch the root `atticplus.com.au` records. Mail for that domain runs on Microsoft 365 and the website is live on SiteGround — a mistake there takes down the client's email or site.

## Supabase auth redirect URLs

**Authentication → URL Configuration**

| Setting | Value |
|---|---|
| Site URL | `https://crew.atticplus.com.au` |
| Redirect URLs | `https://crew.atticplus.com.au/**` |

Add the Lovable preview URL as an additional redirect during development, and remove it at handover.

## Edge function CORS

`pin-login` currently allows `*`. Before go-live, tighten it to the real origin:

```ts
const cors = {
  "Access-Control-Allow-Origin": "https://crew.atticplus.com.au",
  ...
};
```

## PWA checklist

- [ ] `manifest.json` — name "Attic Plus Crew", short name "Crew", `display: standalone`, `orientation: portrait`, `theme_color: #12171A`
- [ ] Icons at 192px and 512px, plus a maskable variant
- [ ] Apple touch icon (iOS ignores the manifest icons)
- [ ] Installs to the home screen on both platforms
- [ ] **Camera and location still work from the installed app.** iOS treats a home-screen PWA as a separate permission context from Safari — an installer who granted permission in the browser will be asked again in the app. Test in the installed app specifically.

## Handing the app to the crew

Do not email a link and hope. Do it in person, once, with each installer:

1. Open `crew.atticplus.com.au` in their phone browser
2. Add to Home Screen
3. Open the installed app
4. Log in with their PIN
5. **Grant camera and location permission there and then** — this is the step that fails silently later if skipped
6. Do one practice clock-in and clock-out in the yard

Ten minutes per person, once. It is the difference between a tool that gets used and a tool that gets blamed.
