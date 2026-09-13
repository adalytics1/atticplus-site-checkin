// pin-login — verify a 4-digit PIN and return a real Supabase session.
//
// Why this exists: Supabase Auth has no PIN concept. Each installer has a
// synthetic auth user with a long random password stored server-side. This
// function verifies the PIN, then signs in as that user and hands back the
// session. The installer never sees an email or a password.
//
// Deploy:  supabase functions deploy pin-login --no-verify-jwt
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let installer_id: string, pin: string;
  try {
    ({ installer_id, pin } = await req.json());
  } catch {
    return json({ error: "Invalid request" }, 400);
  }

  if (!installer_id || !/^[0-9]{4}$/.test(pin ?? "")) {
    return json({ error: "Enter your 4-digit PIN." }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // 1. Rate limit BEFORE verifying, so a brute-force attempt cannot learn
  //    anything from timing.
  const { data: lockedOut } = await admin.rpc("pin_locked_out", {
    p_installer_id: installer_id,
  });
  if (lockedOut) {
    return json(
      { error: "Too many wrong PINs. Try again in 15 minutes." },
      429,
    );
  }

  // 2. Verify the PIN.
  const { data: ok } = await admin.rpc("verify_pin", {
    p_installer_id: installer_id,
    p_pin: pin,
  });

  await admin.rpc("log_pin_attempt", {
    p_installer_id: installer_id,
    p_success: !!ok,
  });

  if (!ok) return json({ error: "Wrong PIN." }, 401);

  // 3. Mint a real session as the installer's synthetic auth user.
  const { data: installer, error: iErr } = await admin
    .from("installers")
    .select("login_email, full_name, installer_secrets(auth_password)")
    .eq("id", installer_id)
    .single();

  if (iErr || !installer) return json({ error: "Sign-in failed." }, 500);

  const password =
    (installer as any).installer_secrets?.auth_password ??
    (installer as any).installer_secrets?.[0]?.auth_password;

  if (!password) return json({ error: "Sign-in failed." }, 500);

  const anon = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data: session, error: sErr } = await anon.auth.signInWithPassword({
    email: installer.login_email,
    password,
  });

  if (sErr || !session.session) return json({ error: "Sign-in failed." }, 500);

  return json({
    session: session.session,
    installer: { id: installer_id, full_name: installer.full_name },
  });
});
