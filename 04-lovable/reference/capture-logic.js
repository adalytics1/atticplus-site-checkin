/**
 * capture-logic.js — reference implementation of the one hard part.
 *
 * Live camera frame + independent GPS read + burned-in stamp + compression.
 * This is the piece that makes the whole system trustworthy. Read
 * ../../docs/03-critical-constraints.md before changing any of it.
 *
 * Three rules encoded here:
 *   1. The image comes from the camera sensor, never a file picker.
 *   2. Location is read from navigator.geolocation, never from EXIF.
 *   3. The displayed time is the SERVER's, fetched before capture — the
 *      phone's clock is not trusted and is never written to the database.
 */

const MAX_WIDTH = 1280;
const JPEG_QUALITY = 0.7;
const TARGET_BYTES = 250 * 1024;
const GEO_TIMEOUT_MS = 15000;

/* -------------------------------------------------------------------------
 * Camera
 * ---------------------------------------------------------------------- */

/**
 * @param {'user'|'environment'} facingMode  'user' for the clock-in selfie,
 *                                           'environment' for completed work.
 */
export async function startCamera(videoEl, facingMode) {
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error('This phone or browser cannot open the camera.');
  }

  const stream = await navigator.mediaDevices.getUserMedia({
    video: {
      facingMode: { ideal: facingMode },
      width: { ideal: 1920 },
      height: { ideal: 1080 },
    },
    audio: false,
  });

  // iOS will not autoplay inline video without both of these.
  videoEl.setAttribute('playsinline', '');
  videoEl.muted = true;
  videoEl.srcObject = stream;
  await videoEl.play();

  return stream;
}

export function stopCamera(stream) {
  stream?.getTracks().forEach((t) => t.stop());
}

/* -------------------------------------------------------------------------
 * Location — read independently of the image, every time
 * ---------------------------------------------------------------------- */

export function getLocation() {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      return reject(new Error('This phone cannot provide location.'));
    }
    navigator.geolocation.getCurrentPosition(
      (pos) =>
        resolve({
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
          accuracy_m: pos.coords.accuracy,
        }),
      (err) => {
        // Plain language. The installer must know what to do about it.
        const messages = {
          1: "Location is switched off for this app. Turn it on in your phone settings — we can't record your clock-in without it.",
          2: "Can't find your location right now. Step outside the roof space and try again.",
          3: "Location is taking too long. Step outside and try again.",
        };
        reject(new Error(messages[err.code] || 'Location unavailable.'));
      },
      { enableHighAccuracy: true, timeout: GEO_TIMEOUT_MS, maximumAge: 0 },
    );
  });
}

/* -------------------------------------------------------------------------
 * Server time — the phone's clock is not evidence
 * ---------------------------------------------------------------------- */

/**
 * The authoritative timestamp is written by Postgres on insert. This fetch is
 * only so the burned-in stamp shows the same time the database will record,
 * rather than whatever the phone thinks it is.
 */
export async function getServerTime(supabase) {
  const { data, error } = await supabase.rpc('server_now');
  if (error || !data) return new Date(); // stamp degrades; DB value still correct
  return new Date(data);
}

/* -------------------------------------------------------------------------
 * Capture + stamp + compress
 * ---------------------------------------------------------------------- */

export async function captureStamped(videoEl, { location, serverTime, jobLabel }) {
  const vw = videoEl.videoWidth;
  const vh = videoEl.videoHeight;
  if (!vw || !vh) throw new Error('Camera is not ready yet.');

  const scale = Math.min(1, MAX_WIDTH / vw);
  const w = Math.round(vw * scale);
  const h = Math.round(vh * scale);

  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');

  ctx.drawImage(videoEl, 0, 0, w, h);
  drawStamp(ctx, w, h, { location, serverTime, jobLabel });

  return compress(canvas);
}

