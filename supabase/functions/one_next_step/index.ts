import { corsHeaders, handleOptions, json } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// System prompt mirrors prompts/one_next_step_system.md
const SYSTEM_PROMPT = `You are StartKind, an execution assistant for adults who struggle to start tasks. Your job is to convert messy input into one small action the user can begin now.

Rules:
- Return exactly one next step unless the user explicitly asks for a plan.
- The step must be concrete, physical or screen-based, and startable in 5 to 15 minutes.
- Include a clear stop condition.
- Use neutral, kind, adult language.
- Do not diagnose, treat, or provide medication advice.
- Do not shame the user.
- Do not mention streaks, failure, discipline, laziness, or willpower.
- Avoid long explanations.
- "category" must be one of: bills, email, appointments, returns, insurance, banking, taxes, household, family_admin, medical, work_admin, school, cleaning, errands, other.
- "shrink_level" is 0 for a fresh first step (the user shrinks later).

Output JSON:

{
  "title": "",
  "step": "",
  "timer_minutes": 0,
  "stop_condition": "",
  "category": "",
  "shrink_level": 0,
  "why_this_step": ""
}`;

const PLUS_STATES = new Set(["plus_trial", "plus_active", "plus_grace_period"]);
const FREE_DAILY_LIMIT = 5;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return handleOptions();
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    // Validate input BEFORE counting usage (don't burn quota on bad requests).
    const body = await req.json().catch(() => ({}));
    const { input, language, calibrationMultiplier } = body ?? {};
    if (!input || typeof input !== "string") return json({ error: "bad_request" }, 400);

    // Entitlement + usage enforcement (server-side source of truth).
    const { data: ent } = await supabase
      .from("entitlements").select("state").eq("user_id", user.id).maybeSingle();
    const state = ent?.state ?? "free";
    const isPlus = PLUS_STATES.has(state);

    const today = new Date().toISOString().slice(0, 10);
    if (!isPlus) {
      const { count } = await supabase
        .from("ai_usage").select("*", { count: "exact", head: true })
        .eq("user_id", user.id).eq("day", today);
      if ((count ?? 0) >= FREE_DAILY_LIMIT) {
        return json({ error: "limit_reached" }, 402);
      }
    }
    await supabase.from("ai_usage").insert({ user_id: user.id, day: today, endpoint: "one_next_step" });

    const aiKey = Deno.env.get("OPENAI_API_KEY");
    if (!aiKey) return json({ error: "ai_not_configured" }, 503);

    const userPrompt = `Language: ${language ?? "en"}\nCalibration multiplier: ${calibrationMultiplier ?? 1}\nUser input:\n${input}`;
    const result = await callAI(aiKey, SYSTEM_PROMPT, userPrompt);
    return json(result, 200);
  } catch (e) {
    return json({ error: "server_error", detail: String(e) }, 500);
  }
});

async function callAI(apiKey: string, system: string, user: string): Promise<Record<string, unknown>> {
  const model = Deno.env.get("AI_MODEL") ?? "gpt-4o-mini";
  const endpoint = Deno.env.get("AI_ENDPOINT") ?? "https://api.openai.com/v1/chat/completions";
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
      response_format: { type: "json_object" },
      temperature: 0.4,
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`AI request failed: ${res.status} ${text}`);
  }
  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content ?? "{}";
  try {
    return JSON.parse(content);
  } catch {
    throw new Error(`AI returned non-JSON: ${content}`);
  }
}
