// seed_installers.mjs — create installers with synthetic auth users and PINs.
//
// Usage:
//   export SUPABASE_URL="https://<project>.supabase.co"
//   export SUPABASE_SERVICE_ROLE_KEY="<service role key>"
//   node seed_installers.mjs
//
// Safe to re-run: existing installers are skipped, not duplicated.

import { createClient } from "@supabase/supabase-js";
import { randomBytes } from "node:crypto";

// ---------------------------------------------------------------------------
// EDIT THIS LIST. PINs are what you hand the crew — write them down once,
// give them out, then delete them from this file.
// ---------------------------------------------------------------------------
const INSTALLERS = [
  { full_name: "Jake Thompson", pin: "1234" },
  { full_name: "Sam Rivera",    pin: "5678" },
  // ...add the real crew
];

const DOMAIN = "crew.atticplus.com.au"; // synthetic addresses only, never emailed

const db = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
);

const slug = (name) =>
  name.toLowerCase().replace(/[^a-z0-9]+/g, ".").replace(/^\.|\.$/g, "");

for (const { full_name, pin } of INSTALLERS) {
  if (!/^[0-9]{4}$/.test(pin)) {
    console.error(`✗ ${full_name}: PIN must be exactly 4 digits`);
    continue;
  }

  const login_email = `${slug(full_name)}@${DOMAIN}`;

  const { data: existing } = await db
    .from("installers")
    .select("id")
    .eq("login_email", login_email)
    .maybeSingle();

  if (existing) {
    console.log(`· ${full_name}: already exists, skipping`);
    continue;
  }

  // Long random password. The installer never sees or types this.
  const auth_password = randomBytes(32).toString("base64url");

  const { data: authUser, error: aErr } = await db.auth.admin.createUser({
    email: login_email,
    password: auth_password,
    email_confirm: true,
  });
  if (aErr) {
    console.error(`✗ ${full_name}: ${aErr.message}`);
    continue;
  }

  const { data: installer, error: iErr } = await db
    .from("installers")
    .insert({
      full_name,
      login_email,
      auth_user_id: authUser.user.id,
      pin_hash: "placeholder", // replaced below via set_installer_pin
    })
    .select("id")
    .single();
  if (iErr) {
    console.error(`✗ ${full_name}: ${iErr.message}`);
    continue;
  }

  await db.from("installer_secrets").insert({
    installer_id: installer.id,
    auth_password,
  });

  const { error: pErr } = await db.rpc("set_installer_pin", {
    p_installer_id: installer.id,
    p_pin: pin,
  });
  if (pErr) {
    console.error(`✗ ${full_name}: PIN not set — ${pErr.message}`);
    continue;
  }

  console.log(`✓ ${full_name} → PIN ${pin}`);
}

console.log("\nDone. Hand the PINs to the crew, then clear them from this file.");
