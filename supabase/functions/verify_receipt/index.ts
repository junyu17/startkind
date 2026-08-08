import { json } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Verifies an App Store receipt server-side and mirrors the resulting
// entitlement into the `entitlements` table (the cross-device source of truth
// that one_next_step / admin_task_reader check).
//
// Requires the APPLE_SHARED_SECRET secret (App Store Connect > App Information >
// App-Specific Shared Secret). Uses the auto-injected SUPABASE_SERVICE_ROLE_KEY
// to write the entitlement row (bypassing RLS).

const PLUS_PRODUCTS = new Set(["StartKind_plus_monthly", "StartKind_plus_yearly"]);
const PROD_URL = "https://buy.itunes.apple.com/verifyReceipt";
const SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } });
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const receipt = body?.receipt;
    if (!receipt || typeof receipt !== "string") return json({ error: "bad_request" }, 400);

    const secret = Deno.env.get("APPLE_SHARED_SECRET");
    if (!secret) return json({ error: "apple_not_configured" }, 503);

    // Apple guidance: hit production first; 21007 means it's a sandbox receipt.
    let result = await verify(receipt, secret, PROD_URL);
    if (result.status === 21007) {
      result = await verify(receipt, secret, SANDBOX_URL);
    }
    if (result.status !== 0) {
      return json({ error: "verification_failed", apple_status: result.status }, 400);
    }

    const state = deriveEntitlement(result);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    await admin.from("entitlements").upsert(
      { user_id: user.id, state, updated_at: new Date().toISOString() },
      { onConflict: "user_id" }
    );

    return json({ state }, 200);
  } catch (e) {
    return json({ error: "server_error", detail: String(e) }, 500);
  }
});

async function verify(receipt: string, secret: string, url: string): Promise<any> {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      "receipt-data": receipt,
      password: secret,
      "exclude-old-transactions": true,
    }),
  });
  return await res.json();
}

function deriveEntitlement(result: any): string {
  const now = Date.now();
  const infos: any[] = result.latest_receipt_info ?? [];
  let latestExpiry = 0;
  let active = false;
  let inIntro = false;
  for (const info of infos) {
    if (!PLUS_PRODUCTS.has(info.product_id)) continue;
    const expiry = parseInt(info.expires_date_ms ?? "0", 10);
    if (expiry > latestExpiry) latestExpiry = expiry;
    if (expiry > now) active = true;
    if (info.is_in_intro_offer_period === "true") inIntro = true;
  }
  if (active) return inIntro ? "plus_trial" : "plus_active";
  if (latestExpiry > 0) return "plus_expired";
  return "free";
}
