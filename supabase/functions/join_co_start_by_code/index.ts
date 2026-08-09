import { corsHeaders, handleOptions, json } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type JoinBody = {
  room_code?: unknown;
  step_text?: unknown;
  display_name?: unknown;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return handleOptions();
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({})) as JoinBody;
    const roomCode = normalizeCode(body.room_code);
    if (!roomCode) return json({ error: "bad_room_code" }, 400);

    const displayName = cleanText(body.display_name, "Friend", 40);
    const stepText = cleanText(body.step_text, "Starting now", 180);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const { data: room, error: roomError } = await admin
      .from("co_start_rooms")
      .select("id,host_user_id,room_type,duration_minutes,status,room_code,starts_at")
      .eq("room_code", roomCode)
      .eq("status", "active")
      .maybeSingle();
    if (roomError) return json({ error: "room_lookup_failed" }, 500);
    if (!room) return json({ error: "room_not_found" }, 404);

    const { error: participantError } = await admin
      .from("co_start_participants")
      .upsert({
        room_id: room.id,
        user_id: user.id,
        display_name: displayName,
        stated_step: stepText,
        joined_at: new Date().toISOString(),
      }, { onConflict: "room_id,user_id" });
    if (participantError) return json({ error: "join_failed" }, 500);

    return json({ room }, 200);
  } catch (e) {
    return json({ error: "server_error", detail: String(e) }, 500);
  }
});

function normalizeCode(value: unknown): string | null {
  if (typeof value !== "string" && typeof value !== "number") return null;
  const digits = String(value).replace(/\D/g, "").slice(0, 6);
  return /^\d{6}$/.test(digits) ? digits : null;
}

function cleanText(value: unknown, fallback: string, maxLength: number): string {
  if (typeof value !== "string") return fallback;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, maxLength) : fallback;
}