function drawStamp(ctx, w, h, { location, serverTime, jobLabel }) {
  const when = serverTime.toLocaleString('en-AU', {
    timeZone: 'Australia/Sydney',
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', hour12: true,
  });

  const lines = [
    when,
    `${location.lat.toFixed(6)}, ${location.lng.toFixed(6)}  (±${Math.round(location.accuracy_m)} m)`,
    jobLabel,
  ].filter(Boolean);

  const pad = Math.round(w * 0.025);
  const fontSize = Math.max(13, Math.round(w * 0.028));
  const lineHeight = Math.round(fontSize * 1.45);
  const boxH = lines.length * lineHeight + pad * 1.5;

  // Dark band so the text is legible over any photo.
  const grad = ctx.createLinearGradient(0, h - boxH * 1.6, 0, h);
  grad.addColorStop(0, 'rgba(0,0,0,0)');
  grad.addColorStop(0.45, 'rgba(0,0,0,0.62)');
  grad.addColorStop(1, 'rgba(0,0,0,0.82)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, h - boxH * 1.6, w, boxH * 1.6);

  ctx.textBaseline = 'alphabetic';
  ctx.fillStyle = '#FFFFFF';
  ctx.shadowColor = 'rgba(0,0,0,0.9)';
  ctx.shadowBlur = 3;

  lines.forEach((line, i) => {
    ctx.font = `${i === 0 ? '600 ' : ''}${fontSize}px -apple-system, "Segoe UI", Roboto, sans-serif`;
    ctx.fillText(line, pad, h - boxH + pad * 0.5 + (i + 1) * lineHeight - lineHeight * 0.25);
  });

  ctx.shadowBlur = 0;
}

/**
 * Compression is not optional. 10 installers x 2 photos/day at full size
 * exhausts the Supabase free tier in under two months and breaks the
 * $0/month promise to the client.
 */
async function compress(canvas) {
  let quality = JPEG_QUALITY;
  let blob = await toBlob(canvas, quality);

  // Step down twice if the scene is noisy enough to blow the target.
  while (blob.size > TARGET_BYTES && quality > 0.45) {
    quality -= 0.1;
    blob = await toBlob(canvas, quality);
  }
  return blob;
}

function toBlob(canvas, quality) {
  return new Promise((resolve) =>
    canvas.toBlob((b) => resolve(b), 'image/jpeg', quality),
  );
}

/* -------------------------------------------------------------------------
 * Upload + record
 * ---------------------------------------------------------------------- */

export async function clockIn(supabase, { installerId, job, videoEl }) {
  const location = await getLocation();          // fails loudly, blocks submit
  const serverTime = await getServerTime(supabase);

  const blob = await captureStamped(videoEl, {
    location,
    serverTime,
    jobLabel: job.customer_name || job.address || '',
  });

  const visitId = crypto.randomUUID();
  const path = `${installerId}/${visitId}/clockin.jpg`;

  const { error: upErr } = await supabase.storage
    .from('site-photos')
    .upload(path, blob, { contentType: 'image/jpeg', upsert: false });
  if (upErr) throw new Error('Photo upload failed. Check your signal and try again.');

  // NOTE: no timestamp in this payload. Postgres sets clockin_at, and a
  // trigger overwrites anything the client sends.
  const { error } = await supabase.from('site_visits').insert({
    id: visitId,
    job_id: job.id,
    installer_id: installerId,
    clockin_lat: location.lat,
    clockin_lng: location.lng,
    clockin_accuracy_m: location.accuracy_m,
    clockin_photo_path: path,
  });

  if (error) {
    if (error.code === '23505') throw new Error("You're already clocked in on another job.");
    throw new Error('Clock-in failed. Try again.');
  }

  return visitId;
}

export async function clockOut(supabase, { installerId, visitId, videoEl, jobLabel }) {
  const location = await getLocation();
  const serverTime = await getServerTime(supabase);

  const blob = await captureStamped(videoEl, { location, serverTime, jobLabel });
  const path = `${installerId}/${visitId}/clockout.jpg`;

  const { error: upErr } = await supabase.storage
    .from('site-photos')
    .upload(path, blob, { contentType: 'image/jpeg', upsert: false });
  if (upErr) throw new Error('Photo upload failed. Check your signal and try again.');

  const { error } = await supabase
    .from('site_visits')
    .update({
      clockout_at: new Date().toISOString(), // overwritten server-side with now()
      clockout_lat: location.lat,
      clockout_lng: location.lng,
      clockout_accuracy_m: location.accuracy_m,
      clockout_photo_path: path,
    })
    .eq('id', visitId);

  if (error) throw new Error('Clock-out failed. Try again.');
}
