import { handleOptions, json } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return handleOptions();
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );
    // The account to delete is always the caller's own, taken from the verified
    // JWT. Nothing is read from the request body, so this cannot be pointed at
    // another user's account.
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    // Hard delete, not a soft delete: every application table has an
    // ON DELETE CASCADE foreign key to auth.users(id), so removing the auth
    // user removes all of their rows. A soft delete would leave them behind.
    const { error } = await admin.auth.admin.deleteUser(user.id, false);
    if (error) return json({ error: "delete_failed" }, 500);

    return json({ deleted: true }, 200);
  } catch (e) {
    return json({ error: "server_error", detail: String(e) }, 500);
  }
});
